#!/bin/bash
## Requied arai2 mpv jq nodejs

IFS=$'\n'

export ACCESS_TOKEN="`cat token.json | cut -d'\"' -f4`"

export CURL_ARG="--header 'Authorization: Bearer $ACCESS_TOKEN'  --header 'Accept: application/json'  -s "
export ARIA2_ARG="-x15 --file-allocation=trunc --header='Authorization: Bearer $ACCESS_TOKEN' --header='Accept: application/json'"
export MPV_ARG="-http-header-fields='Authorization: Bearer $ACCESS_TOKEN','Accept: application/json'"

export API_ADDR_v3="https://www.googleapis.com/drive/v3/files"
export API_ADDR_v2="https://www.googleapis.com/drive/v2/files"

function list_folder(){
	eval curl  $CURL_ARG  --compressed  "$API_ADDR_v3?q=%27$1%27%20in%20parents%20and%20trashed%20=%20false"
}

## Download File require aria2
function download_file(){	
	eval aria2c $ARIA2_ARG "https://www.googleapis.com/drive/v3/files/$1?alt=media"  -o downloads/"\"$2\""
}

function play_video(){
	eval mpv $MPV_ARG --loop "https://www.googleapis.com/drive/v3/files/$1?alt=media"
}

function file_menu(){
	clear
	size=`eval curl $CURL_ARG --compressed $API_ADDR_v3/"$1"?fields=size|grep size|cut -d'"' -f4`
	printf "File Name:%-10s\nSize:%-10s" "$2" "$size"
	printf "Menu\n\n"
	(printf "Choice\n"
	printf "1, Download\n") | column -t -s ','
	while : ; do
		echo "Your Choice:"
		read tmp
		case $tmp in
			1)
				download_file "$1" "$2"
				return
				;;
			*)
				printf "Wrong input\n"
		esac
	done
}

function video_menu(){
	clear
	size=`eval curl $CURL_ARG --compressed $API_ADDR_v3/"$1"?fields=size|grep size|cut -d'"' -f4`
	printf "File Name:%-10s\nSize:%-10s\n\n" "$2" "$size"
	printf "Menu\n\n"
	(printf "Choice\n"
	printf "1, Download\n2,Play by mpv\n") | column -t -s ','
	while : ; do
		echo "Your Choice:"
		read tmp
		case $tmp in
			1)
				download_file "$1" "$2"
				return
				;;
			2)
				play_video "$1" 
				return
				;;
			*)
				printf "Wrong input\n"
		esac
	done
}


function start(){
	export work_dir="root"
	if [ ! -f credentials.json ];then
		echo "Goto https://developers.google.com/drive/api/v3/quickstart/go > Step1 get 'credentials.json' first!!"
		exit
	fi
	while : ; do
		unset ID
		unset NAME
		unset METATYPE
		clear
		unset output
		output="`list_folder $work_dir`"
		if [[ ! -z "`echo $output | grep 'Invalid Credentials'`" ]];then
			printf "Credentials not valid, update now."
			rm token.json
			node googleapi.js
			./drive-api.sh
			exit
		fi
		ID=(`echo $output | jq '.[]'  | grep "\"id\"" | cut -d'"' -f4 `)
		NAME=(`echo $output | jq '.[]' | grep name | cut -d'"' -f4`)
		METATYPE=(`echo $output | jq '.[]' | grep mimeType | cut -d'"' -f4`)
		(printf "Line,File Name,File Type\n" && for i in "${!NAME[@]}"; do 
																			printf "%s,%s,%s,%s\n" "$i" "${NAME[$i]}" "${METATYPE[$i]}"
																		done)  | column -t -s ','
		while : ; do
			printf "\nYour choice:"
			read tmp
			if [[ "$tmp" -eq "b" || "$tmp" -lt "${#NAME[@]}" && "$tmp" -ge 0 ]];then
				break
			fi
		done
		echo $tmp
		if ! [[ "$tmp" =~ ^[0-9]+$ ]] && [[ "$tmp" == "b" ]]; then
			export work_dir="$oldwork_dir"
		else
			if [[ "${METATYPE[$tmp]}" == "application/vnd.google-apps.folder" ]];then
				export oldwork_dir="$work_dir"
				export work_dir="${ID[$tmp]}"
			elif [[ "${METATYPE[$tmp]}" == "application/rar" ]];then
				file_menu "${ID[$tmp]}" "${NAME[$tmp]}"
			elif [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f1`" == "video" ]] || [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f1`" == "image" ]]  || [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f1`" == "audio" ]];then
				echo "video"
				video_menu "${ID[$tmp]}" "${NAME[$tmp]}"
			else
				file_menu "${ID[$tmp]}" "${NAME[$tmp]}"
			fi
		fi
	done
}

start

#mpv "https://www.googleapis.com/drive/v3/files/$1?alt=media" --http-header-fields='Authorization: Bearer #ya29.GlvGBlwExNproyTqddnuD7Sedqkb50brV65u7OCmEE0hgEYKFflwaTKhXrbalEp8fcvwcl9JL48Q_17ArSUs_KeG72ub9LbXaO4YYtrW_T7jjKI5pStGdjhkCkuB','Accept: application/json'

