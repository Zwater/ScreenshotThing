#!/bin/bash
domains="my.domain.com"
exitAfter=false
maim -v > /dev/null 2>&1
case $? in
    0)
        :;;
    127)
        echo "Maim is not installed"
        exitAfter=true
        ;;
esac
xclip -version > /dev/null 2>&1
case $? in
    0)
        :;;
    127)
        echo "xclip is not installed"
        exitAfter=true5;19M5;19m
        ;;
esac
yad --version > /dev/null 2>&1
case $? in
    0)
        :;;
    127)
        echo "yad is not installed"
        ;;
esac
jq --version > /dev/null 2>&1
case $? in
    0)
        :;;
    127)
        echo "jq is not installed"
        exitAfter=true
        ;;
esac
case $exitAfter in
    true)
        echo "One or more required packages are not installed. Quitting"
        exit 1
        ;;
    false)
        :;;
esac

record() {
    size=$(echo $1 | awk -F "+" '{print $1}')
    length=$(echo $size | awk -F "x" '{print $1}')

    if [ $((length%2)) -eq 0 ]
    then
        :
    else
        length=$((length + 1))
    fi
    width=$(echo $size | awk -F "x" '{print $2}')
    if [ $((width%2)) -eq 0 ]
    then
        :
    else
        width=$((width + 1))
    fi
    finalsize="$(echo $length)x$(echo $width)"
    echo $finalsize
    #echo $length
    #echo $width
    area="$(echo $1 | awk -F "+" '{print $2}'),$(echo $1 | awk -F "+" '{print $3}')"
    ffmpeg -y -video_size $finalsize -framerate 24 -f x11grab -i :1.0+$area -pix_fmt yuv420p -vcodec h264 -movflags +faststart /tmp/upload.mp4 &
    upload=/tmp/upload.mp4
    ffmpegpid=$!


}
ext="/"
case $1 in
    "--window")
        delete=true
        maim -i $(xdotool getactivewindow) /tmp/upload.png
        upload="/tmp/upload.png"
        ;;
    "--rect")
        sleep 0.2
        delete=true
        maim -s /tmp/upload.png
        upload="/tmp/upload.png"
        ;;
    "--clip")
        delete=false
        clip=$(xclip -selection clipboard -o)
        case $clip in
            /*)
                echo uploading $clip
                filename="$clip"
                upload="$filename"
                ;;
            *)
                echo "nothing to upload."
                exit 1
                ;;
        esac
        ;;
    "--rehost")
        delete=true
        clip=$(xclip -selection clipboard -o)
        filename=$(basename $clip)
        curl -s $clip > /tmp/$filename
        upload="/tmp/$filename"
        ;;
    "")
        delete=true
        maim /tmp/upload.png
        upload="/tmp/upload.png"
        ;;
    "--annotate")
        delete=true
        maim /tmp/upload.png
        gpaint /tmp/upload.png
        upload=/tmp/upload.png
        ;;
    "--rect-annotate")
        delete=true
        maim -s /tmp/upload.png
        gpaint /tmp/upload.png
        upload="/tmp/upload.png"
        ;;
    "--rect-record")
        sleep 0.2
        delete=false
        coords=$(slop)
        mkdir -p /tmp/gif
        record $coords
        echo $ffmpegpid
        yad --notification --command="killall yad" > /dev/null
        kill $ffmpegpid
        RET=1
        until [ ${RET} -eq 0 ]; do
            kill -0 $ffmpegpid
            RET=$?
            echo "ffmpeg is still alive"
            sleep 2
        done
        ext="/raw/"
        ;;
    *)
        echo "Incorrect syntax."
        echo "options are: --window, --rect, --clip, --annotate --rect-annotate --rect-record"
        ;;
esac
echo $upload
domain="https://$(echo $domains | xargs shuf -e | head -1)"
##
# This is the stuff you're going to have to change if you don't use pictshare
##
pictjson=$(curl -F "postimage=@$upload" -F "upload_code=UPLOAD_CODE" $domain/backend.php)
echo "Output: $pictjson"
hash=$(echo -n $pictjson | jq -r '.hash')
link="$domain$ext$hash"
##
# Thus ends the stuff you're going to have to change if you don't use pictshare
##
echo -n $link | xclip -selection clipboard
xclip -o -selection clipboard
notify-send $(xclip -o -selection clipboard)
case $delete in
    true)
        rm $upload
        ;;
    false)
        :;;
esac
