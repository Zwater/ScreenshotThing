#!/bin/bash

scrot -v > /dev/null 2>&1
exitAfter=false
case $? in
	0)
		:
		;;
	127)
		echo "scrot is not installed"
		exitAfter=true
		;;
esac
mimetype -v > /dev/null 2>&1
case $? in
	0)
		:
		;;
	127)
		echo "pearl-file-mimeinfo is not installed"
		exitAfter=true
		;;
esac
xclip -version > /dev/null 2>&1
case $? in
	0)
		:
		;;
	127)
		echo "xclip is not installed"
		exitAfter=true
		;;
esac
zenity --version > /dev/null 2>&1
case $? in
	0)
		:
		;;
	127)
		echo "zenity is not installed"
		exitAfter=true
		;;
esac
jq --version > /dev/null 2>&1
case $? in
	0)
		:
		;;
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
		echo "All required packages are here!"
		;;
esac
configfile=$(pwd)/config.json
if [ -e "$configfile" ]; then
	cat $configfile | jq -e 'has("host", "port", "uploadDir", "fileDir", "domain", "useBitly", "bitlyKey")' > /dev/null
	case $? in
		
		0)
			cat $configfile | jq -e '.' > /dev/null
			case $? in
				
				1)
					zenity --question --text="$configfile is empty, or not a valid JSON text. Would you like to generate a new one? Otherwise, we will quit"
					case $? in
						0)
							echo '{ "host": "sftp.server", "port": "22", "uploadDir": "/srv/upl/img", "fileDir": "/srv/upl/file", "domain": "domain.for.links", "useBitly": "1", "bitlyKey": "null"}' > $configfile
							exit 0
							;;
						1)
							exit 1
							;;
					esac
					;;
				0)
					:
					;;
			esac
			;;
			
			
		1)
			zenity --question --text="One or more entries are missing from $configfile. Would you like to generate a new one? Otherwise, we will quit"
			case $? in
				0)
					echo '{ "host": "sftp.server", "port": "22", "uploadDir": "/srv/upl/img", "fileDir": "/srv/upl/file", "domain": "domain.for.links", "useBitly": "1", "bitlyKey": "null"}' > $configfile
					exit 0
					;;
				1)
					exit 1
					;;
			esac
			;;
	esac
else
	echo "No config file found. Generating a new one. Quitting to allow the user to configure it."
	echo '{ "host": "sftp.server", "port": "22", "uploadDir": "/srv/upl/img", "fileDir": "/srv/upl/file", "domain": "domain.for.links", "useBitly": "1", "bitlyKey": "null"}' > $configfile
	exit 1
fi
options=$(cat $configfile)
useBitly=$(echo $options | jq -r .useBitly)
bitlyKey=$(cat $configfile | jq -r .bitlyKey)
function bitlyAuth () {
	loginInfo=$(zenity --title="$1" --password --username)
	case $? in
         0)
	 		bitlyUser=$(echo $loginInfo | cut -d'|' -f1)
	 		bitlyPass=$(echo $loginInfo | cut -d'|' -f2)
			;;
         1)
            echo "Login cancelled by user. Quitting"
            exit 0
            ;;
        -1)
            echo "An error occurred. Quitting."
            exit 1
            ;;
	esac
	bitlyKey=$(curl -s -u "$bitlyUser:$bitlyPass" -X POST "https://api-ssl.bitly.com/oauth/access_token")
	processBitly
}
function processBitly {
	case $bitlyKey in
		*401*)
			bitlyAuth "Invalid Login"
			;;
		*403*)
			bitlyAuth "Wait a Minute"
			;;
		*)
			echo $
			newConfig=$(echo $options | jq --arg bitlyKey "$bitlyKey" '.bitlyKey = $bitlyKey')
			echo $newConfig > $configfile
			zenity --info --title="Bit.ly" --text="Bitly authentication successful!"
			;;
	esac
}
if [[ "$useBitly" == "1" ]]; then
	if [[ "$bitlyKey" == "null" ]]; then
		echo "Null Bitly Key, beginning authentication process"
		bitlyAuth "Bitly Login"
	else
		echo "Bitly is configured!"
	fi
fi
server=$(echo $options | jq -r .host)
port=$(echo $options | jq -r .port)
imgDir=$(echo $options | jq -r .uploadDir)
fileDir=$(echo $options | jq -r .fileDir)
domain=$(echo $options | jq -r .domain)
bitlyKey=$(cat $configfile | jq -r .bitlyKey)
case $1 in
	"--window")
		delete=true
		filename="screenshot_$(date +%m_%d_%Y_%H%M%S).png"
		scrot -u /tmp$filename
		upload=/tmp/$filename
		;;
	"--rect")
		delete=true
		filename="screenshot_$(date +%m_%d_%Y_%H%M%S).png"
		scrot -s /tmp/$filename
		upload=/tmp/$filename
		;;
	"--clip")
		delete=false
		clip=$(xclip -selection clipboard -o)
		case $clip in
			/*)
    			filename=$(basename $clip)
    			upload=$clip
    			;;
			*)
    			filename="text_$(date +%m_%d_%Y_%H%M%S).txt"
    			echo $clip > /tmp/$filename
    			upload=/tmp/$filename
    			;;
    	esac
    	;;
    "")
		delete=true
		filename="screenshot_$(date +%m_%d_%Y_%H%M%S).png"
		scrot /tmp/$filename
		upload=/tmp/$filename
		;;
	"--help")
		printf "Instructions for Use \n 	--window - Takes a screenshot of the current window\n 	--rect - Allows the user to select a rectangle as a screenshot area\n 	--clip - Uploads a file or bit of text from the clipboard\n 	--help - Shows this. Duh.\n 	--config-help - displays help for config.json\n"
		exit 0		
		;;
	"--config-help")
		printf 'A configuration file called config.json must exist in the same directory as this script. it is in JSON format and must have the following entries\n     host - The ssh server to upload files to\n     port - The SSH Servers port\n     uploadDir - The directory on the ssh server to upload files to. ideally, this should be an internet-facing directory.\n     fileDir - The directory on the server to upload non-image files to. make it the same as uploadDir to upload everything to the same place.\n     domain - the domain name/directory used in generating links to the uploaded files.\n     useBitly - a 1 or 0 dictating if the user wishes to shorten links with bitly.\n     bitlyKey - a Bitly OAuth access key. this is automatically fetched upon logging in with this script. set it to null to trigger a re-authentication from this script.\nConfiguration Example:\n     { "host": "192.168.0.201", "port": "22", "uploadDir": "/srv/upl/img", "fileDir": "/srv/upl/file", "domain": "uploads.my.domain", "useBitly": "1", "bitlyKey": "null" }"\n'
		exit 0
		;;
	*)
		printf "Incorrect syntax.\n"
		printf "Instructions for Use \n 	--window - Takes a screenshot of the current window\n 	--rect - Allows the user to select a rectangle as a screenshot area\n 	--clip - Uploads a file or bit of text from the clipboard\n 	--help - Shows this. Duh.\n 	--config-help - displays help for config.json\n"
		exit 0
		;;
	esac
mimetype=$(mimetype --brief $upload)
case $mimetype in
	image/*)
		finalDir=$imgDir
		;;
	*)
		finalDir=$fileDir
		;;
esac
scp -P $port $upload $server:$finalDir
link="$domain/$(basename $finalDir)/$filename"
function shorten () {
	case $useBitly in
		1)
			shortLink=$(curl -s -X GET 'https://api-ssl.bitly.com/v3/shorten?access_token='$bitlyKey'&longUrl=http://'$1'&format=txt')
			echo "$shortLink"
			;;
		0)
			echo "$1"
			;;
	esac
}
shorten $link| xclip -selection clipboard
xclip -o -selection clipboard
case $delete in
	true)
		rm $upload
		;;
	false)
		:
		;;
esac