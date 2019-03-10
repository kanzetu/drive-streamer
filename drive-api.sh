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
	node googleapi_list.js "$1" > tmp
}


function get_parents(){
	eval curl  $CURL_ARG  --compressed  "$API_ADDR_v3/$1?fields=parents" | sed "3q;d" |cut -d'"' -f2
}

#============================ Search
function search(){
	printf "Input the argument: "
	read tmp
	tmp=`echo $tmp | sed s," ","%20",g`
	output="`eval curl  $CURL_ARG  --compressed  \"$API_ADDR_v3?q=name%20contains%20%27$tmp%27\"`"
		ID=(`echo $output | jq '.[]'  | grep "\"id\"" | cut -d'"' -f4 `)
		NAME=(`echo $output | jq '.[]' | grep name | cut -d'"' -f4`)
		METATYPE=(`echo $output | jq '.[]' | grep mimeType | cut -d'"' -f4`)
		(printf "Line,File Name,File Type\n" && for i in "${!NAME[@]}"; do 
																			printf "%s,%s,%s,%s\n" "$i" "${NAME[$i]}" "${METATYPE[$i]}"
																		done && printf "q,Quit search\n"
																		)  | column -t -s ','
		while : ; do
			printf "\nYour choice:"
			read tmp
			if [[ "$tmp" -eq "b" || "$tmp" -lt "${#NAME[@]}" && "$tmp" -ge 0 ]];then
				break
			fi
		done
		if ! [[ "$tmp" =~ ^[0-9]+$ ]]; then
			if [[ "$tmp" == "q" ]]; then
				return
			elif [[ "$tmp" == "p" ]]; then
				play_image ID[@]
			fi
		else
			if [[ "${METATYPE[$tmp]}" == "application/vnd.google-apps.folder" ]];then
				export oldwork_dir="$work_dir"
				export work_dir="${ID[$tmp]}"
			elif [[ "${METATYPE[$tmp]}" == "application/rar" ]];then
				file_menu "${ID[$tmp]}" "${NAME[$tmp]}"
			elif [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f1`" == "video" ]] || [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f1`" == "image" ]]  || [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f1`" == "audio" ]];then
				echo "video"
				video_menu "${ID[$tmp]}" "${NAME[$tmp]}"
			elif [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f2`" == "html" ]] || [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f2`" == "x-link-url" ]] || [[ "${METATYPE[$tmp]}" == "message/rfc822" ]] ;then
				html_menu "${ID[$tmp]}" "${NAME[$tmp]}" "${METATYPE[$tmp]}"
			elif [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f1`" == "text" ]];then
				text_menu "${ID[$tmp]}" "${NAME[$tmp]}" "${METATYPE[$tmp]}"
			fi
		fi
}

##========================  Download File require aria2
function download_file(){	
	eval aria2c $ARIA2_ARG "https://www.googleapis.com/drive/v3/files/$1?alt=media"  -o downloads/"\"$2\""
}

#========================== META Function
function readtext(){
	eval curl $CURL_ARG "https://www.googleapis.com/drive/v3/files/$1?alt=media" | less -r
}

function play_video(){
	eval mpv $MPV_ARG --prefetch-playlist --autofit-larger=80%x80% "https://www.googleapis.com/drive/v3/files/$1?alt=media"
}

function play_image(){
	declare -a ID=("${!1}")
	declare -a NAME=("${!2}")
	echo "" > a.txt
	for i in "${!ID[@]}"; do 
		if [ -z "`echo ${NAME[i]} | grep '._'`" ]; then
			echo "https://www.googleapis.com/drive/v3/files/${ID[i]}?alt=media" >> a.txt
		fi
	done
	eval mpv $MPV_ARG --keep-open=always --prefetch-playlist --autofit-larger=80%x80% --playlist=a.txt
	rm a.txt
}
#================================================ META MENU
function text_menu(){
	clear
	size=`eval curl $CURL_ARG --compressed $API_ADDR_v3/"$1"?fields=size|grep size|cut -d'"' -f4`
	printf "File Name:%-10s\nSize:%-10s" "$2" "$size"
	printf "Menu\n\n"
	(printf "Choice\n"
	printf "1, Read text\nr,Return\n") | column -t -s ','
	while : ; do
		echo "Your Choice:"
		read tmp
		case $tmp in
			1)
				readtext "$1"
				return
				;;
			r)
				return
				;;
			*)
				printf "Wrong input\n"
		esac
	done
}

function html_menu(){
	clear
	size=`eval curl $CURL_ARG --compressed $API_ADDR_v3/"$1"?fields=size|grep size|cut -d'"' -f4`
	printf "File Name:%-10s\nSize:%-10s" "$2" "$size"
	printf "Menu\n\n"
	(printf "Choice\n"
	printf "1, Read text\nr,Return\n") | column -t -s ','
	while : ; do
		echo "Your Choice:"
		read tmp
		case $tmp in
			1)
				eval curl $CURL_ARG "https://www.googleapis.com/drive/v3/files/$1?alt=media" | w3m -T $3
				return
				;;
			r)
				return
				;;
			*)
				printf "Wrong input\n"
		esac
	done
}

function file_menu(){
	clear
	size=`eval curl $CURL_ARG --compressed $API_ADDR_v3/"$1"?fields=size|grep size|cut -d'"' -f4`
	printf "File Name:%-10s\nSize:%-10s" "$2" "$size"
	printf "Menu\n\n"
	(printf "Choice\n"
	printf "1, Download\nr,Return\n") | column -t -s ','
	while : ; do
		echo "Your Choice:"
		read tmp
		case $tmp in
			1)
				download_file "$1" "$2"
				return
				;;
			r)
				return
				;;
			*)
				printf "Wrong input\n"
		esac
	done
}

function video_menu(){
	clear
	output=`eval curl $CURL_ARG --compressed $API_ADDR_v3/"$1"?fields=thumbnailLink,size`
	if ! [ -z "`echo \"$output\"|grep \"Invalid Credentials\"`" ]; then
			printf "Credentials not valid, update now."
			rm token.json tmp
			node googleapi.js
			./drive-api.sh
			exit
	fi
	size=`echo $output | cut -d'"' -f8`
	thumbnailLink=`echo $output | cut -d'"' -f4`
	printf "File Name:%-10s\nSize:%-10s\n\n" "$2" "$size"
	printf "Menu\n\n"
	(	printf "Choice\n"
		printf "1,Download\n2,Play by mpv\n3,Show thumbnailLink\nq,Return\n"
	) 	| column -t -s ','
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
			3)
				mpv --loop "$thumbnailLink"
				;;
			q)
				return
				;;
			*)
				printf "Wrong input\n"
		esac
	done
}

#================================================ ================================================  START

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
		list_folder $work_dir
		if [[ ! -z "`cat tmp | grep 'Authorize this app by visiting this url'`" ]];then
			printf "Credentials not valid, update now."
			rm token.json tmp
			node googleapi.js
			./drive-api.sh
			exit
		fi
		NAME=(`cat tmp | cut -d',' -f1`)
		ID=(`cat tmp | cut -d',' -f2`)
		METATYPE=(`cat tmp | cut -d',' -f3`)
		rm tmp
		(	printf "Line,File Name,File Type\n" 
			for i in "${!NAME[@]}"; do 
				printf "%s,%s,%s,%s\n" "$i" "${NAME[$i]}" "${METATYPE[$i]}"
			done
			printf "\n , \np,Play all in thie directory\ns,Search\nb,Back\nr,root directory\n"
		)  | column -t -s ','
		while : ; do
			printf "\nYour choice:"
			read tmp
			if [[ "$tmp" -eq "b" || "$tmp" -lt "${#NAME[@]}" && "$tmp" -ge 0 ]];then
				break
			fi
		done
		if ! [[ "$tmp" =~ ^[0-9]+$ ]]; then
			if [[ "$tmp" == "b" ]]; then
				export work_dir="`get_parents $work_dir`"
			elif [[ "$tmp" == "r" ]]; then
				export work_dir=root
			elif [[ "$tmp" == "p" ]]; then
				play_image ID[@] NAME[@]
			elif [[ "$tmp" == "s" ]]; then
				search
			fi
		else
			if [[ "${METATYPE[$tmp]}" == "application/vnd.google-apps.folder" ]];then
				export oldwork_dir="$work_dir"
				export work_dir="${ID[$tmp]}"
			elif [[ "${METATYPE[$tmp]}" == "application/rar" ]];then
				file_menu "${ID[$tmp]}" "${NAME[$tmp]}"
			elif [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f1`" == "video" ]] || [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f1`" == "image" ]]  || [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f1`" == "audio" ]];then
				echo "video"
				video_menu "${ID[$tmp]}" "${NAME[$tmp]}"
			elif [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f2`" == "html" ]] || [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f2`" == "x-link-url" ]] || [[ "${METATYPE[$tmp]}" == "message/rfc822" ]] ;then
				html_menu "${ID[$tmp]}" "${NAME[$tmp]}" "${METATYPE[$tmp]}"
			elif [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f1`" == "text" ]];then
				text_menu "${ID[$tmp]}" "${NAME[$tmp]}" "${METATYPE[$tmp]}"
			else
				file_menu "${ID[$tmp]}" "${NAME[$tmp]}"
			fi
		fi
	done
}

start
