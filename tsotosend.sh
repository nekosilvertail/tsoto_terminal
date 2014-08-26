#!/bin/bash
#terminal tsoto send client v0.4
#nekosilvertail 2013
#cc-by-sa
#uses the tsoto-api version (UNKNOWN)
#needs external resources: w3m for decoding html chars, curl for sending

MAKE_TEMP(){
	ck_out1=$(mktemp)
	ck_out2=$(mktemp)
	ck_out3=$(mktemp)
	ck_out4=$(mktemp)
	send_return=$(mktemp)
}

PRECONFIG(){
	config_dir="data"
}

VAR_CONFIG(){
	#defines where the system can find what
	logfile_name=$(cat "$config_dir/chat.cfg" | grep logfilename | cut -d "=" -f2)
	#don't change things if you don't know what you are doing.
	config_dir_user="$config_dir/$user_name"
	cookie="./$config_dir_user/cookie"
	log="./$config_dir/$logfile_name"
	block="./$config_dir_user/blocklist"
}

STARTUP_SETTINGS_DIR(){
	if CHECK_SETTINGS_DIR
	then
		MAKE_SETTINGS_DIR
		return 0
	else
		return 1
	fi
}

STARTUP_SETTINGS(){
	if CHECK_USER_CONFIG
	then
		MAKE_USER_CONFIG
		return 0
	else
		return 1
	fi
}

STARTUP_SETTINGS_FILE(){
	if CHECK_SETTINGS_FILE
	then
		MAKE_SETTINGS_FILE
		return 0
	else
		return 1	
	fi
}

CHECK_SETTINGS_DIR(){
	if [[ -d "$config_dir" ]]
	then
		echo "$(date +"%Y.%m.%d %H:%M:%S") Konfigurationsverzeichnis besteht bereits" >> $log
		return 1
	else
		echo "$(date +"%Y.%m.%d %H:%M:%S") Konfigurationsverzeichnis nicht vorhanden" >> $log
		return 0
	fi
}

CHECK_SETTINGS_FILE(){
	if [[ -f "$config_dir/chat.cfg" ]]
	then
		return 1
	else
		return 0
	fi
}

SETTINGS_HELPER(){

#check user name
	user_name_settings=$(cat "$config_dir/chat.cfg" | grep username | cut -d "=" -f2)
	if [[ "$user_name" == "$user_name_settings" ]]
	then
		return 1
	else
		echo "$(date +"%Y.%m.%d %H:%M:%S") Ersetze den vorhandenen Benutzernamen $user_name_settings in der Konfigurationsdatei durch $user_name" >> $log
		cat "$config_dir/chat.cfg" | sed s/username=.*/username=$user_name/g > $config_dir/tmp.cfg
		#for some reason, when just piping the output back to $config_dir/chat.cfg, then the file is empty. nice, isnt it?^^	
		mv $config_dir/tmp.cfg $config_dir/chat.cfg
		return 
	fi
}

MAKE_SETTINGS_FILE(){
	sleep 1
	echo "Erstelle die Konfigurationsdatei chat.cfg in $config_dir"
	touch $config_dir/chat.cfg
	echo "logfilename=logfile_$(date +%m_%Y).log" > $config_dir/chat.cfg
	echo "username=$user_name" >> $config_dir/chat.cfg
}

MAKE_SETTINGS_DIR(){
	mkdir $config_dir
	echo "$(date +"%Y.%m.%d %H:%M:%S") Erstelle lokales Konfigurationsverzeichnis \"$config_dir\" im derzeitigen Ordner: $(pwd)" >> $log
}

CHECK_USER_CONFIG(){
	if [[ -d "$config_dir_user" ]]
	then
		echo "$(date +"%Y.%m.%d %H:%M:%S") Benutzerverzeichnis $config_dir_user besteht bereits" >> $log
		return 1
	else
		echo "$(date +"%Y.%m.%d %H:%M:%S") Benutzerverzeichnis $config_dir_user nicht vorhanden" >> $log
		return 0
	fi
}

MAKE_USER_CONFIG(){
	echo "$(date +"%Y.%m.%d %H:%M:%S") Erstelle lokales Benutzerkonfigurationsverzeichnis \"$config_dir/$user_name\" im derzeitigen Ordner: $(pwd)" >> $log
	mkdir "./$config_dir_user"
}

CLOSE(){
	echo -e "\nProgramm wird beendet.."
	rm $cookie
	rm $ck_out1
	rm $ck_out2
	rm $ck_out3
	rm $ck_out4
	rm $send_return
	rm $config_dir/send.run
	echo "$(date +"%Y.%m.%d %H:%M:%S") Client beendet" >> $log
	exit 0
}

TRAP(){
	trap CLOSE SIGINT
}

SEND_PURE(){
	#post
	curl -ss -b $cookie -c $cookie --data-urlencode "message=$msg" --output $send_return http://www.tsoto.net/Chat/API
	#get
	#curl -ss --data-urlencode --output $send_return http://www.tsoto.net/Chat/Message/1?message=$msg
}

CHANGE_IFS(){
	export IFS_ORIG=$IFS
	IFS=$(echo -en "\n\b")
}

RETURN_IFS(){
	IFS=$IFS_ORIG
}

CHECK_FOR_LOGIN(){
	check=$(curl -ss -c $cookie -b $cookie http://www.tsoto.net/Chat/API)
	is_error=$(echo $check | cut -d"=" -f1)
	if [[ "$is_error" == "ERROR" ]] 
	then
		echo "$(date +"%Y.%m.%d %H:%M:%S") Login-Check fehlgeschlagen: $check." >> $log
		return 1
	else
                echo "$(date +"%Y.%m.%d %H:%M:%S") Login-Check fehlgeschlagen: $check." >> $log
		return 0
	fi
}

GENERATE_COOKIE(){
	if [[ -s $cookie ]]
	then
		echo "$(date +"%Y.%m.%d %H:%M:%S") Cookie existiert bereits." >> $log
		return 1
	else
		#echo "Cookie wird generiert."
		curl -ss -c $cookie --output $ck_out1 www.tsoto.net
		echo "$(date +"%Y.%m.%d %H:%M:%S") Cookie wurde generiert" >> $log
		return 0
	fi
}

DESTROY_COOKIE(){
	if [[ -s $cookie ]]
	then
		echo "Cookie wird gelöscht."
		> $cookie
	else
		echo "Kein Cookie vorhanden."
	fi
}

SEND_LOGOUT(){
	#logout is defunc. Cookie problems. Investigation is running.
	if [[ -s $cookie ]]
	then
		curl -ss -b $cookie -c $cookie --output $ck_out4 --data "logout=logout" www.tsoto.net
	else
		echo "Cookie existiert nicht."
		GENERATE_COOKIE
		SEND_LOGOUT
	fi
}

SEND_LOGIN(){
	#create the initial cookie
	echo "Cookie wird überprüft.."
	GENERATE_COOKIE

	sleep 1
	
	SEND_AUTH_MSG_NAME
	
	echo "Bitte gib dein tsoto-Passwort ein:"	
	stty -echo
	read user_password
	stty echo
	
	echo "Login wird durchgeführt.."
	curl -ss -b $cookie --data "user_name=$user_name&user_password=$user_password&login=Login" --output $ck_out2 --location www.tsoto.net
	sleep 1
	unset user_password

	echo "Chat wird besucht.."
	curl -ss -b $cookie --output $ck_out3 www.tsoto.net/Chat
	sleep 1	

	if CHECK_FOR_LOGIN
	then
		echo "Erfolgreich eingeloggt.."
		echo "$(date +"%Y.%m.%d %H:%M:%S") Login erfolgreich durchgeführt" >> $log
	else
		echo "Fehler, Login fehlgeschlagen."
		echo "Weitere Informationen: /debug, Inhalte von ck_out2 und ck_out3 überprüfen"
		echo "$(date +"%Y.%m.%d %H:%M:%S") Login fehlgeschlagen" >> $log
	fi
}

SEND_ONLINE(){
	CHANGE_IFS
	online_users=$(curl -ss -b $cookie -c $cookie www.tsoto.net/Chat/API/Mitglieder)
	for i in $online_users
	do
		username=$(echo $i | cut -d "|" -f 1 | strings --bytes 1)
		userstate=$(echo $i | cut -d "|" -f 2 | strings)
		reason=$(echo $i | cut -d "|" -f 3 | strings | w3m -dump -T text/html)
		#well that case is pretty much just for only one thing: not echoing that ^M after the line end of the last user
		case $username in
		"" ) ;;
		* )
			if [[ "$userstate" != "ANWESEND" ]]
			then
				if (test $reason)
				then
					echo "$username ist gerade $userstate (Grund: $reason)"
				else
					echo "$username ist gerade $userstate (Kein Grund angegeben)"
				fi
			else
				echo "$username ist gerade $userstate"
			fi
		;;
		esac
	done
	RETURN_IFS
}

SEND_WHISPER(){
	whisper_target=$(echo $msg | cut -d " " -f 2)
	curl -b $cookie -c $cookie --data-urlencode "message=$msg" http://www.tsoto.net/Chat/API
}

SEND_REWHISPER(){
	if (test $whisper_target) 
	then
		msg_whisper=$(echo $msg | strings -e S | cut -d " " -f 2-)
		msg=$(echo /w $whisper_target $msg_whisper)
		SEND_PURE
	else
		echo "No whisper target found."
	fi
}

SEND_DEBUG(){
	echo "Konfiguration:"
	echo "config_dir = $config_dir"
	ls $config_dir
	ls $config_dir/$user_name
	echo "Cookie:"
	echo "cookie = $cookie"
	echo "Curl-Returns:"
	echo "ck_out1 = $ck_out1"
	echo "ck_out2 = $ck_out2"
	echo "ck_out3 = $ck_out3"
	echo "ck_out4 = $ck_out4"
	echo "send_return = $send_return"
}

SHOW_RETURN(){
	if [[ -z "$send_return" ]]
	then
		curl -ss www.tsoto.net/Chat/API --output $send_return
	fi
	cat $send_return
	echo ""
}

SEND_WELCOME_TEXT(){
	SEND_AUTH_MSG_NAME
	echo "Willkommen, $user_name"
	echo "Bitte tippe /login ein, wenn du noch nicht im tsoto eingeloggt bist."
	echo "Mit dem Befehl \"/help\" bekommst du eine Übersicht der möglichen Befehle angezeigt."
	echo "---"
}

SEND_AUTH_MSG_NAME(){
	if [[ -z $user_name ]]
	then
		echo "Bitte gib deinen tsoto-Benutzernamen ein:"
		read user_name
		clear
		return 0
	else
		return 1
	fi
}

SEND_BLOCK(){
	if (test $1) 
	then
		if (CHECK_BLOCK_NAME $1)
		then
			echo "Der User ist bereits geblockt!"
		else
			echo $1 >> $block
		fi
	else
		echo "Du hast vergessen einen Benutzer zum blocken anzugeben!"
	fi
}

SEND_HELP_MSG(){
	#todo: colouring of the help file.
	echo "Es stehen folgenden Befehle zur Auswahl:"
	echo -e "/login\nLoggt dich im tsoto ein\n\
/logout\nLoggt dich aus dem tsoto aus\n\
/block Benutzername\nBlockiert Nachrichten von \"Benutzername\"\(Funktioniert noch nicht\)\n\
/online\nZeigt eine Liste der im Chat eingeloggten Benutzer\n\
/w Benutzername\nSendet eine Flüsternachricht an \"Benutzername\"\n\
/r\nAntwortet dem Benutzer, an den zuletzt geflüstert wurde\n\
/afk Grund\nStellt den Status auf Abwesend, mit "Grund" als Grund. Eine 2. Eingabe stellt den Status zurück. Alternativ kann /re verwendet werden\n\
/me\nSchreibt eine Nachricht in der 3. Person\n\
/keks Benutzername\nReicht \"Benutzername\" einen Keks\n\
/debug\nZeigt Debug-Informationen an\n\
/cookie\nDebug-Befehl, holt das Cookie\n\
/cookie_del\nDebug-Befehl, löscht das lokal gespeicherte Cookie\n\
/error\nStartet die Fehlerbehandlung. Zeigt aktuell nur den Output des Curl-Aufrufs an\n\
/help\nZeigt diese Auflistung an\n
	"
}

CHECK_BLOCK_NAME(){
	namecheck=$(cat $block | grep -x $1 | strings --bytes 1)
	#debug line
	#echo "namecheck = \"$namecheck\""
	if (test $namecheck)
	then
		return 0
	else
		return 1
	fi
}

CHECK_FOR_SEND(){
	if [[ -a $config_dir/send.run ]]
	then
		echo "Send client scheint bereits zu laufen. Wenn du dir sicher bist, daß dies nicht der Fall ist, dann lösche die Datei: $config_dir/send.run"
		exit 1
	else
		touch $config_dir/send.run
		return 0
	fi
}
#############################
########START ROUTINE########
#############################
PRECONFIG
CHECK_FOR_SEND
echo "Starte.."
STARTUP_SETTINGS_DIR
echo "Erstelle temporäre Werte.."
MAKE_TEMP
echo "Falle wird aufgestellt.."
TRAP
clear
SEND_WELCOME_TEXT
STARTUP_SETTINGS_FILE
VAR_CONFIG
STARTUP_SETTINGS
echo "$(date +"%Y.%m.%d %H:%M:%S") Client gestartet" >> $log
GENERATE_COOKIE
SETTINGS_HELPER
###########################
#######main routine########
###########################

while true
do
	read -p "> " msg
	msg_intro=$(echo $msg | cut -d " " -f 1)
	msg_var1=$(echo $msg | awk -F " " '{print $2}')
	case "$msg_intro" in
		"/close" )		CLOSE;;
		"/block" ) 		SEND_BLOCK $msg_var1 ;;
		"/error" )		SHOW_RETURN ;;
		"/help" )		SEND_HELP_MSG ;;
		"/cookie_del" )		DESTROY_COOKIE ;;
		"/cookie" )		GENERATE_COOKIE ;;
		"/logout" )		SEND_LOGOUT ;;
		"/debug" ) 		SEND_DEBUG ;;
		"/login" ) 		SEND_LOGIN ;;
		"/online" ) 		SEND_ONLINE ;;
		"/w" ) 			SEND_WHISPER ;;
		"/r" )			SEND_REWHISPER ;;
		* ) 			SEND_PURE ;;	
	esac	
	
	echo "$(date +"%Y.%m.%d %H:%M:%S") Nachricht gesendet: $msg" >> $log
done
