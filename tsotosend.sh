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

VAR_CONFIG(){
	#defines where the system can find what
	logfile_name="logfile_$(date +%m_%Y).log"
	config_dir="data"
	#don't change things if you dont know what you are doing.
	config_dir_user="./$config_dir/$user_name"
	cookie="./$config_dir_user/cookie"
	log="./$config_dir/$logfile_name"
	
}

STARTUP_SETTINGS(){
	if CHECK_SETTINGS
	then
		MAKE_SETTINGS
		return 0
	else
		return 1
	fi

	if CHECK_USER_CONFIG
	then
		MAKE_USER_CONFIG
		return 0
	else
		return 1
	fi
}

CHECK_SETTINGS(){
	if [[ -d "$config_dir" ]]
	then
		return 1
	else
		return 0
	fi
}

MAKE_SETTINGS(){
	mkdir $config_dir
	echo "Erstelle lokales Konfigurationsverzeichnis \"$config_dir\" im derzeitigen Ordner: $(pwd)" >> $log
}

CHECK_USER_CONFIG(){
	if [[ -d "$config_dir_user" ]]
	then
		return 1
	else
		return 0
	fi
}

MAKE_USER_CONFIG(){
	echo "Erstelle lokales Benutzerkonfigurationsverzeichnis \"$config_dir/$user_name\" im derzeitigen Ordner: $(pwd)"
	mkdir $config_dir/$user_name
}

CLOSE(){
	echo -e "\nProgramm wird beendet.."
	rm $cookie
	rm $ck_out1
	rm $ck_out2
	rm $ck_out3
	rm $ck_out4
	rm $send_return
	echo "$(date) Client beendet" >> $log
	exit 0
}

TRAP(){
	trap CLOSE SIGINT
}

SEND_PURE(){
	curl -ss --data-urlencode "message=$msg" --output $send_return http://www.tsoto.net/Chat/API
}

CHANGE_IFS(){
	export IFS_ORIG=$IFS
	IFS=$(echo -en "\n\b")
}

RETURN_IFS(){
	IFS=$IFS_ORIG
}

CHECK_FOR_LOGIN(){
	check=$(curl -ss http://www.tsoto.net/Chat/API)
	is_error=$(echo $check | cut -d"=" -f1)
	if [[ "$is_error" == "ERROR" ]] 
	then
		return 1
	else
		return 0
	fi
}

GENERATE_COOKIE(){
	if [[ -s $cookie ]]
	then
		#echo "Cookie existiert bereits."
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
		curl -ss -b $cookie --output $ck_out4 --data "logout=logout&user_id=276" www.tsoto.net
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
	fi
}

SEND_ONLINE(){
	CHANGE_IFS
	online_users=$(curl -ss www.tsoto.net/Chat/API/Mitglieder)
	for i in $online_users
	do
		username=$(echo $i | cut -d "|" -f 1 | strings)
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
	curl --data-urlencode "message=$msg" http://www.tsoto.net/Chat/API
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
		return 0
	else
		return 1
	fi
}

SEND_HELP_MSG(){
	#todo: colouring of the help file.
	echo "Es stehen folgenden Befehle zur Auswahl:"
	echo -e "/login\nLoggt dich im tsoto ein\n\
/logout\nLoggt dich aus dem tsoto aus\n\
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
############start 
echo "Starte.."
echo "Erstelle temporäre Werte.."
MAKE_TEMP
echo "Falle wird aufgestellt.."
TRAP
clear
SEND_WELCOME_TEXT
VAR_CONFIG
STARTUP_SETTINGS
echo "$(date +"%Y.%m.%d %H:%M:%S") Client gestartet" >> $log
GENERATE_COOKIE

###########################
#######main routine########
###########################

while true
do
	read -p "> " msg
	msg_intro=$(echo $msg | cut -d " " -f 1)
	case "$msg_intro" in
		"/close" )		CLOSE;;
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
