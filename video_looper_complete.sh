# -v video.mp4
# -r (rotate)
# -s skip processing video (must have -v)
# -i 0 (default video0 input)
# -o 2 (default video2 output)
# -w watermark.png
# -t top text (meme)
# -b bottom text (meme)
# -f font (meme)

video=false
process=true
input=0
output=2
watermark=false
toptext=false
bottomtext=false
font="Arial"
memestr=""
rotate=false
rotatestr=""

while getopts ":hv:rsi:o:w:t:b:f:z:" opt; do
  # echo $opt
  case $opt in
    v) video="$OPTARG"
    ;;
    r) rotate=true
    ;;
    s) process=false
	;;
	i) input="$OPTARG"
	;;
	o) output="$OPTARG"
	;;
	w) watermark="$OPTARG"
		printf "watermark: $watermark"
    ;;
    t) toptext="$OPTARG"
	;;
	b) bottomtext="$OPTARG"
	;;
	f) font="$OPTARG"
	;;
    z) rotatestr="rotate=$OPTARG,"
    ;;
    h) cat help.md
        exit 0
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

if [[ -f $toptext ]] && [[ -f $bottomtext ]]
then
	topplaintext=$(more $toptext | tr '[:lower:]' '[:upper:]')
	printf "%s\n" "$topplaintext"
	toptextlen=$(expr length "$toptext")
	printf "%s\n" "$toptextlen"
	toptextfs=$((240 / ($toptextlen / 5 + 1) ))
	printf "%s\n" $toptextfs

	bottomplaintext=$(more $bottomtext | tr '[:lower:]' '[:upper:]')
	bottomtextlen=$(expr length "$bottomplaintext")
	printf "%s\n" "$bottomplaintextlen"
	bottomtextfs=$((240 / ($bottomtextlen / 5 + 1) ))
	printf "%s\n" $bottomtextfs

	memestr="drawtext=font='$font': \
		textfile='$toptext': x=(w-tw)/2: y=(h-text_h)/8: reload=1: \
		fontsize=$toptextfs: fontcolor='AntiqueWhite': borderw=4, \
		drawtext=font='$font': \
		textfile='$bottomtext':x=(w-tw)/2:y=7*(h-text_h)/8: reload=1: \
		fontsize=$bottomtextfs: fontcolor='AntiqueWhite': borderw=4, "
elif [[ $toptext != false ]] && [[ $bottomtext != false ]]
then
	toptext=$(echo $toptext | tr '[:lower:]' '[:upper:]')
	printf "%s\n" "$toptext"
	toptextlen=$(expr length "$toptext")
	printf "%s\n" "$toptextlen"
	toptextfs=$((240 / ($toptextlen / 5 + 1) ))
	printf "%s\n" $toptextfs

	bottomtext=$(echo $bottomtext | tr '[:lower:]' '[:upper:]')
	bottomtextlen=$(expr length "$bottomtext")
	printf "%s\n" "$bottomtextlen"
	bottomtextfs=$((240 / ($bottomtextlen / 5 + 1) ))
	printf "%s\n" $bottomtextfs

	memestr="drawtext=font='$font': \
		text='$toptext': x=(w-tw)/2: y=(h-text_h)/8: \
		fontsize=$toptextfs: fontcolor='AntiqueWhite': borderw=4, \
		drawtext=font='$font': \
		text='$bottomtext':x=(w-tw)/2:y=7*(h-text_h)/8: \
		fontsize=$bottomtextfs: fontcolor='AntiqueWhite': borderw=4, "
fi

if [[ $rotate != false ]]
then
	rotatestr="rotate=2*PI*t/6,"
fi

if [[ $video != false ]]
then # if streaming a video
	if [[ $process = true ]]
	then # process the video input
		norm="$video"
		rev="rev-$video"
		now="$(date)"

		ffmpeg -i $norm -vf reverse $rev

		printf "file '%s'\nfile '%s'" "$norm" "$rev" > "$now.txt"

		ffmpeg -f concat -i "$now.txt" -c copy "$now.mp4"

		rm $rev "$now.txt"

		video="$now.mp4"

		# stack overflow
		# ffmpeg -i input.mkv -filter_complex "[0:v]reverse,split=3[r1][r2][r3];[0:v][r1][0:v][r2][0:v][r3] concat=n=6:v=1[v]" -map "[v]" output.mkv
	fi

	if [[ $watermark != false ]]
	then # rotate video and stream it
		# ffmpeg -stream_loop -1 -re -i "$video" -vf "$memestr $rotatestr format=yuv420p[v]" \
			# -map 0:v -f v4l2 "/dev/video$output"
		ffmpeg -stream_loop -1 -re -i "$video" -i "$watermark" \
			-filter_complex "[1][0]scale2ref[i][m];[m][i]overlay=format=auto, \
			$memestr $rotatestr format=yuv420p[v]" \
			-map "[v]" -f v4l2 "/dev/video$output"
	else
		ffmpeg -stream_loop -1 -re -i "$video" -vf "$memestr $rotatestr format=yuv420p[v]" \
			-map 0:v -f v4l2 "/dev/video$output"
	fi
else # if streaming from a webcam
	if [[ $watermark != false ]]
	then
		ffmpeg -i "/dev/video$input" -i "$watermark" \
			-filter_complex "[1][0]scale2ref[i][m];[m][i]overlay=format=auto, \
			$memestr $rotatestr format=yuv420p[v]" \
			-map "[v]" -f v4l2 "/dev/video$output"
	else
		ffmpeg -i "/dev/video$input" \
			-vf "$memestr $rotatestr format=yuv420p[v]" \
			-map 0:v -f v4l2 "/dev/video$output"

	fi
fi
# ffmpeg -i $norm -c copy v1.mp4
# ffmpeg -i $rev -c copy v2.mp4

# ffmpeg -i v1.mp4 -c copy -bsf:v h264_mp4toannexb -f mpegts input1.ts
# ffmpeg -i v2.mp4 -c copy -bsf:v h264_mp4toannexb -f mpegts input2.ts

# ffmpeg -i "concat:input1.ts|input2.ts" -c copy "$now.mp4"

# ffmpeg -f concat -safe 0 -i mylist.txt -c copy "$now 2.mp4"

# rm v1.mp4 v2.mp4 input1.ts input2.ts $rev

# ffmpeg -stream_loop -1 -re -i "$video.mp4" -map 0:v -f v4l2 /dev/video2

# sh rotate_video.sh "$now.mp4"

# ffmpeg -f v4l2 -input_format yuyv422 -video_size 800x448 -framerate 30 -i /dev/video0 -filter_complex "[0]vflip,drawtext=fontfile=/usr/share/fonts/truetype/freefont/Roboto-Regular.ttf:text='%{localtime\:%d %b %Y}':x=8:y=8:fontcolor=white:box=1:boxcolor=black@0.75,drawtext=fontfile=/usr/share/fonts/truetype/freefont/Roboto-Regular.ttf:text='%{localtime\:%T}':x=8:y=24:fontcolor=white:box=1:boxcolor=black@0.75[vid];[0]fps=1/20,vflip[img]" -map "[vid]" -c:v h264_omx -b:v 2M -f rtsp rtsp://localhost:8554/mystream -map "[img]" -update 1 /dev/shm/snapshot.jpg
