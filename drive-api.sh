#!/bin/bash
## Requied arai2 mpv jq nodejs

#============================ Initial
IFS=$'\n'

export ACCESS_TOKEN="`cat token.json | cut -d'\"' -f4`"

export CURL_ARG="--header 'Authorization: Bearer $ACCESS_TOKEN'  --header 'Accept: application/json'  -s "
export ARIA2_ARG="-x15 --file-allocation=trunc --header='Authorization: Bearer $ACCESS_TOKEN' --header='Accept: application/json'"
export MPV_ARG="-http-header-fields='Authorization: Bearer $ACCESS_TOKEN','Accept: application/json'"

export API_ADDR_v3="https://www.googleapis.com/drive/v3/files"
export API_ADDR_v2="https://www.googleapis.com/drive/v2/files"

function testconnection(){
		output="`eval curl  $CURL_ARG  --compressed  "$API_ADDR_v3?q=%27root%27%20in%20parents%20and%20trashed%20=%20false"`"
		if [[ ! -z "`echo $output | grep 'Invalid Credentials'`" ]];then
			printf "Credentials not valid, update now."
			rm token.json
			node googleapi.js
			./drive-api.sh
			exit
		fi
}

#============================

function list_folder(){
	node googleapi_list.js "$1" > tmp
}


function get_parents(){
	eval curl  $CURL_ARG  --compressed  "$API_ADDR_v3/$1?fields=parents" | sed "3q;d" |cut -d'"' -f2
}
#============================ Bookmark
function add_bookmark(){
	echo "$1,$2" >> bookmark
}

function bookmark(){
		clear
		n=(`cat bookmark | cut -d',' -f2`)
		id=(`cat bookmark | cut -d',' -f1`)
		printf "Bookmark\n\n"
		(	printf "Line,File Name\n" 
			for i in "${!n[@]}"; do 
				printf "%s,%s,%s\n" "$i" "${n[$i]}" "${id[$i]}"
			done
			printf "\n , \nd,Delete Bookmark\nq,Quit\n"
		)  | column -t -s ','
		while : ; do
			printf "\nYour choice:"
			read tmp
			if [[ "$tmp" -eq "b" || "$tmp" -lt "${#n[@]}" && "$tmp" -ge 0 ]];then
				break
			fi
		done
		
		if ! [[ "$tmp" =~ ^[0-9]+$ ]]; then
			if [[ "$tmp" == "q" ]]; then
				return
			fi
		else
			export work_dir="${id[$tmp]}"
			return
		fi
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
			fi
		else
			if [[ "${METATYPE[$tmp]}" == "application/vnd.google-apps.folder" ]];then
				export oldwork_dir="$work_dir"
				export work_dir="${ID[$tmp]}"
			elif [[ "${METATYPE[$tmp]}" == "application/rar" ]];then
				file_menu "${ID[$tmp]}" "${NAME[$tmp]}"
			elif [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f1`" == "video" ]] || [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f1`" == "image" ]]  || [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f1`" == "audio" ]];then
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
	eval mpv $MPV_ARG --prefetch-playlist --keep-open=always --autofit-larger=80%x80% "https://www.googleapis.com/drive/v3/files/$1?alt=media"
}

function play_image(){
	ID=("${@}")
	shift
	NAME=("${!2}")
	echo "" > a.txt
	for i in "${!ID[@]}"; do 
		if [ -z "`echo ${NAME[i]} | grep '._'`" ]; then
			echo "https://www.googleapis.com/drive/v3/files/${ID[i]}?alt=media" >> a.txt
		fi
	done
	eval mpv $MPV_ARG --keep-open=always --prefetch-playlist --autofit-larger=80%x80% --playlist=a.txt
	rm a.txt
}

function play_image_byIndex(){
	ID=("${@}")
	printf "Input the range [num]-(num) (e.g. 4-10 / 4- ): "
	read tmp
	start=`echo $tmp|cut -d'-' -f1`
	end=`echo $tmp|cut -d'-' -f2`
	echo "" > a.txt
	for i in "${!ID[@]}"; do 
		if ! [ -z $end ] && [ "$i" -gt "$end" ]; then
			break
		fi
		if  [ "$i" -ge "$start" ]; then
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
	testconnection
	while : ; do
		unset ID
		unset NAME
		unset METATYPE
		clear
		if [[ "$tmp" == "m" ]]; then
			printf "%s marked to Bookmart\n\n" "$n"
		fi
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
			printf "\n , \np,Play all in the directory\ni,Play all in the directory with index\nm,Add to Bookmark\nM,Goto Bookmark\ns,Search\nb,Back\nr,root directory\n"
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
				play_image ${ID[@]} ${NAME[@]}
			elif [[ "$tmp" == "i" ]]; then
				play_image_byIndex ${ID[@]} 
			elif [[ "$tmp" == "s" ]]; then
				search
			elif [[ "$tmp" == "m" ]]; then
				n="`eval curl  $CURL_ARG  --compressed  \"$API_ADDR_v3/$work_dir?fields=name\" | grep name | cut -d'\"' -f4`"
				add_bookmark "$work_dir" "$n"
			elif [[ "$tmp" == "M" ]]; then	
				bookmark
			fi
		else
			if [[ "${METATYPE[$tmp]}" == "application/vnd.google-apps.folder" ]];then
				export oldwork_dir="$work_dir"
				export work_dir="${ID[$tmp]}"
			elif [[ "${METATYPE[$tmp]}" == "application/rar" ]];then
				file_menu "${ID[$tmp]}" "${NAME[$tmp]}"
			elif [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f1`" == "video" ]] || [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f1`" == "image" ]]  || [[ "`echo ${METATYPE[$tmp]}|cut -d'/' -f1`" == "audio" ]];then
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
