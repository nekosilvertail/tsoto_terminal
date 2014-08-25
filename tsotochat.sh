#!/bin/bash
#terminal tsoto client v0.3
#nekosilvertail 2013
#cc-by-sa
#uses the tsoto-api version (UNKNOWN)
#needs external resources: w3m for decoding html chars, md5sum for checking for new messages, curl for receiving

#setup the tty for not taking input and not being synced to the output
STTY_SETUP(){
	STTY_ORIG=$(stty -g)
	stty -icanon time 0 min 0
}

#outputs the raw chat file to stdout
DISPLAY_CHAT(){
	clear
	cat $chat_lokal
}

#checks via API if there is anything new in chat (md5 compare between old and new chat API call output file)
CHECK_FOR_NEW_LINES(){
	MD5_ALT=$(md5sum $temp | cut -d" " -f1)
	CALL_API
	MD5_NEU=$(md5sum $temp | cut -d" " -f1)
	if [[ "0x$MD5_ALT" -eq "0x$MD5_NEU" ]]
	then
		return 1
	else 
		return 0
	fi
}

#changes the internal file seperator, needed to get the for loop running for every line instead of for every word 
CHANGE_IFS(){
	export IFS_ORIG=$IFS
	IFS=$(echo -en "\n\b")
}

#debug function, can basically contain anything needed for debugging
DEBUG(){
	echo DEBUG
	cat $temp
	echo ---
}

#creates needed temporary things like tempfiles and colour codes
MAKE_TEMP(){
	temp=$(mktemp)
	chat_lokal=$(mktemp)
	temp_msg=$(mktemp)
	NC="\e[0m"
	NBC="\e[49m"
	bold=$(echo -e "\033[1m")
	normal=$(tput sgr0)
	whisper_senden="\e[41m"
	whisper_empfangen="\e[42m"
}

REPORT_TEMPS(){
	echo "temp=$temp" > ./$config_dir/recv.vars
	echo "chat_lokal=$chat_lokal" >> ./$config_dir/recv.vars
	echo "temp_msg=$temp_msg" >> ./$config_dir/recv.vars
}

PRECONFIG(){
	config_dir="data"
}

VAR_CONFIG(){
	#defines where the system can find what
	logfile_name=$(cat "$config_dir/chat.cfg" | grep logfilename | cut -d "=" -f2)
	user_name=$(cat "$config_dir/chat.cfg" | grep username | cut -d "=" -f2)
	#don't change things if you don't know what you are doing.
	config_dir_user="$config_dir/$user_name"
	log="./$config_dir/$logfile_name"
	cookie="./$config_dir_user/cookie"
}

#function called on closing via ctrl+c, sets the terminal settings back, changes the IFS back to normal, otherwise the terminal would be totally messed up
CLOSE(){
	echo -e "\nSIGINT CAUGHT. CLOSING."
	rm $temp
	rm $chat_lokal
	rm $temp_msg
	rm $config_dir/recv.run
	IFS=$IFS_ORIG
	stty $STTY
	exit 0
}

#needed for trapping the ctrl+c not to interrupt the process but calling the closing routine, otherwise the terminal would be totally messed up
TRAP(){
	trap CLOSE SIGINT
}

#tsoto api call, output into temporary file
CALL_API(){
	curl -ss -b $cookie -c $cookie http://www.tsoto.net/Chat/API > $temp 
}

PARSE_BBCODE(){
	#nachricht=$(echo $nachricht | sed s/[[]b[]]/$bold/g | sed s/[[]\\/b[]]/$unbold/g )
	#just removing every bbcode for now, couldnt find a way to make a text coloured AND bold the same time.
	#not done yet: if you set a text to bold, you have to set it to "normal" back again, therefor loosing the colour. so the code that closes the bbcode should have the colour added after the the terminal got set to normal again
	
	#nachricht=$(echo $nachricht | sed s/[[].*[]]//g)
	#have to put that back because it removes things like [b]test[/b] completely (because it sees: [ b test /b ]). 
	#maybe using an iteration, removing only the first [.*] until there are no more left to remove. that should do the job
	echo ""
}

#chat parser function
PARSECHAT(){        
	echo "" > $chat_lokal
	inhalt=$(cat $temp )
	for i in $inhalt
	do
		zeit=$(echo $i | cut -d '|' -f1 | strings)
		name=$(echo $i | cut -d '|' -f2)
		typ=$(echo $i | cut -d '|' -f3)
		farbe=$(echo $i | cut -d '|' -f4)
		nachricht=$(echo $i | cut -d '|' -f5- | w3m -dump -T text/html | tr "\n" " ")
		
		case $farbe in
		000000 )
			chatfarbe="\e[1;37m" ;;
		303030 )
			chatfarbe="\e[1;30m" ;;
		606060 )
			chatfarbe="\e[0;37m" ;;
		aa0000 )
			chatfarbe="\e[0;31m" ;;
		ff0000 )
			chatfarbe="\e[0;31m" ;;
		ff6666 )
			chatfarbe="\e[1;31m" ;;
		004400 )
			chatfarbe="\e[0;32m" ;;
		007700 )
			chatfarbe="\e[0;32m" ;;
		33aa33 )
			chatfarbe="\e[1;32m" ;;
		000099 )
			chatfarbe="\e[0;34m" ;;
		3333ff )
			chatfarbe="\e[0;34m" ;;
		016470 )
			chatfarbe="\e[0;36m" ;;
		800080 )
			chatfarbe="\e[0;35m" ;;
		5c3317 )
			chatfarbe="\e[0;33m" ;;
		a67d3d )
			chatfarbe="\e[0;33m" ;;
		ff7f00 )
			chatfarbe="\e[1;33m" ;;
		cf6600 )
			chatfarbe="\e[1;33m" ;;
		7f3f00 )
			chatfarbe="\e[0;33m" ;;
		* )
			chatfarbe="\e[1;37m" ;;
		esac

		#PARSE_BBCODE

		case $typ in
		NORMAL )
			echo -e "$zeit <$name>""${chatfarbe} $nachricht""${NC}" >> $chat_lokal;;
		ME )
			echo -e "$zeit $name""${chatfarbe} $nachricht""${NC}" >> $chat_lokal;;
		WHISPERED ) 
			echo -e "${whisper_empfangen}""${chatfarbe}""$zeit $name flüstert: $nachricht""${NC}""${NBC}" >> $chat_lokal;;
		WHISPERING )
			echo -e "${whisper_senden}""${chatfarbe}""$zeit Du flüsterst an $name: $nachricht""${NC}""${NBC}" >> $chat_lokal;;
		* )
			#omitting invalid messages because of the ^M which is in the last line
			#echo "\[$typ\] <$zeit> $name: $nachricht" >> $chat_lokal;;
		esac		
	done
}

#check if user is logged into the chat, also: error handling
CHECK_FOR_LOGIN(){
	check=$(curl -ss -b $cookie -c $cookie http://www.tsoto.net/Chat/API)
	is_error=$(echo $check | cut -d"=" -f1)
 	if [[ "$is_error" == "ERROR" ]]
	then
		clear
		error=$(echo $check | cut -d"=" -f2)
		case $error in
		"NOTINCHAT" )
			echo "Nicht im Chat. /login in den Client eintippen." 
			return 2;;
		"NOTLOGGEDIN" )
			echo "Nicht auf tsoto eingeloggt. /login in den Client eintippen."
			return 1;;
		* ) 
			echo -e "Unbekannter Fehler! Erhaltener Fehlertext:\n$check"
			return 127;;
		esac
	else
		return 0
	fi
}

CHECK_FOR_SEND(){
	if [[ ! -a $config_dir/send.run || -a $config_dir/recv.run ]]
	then
		echo "Send client läuft nicht, oder Recv client rennt bereits."
		exit 1
	else	
		touch $config_dir/recv.run
		return 0
	fi
}

##################################
##########START ROUTINE###########
##################################

#startup#
PRECONFIG
CHECK_FOR_SEND
VAR_CONFIG
echo "Starte.."
echo "Terminal wird umkonfiguriert.."
STTY_SETUP
echo "Falle wird aufgestellt.."
TRAP
echo "Temporäre Dateien werden erstellt.."
MAKE_TEMP
REPORT_TEMPS
echo "Internes wird umgestellt.."
CHANGE_IFS
echo "Chat wird abgefragt.."
CALL_API
echo "Chat wird verarbeitet.."
PARSECHAT
DISPLAY_CHAT

##################################
###########MAIN ROUTINE###########
##################################
while true 
do
	#currently defunc. -> reimplementing when using curse (maybe)
	#just too unstable using a tty config recode for sending and receiving messages at once.
	#if read -n 1 msg
	#then
	#	echo $msg >> $temp_msg
	#	endline=$(echo -e "\n")
	#	if [[ "$msg" -eq endline ]]
	#	then	
	#		echo ENDE
	#	fi
	#	echo your message: $(cat $temp_msg) 
	#	#curl -d "message=$msg" http://www.tsoto.net/Chat/API
	#fi
	if CHECK_FOR_LOGIN
	then
		if CHECK_FOR_NEW_LINES 
		then
			CALL_API
			PARSECHAT	
			DISPLAY_CHAT
		fi
	fi
	sleep 5
done
