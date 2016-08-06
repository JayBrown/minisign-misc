#!/bin/bash

# minisign-verify v1.7.1 (shell script version)

LANG=en_US.UTF-8
export PATH=/usr/local/bin:$PATH
ACCOUNT=$(who am i | /usr/bin/awk '{print $1}')
CURRENT_VERSION="1.71"

# check compatibility
MACOS2NO=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $2}')
if [[ "$MACOS2NO" -le 7 ]] ; then
	echo "Error! Exiting…"
	echo "minisign-misc needs at least OS X 10.8 (Mountain Lion)"
	INFO=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set userChoice to button returned of (display alert "Error! Minimum OS requirement:" & return & "OS X 10.8 (Mountain Lion)" ¬
		as critical ¬
		buttons {"Quit"} ¬
		default button 1 ¬
		giving up after 60)
end tell
EOT)
	exit
fi

# public key check function
pkch () {
	case $1 in
		[!RW]* ) echo "false" ;;
		* )
		case $1 in
			( *[!0-9A-Za-z+/]* | "" ) echo "false" ;;
			( * )
				case ${#1} in
					( 56 ) echo "true" ;;
					( * ) echo "false" ;;
				esac
		esac
	esac
}

# set notification function
notify () {
 	if [[ "$NOTESTATUS" == "osa" ]] ; then
		/usr/bin/osascript -e 'display notification "$2" with title "$ACCOUNT minisign" subtitle "$1"' &>/dev/null
	elif [[ "$NOTESTATUS" == "tn" ]] ; then
		"$TERMNOTE_LOC/Contents/MacOS/terminal-notifier" \
			-title "$ACCOUNT minisign" \
			-subtitle "$1" \
			-message "$2" \
			-appIcon "$ICON" \
			>/dev/null
	fi
}

# look for terminal-notifier
TERMNOTE_LOC=$(/usr/bin/mdfind "kMDItemCFBundleIdentifier = 'nl.superalloy.oss.terminal-notifier'" 2>/dev/null | /usr/bin/awk 'NR==1')
if [[ "$TERMNOTE_LOC" == "" ]] ; then
	NOTESTATUS="osa"
else
	NOTESTATUS="tn"
fi

# directories
CACHE_DIR="${HOME}/Library/Caches/local.lcars.minisign"
if [[ ! -e "$CACHE_DIR" ]] ; then
	mkdir -p "$CACHE_DIR"
fi
SIGS_DIR="${HOME}/Documents/minisign"
if [[ ! -e "$SIGS_DIR" ]] ; then
	mkdir -p "$SIGS_DIR"
fi

# icon in base64
ICON64="iVBORw0KGgoAAAANSUhEUgAAAIwAAACMEAYAAAD+UJ19AAACYElEQVR4nOzUsW1T
URxH4fcQSyBGSPWQrDRZIGUq2IAmJWyRMgWRWCCuDAWrGDwAkjsk3F/MBm6OYlnf
19zqSj/9i/N6jKenaRpjunhXV/f30zTPNzePj/N86q9fHx4evi9j/P202/3+WO47
D2++3N4uyzS9/Xp3d319+p3W6+fncfTnqNx3Lpbl3bf/72q1+jHPp99pu91sfr4f
43DY7w+fu33n4tVLDwAul8AAGYEBMgIDZAQGyAgMkBEYICMwQEZggIzAABmBATIC
A2QEBsgIDJARGCAjMEBGYICMwAAZgQEyAgNkBAbICAyQERggIzBARmCAjMAAGYEB
MgIDZAQGyAgMkBEYICMwQEZggIzAABmBATICA2QEBsgIDJARGCAjMEBGYICMwAAZ
gQEyAgNkBAbICAyQERggIzBARmCAjMAAGYEBMgIDZAQGyAgMkBEYICMwQEZggIzA
ABmBATICA2QEBsgIDJARGCAjMEBGYICMwAAZgQEyAgNkBAbICAyQERggIzBARmCA
jMAAGYEBMgIDZAQGyAgMkBEYICMwQEZggIzAABmBATICA2QEBsgIDJARGCAjMEBG
YICMwAAZgQEyAgNkBAbICAyQERggIzBARmCAjMAAGYEBMgIDZAQGyAgMkBEYICMw
QEZggIzAABmBATICA2QEBsgIDJARGCAjMEBGYICMwAAZgQEyAgNkBAbICAyQERgg
IzBARmCAjMAAGYEBMgIDZAQGyAgMkBEYICMwQEZggIzAABmBATICA2QEBsgIDJAR
GCAjMEBGYICMwAAZgQEy/wIAAP//nmUueblZmDIAAAAASUVORK5CYII="

# settings
PUBKEY_NAME="jaybrown-github.pub"
PUBKEY_LOC="$SIGS_DIR/$PUBKEY_NAME"
ICON="$CACHE_DIR/lcars.png"

# decode icon
if [[ ! -e "$ICON" ]] ; then
	echo "$ICON64" > "$CACHE_DIR/lcars.base64"
	/usr/bin/base64 -D -i "$CACHE_DIR/lcars.base64" -o "$ICON" && rm -rf "$CACHE_DIR/lcars.base64"
fi
if [[ -e "$CACHE_DIR/lcars.base64" ]] ; then
	rm -rf "$CACHE_DIR/lcars.base64"
fi

# look for minisign binary & check version (prehashing)
MINISIGN=$(which minisign 2>&1)
if [[ "$MINISIGN" == "minisign not found" ]] || [[ "$MINISIGN" == "which: no minisign in"* ]] ; then
	notify "Error: minisign not found" "Please install minisign first"
	/usr/bin/open "https://jedisct1.github.io/minisign/"
	exit
else
	MS_VERSION=$("$MINISIGN" -v | /usr/bin/awk '{print $2}')
	if (( $(echo "$MS_VERSION < 0.6" | /usr/bin/bc -l) )) ; then
		notify "Error: outdated minisign" "Please update minisign first"
		/usr/bin/open "https://jedisct1.github.io/minisign/"
		exit
	fi
fi

# touch JayBrown public key file
if [[ ! -e "$PUBKEY_LOC" ]] ; then
	touch "$PUBKEY_LOC"
	echo -e "untrusted comment: minisign public key 37D030AC5E03C787\nRWSHxwNerDDQN8RlBeFUuLkB9bPqsR2T6es0jmzguvpvqWiXjxzTfaRY" > "$PUBKEY_LOC"
fi
PUBKEY_LOC=""

# check for update
NEWEST_VERSION=$(/usr/bin/curl --silent https://api.github.com/repos/JayBrown/minisign-misc/releases/latest | /usr/bin/awk '/tag_name/ {print $2}' | xargs)
NEWEST_VERSION=${NEWEST_VERSION//,}
if (( $(echo "$NEWEST_VERSION > $CURRENT_VERSION" | /usr/bin/bc -l) )) ; then
	notify "Update available" "Minisign Miscellanea v$NEWEST_VERSION"
	/usr/bin/open "https://github.com/JayBrown/minisign-misc/releases/latest"
fi

# check for false input
VER_FILE="$1"
TARGET_NAME=$(/usr/bin/basename "$VER_FILE")
if [[ ! -f "$VER_FILE" ]] ; then
	PATH_TYPE=$(/usr/bin/mdls -name kMDItemContentTypeTree "$VER_FILE" | /usr/bin/grep -e "bundle")
	if [[ "$PATH_TYPE" != "" ]] ; then
		notify "Error: target is a bundle" "$TARGET_NAME"
		exit # ALT: continue
	fi
	if [[ -d "$VER_FILE" ]] ; then
		notify "Error: target is a directory" "./$TARGET_NAME"
		exit # ALT: continue
	fi
fi
if [[ "$VER_FILE" == *".minisig" ]] || [[ "$VER_FILE" == *".pub" ]] || [[ "$VER_FILE" == *".key" ]]; then
	notify "Error: minisign filetype" "$TARGET_NAME"
	exit # ALT: continue
fi

# more settings
TARGET_DIR=$(/usr/bin/dirname "$VER_FILE")
MINISIG_NAME="$TARGET_NAME.minisig"
MINISIG_LOC="$TARGET_DIR/$MINISIG_NAME"

# choose signature file, if there's none in same directory as target file
if [[ ! -e "$MINISIG_LOC" ]] ; then
	MINISIG_LOC=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theDirectory to "$TARGET_DIR" as string
	set aKey to choose file with prompt "Locate the signature (.minisig) file for " & "$TARGET_NAME" & "…" default location theDirectory without invisibles
	set theKeyPath to (POSIX path of aKey)
end tell
theKeyPath
EOT)
	if [[ "$MINISIG_LOC" == "" ]] || [[ "$MINISIG_LOC" == "false" ]] ; then
		exit # ALT: continue
	elif [[ "$MINISIG_LOC" != *".minisig" ]] ; then
		CHOICE_BASENAME=$(/usr/bin/basename "$MINISIG_LOC")
		notify "Error: not a .minisig file" "$CHOICE_BASENAME"
		exit # ALT: continue
	fi
fi

# check clipboard for public key
CLIPBOARD=$(/usr/bin/pbpaste | xargs)
PK_CLIP=$(pkch "$CLIPBOARD")
if [[ "$PK_CLIP" == "true" ]] ; then
	PUBKEY="$CLIPBOARD"
	METHOD="key"
	TOSAVE="input"
else # choose: enter pub key or choose pub key file
	METHOD_ALL=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.minisign:lcars.png"
	set {theButton, theReply} to {button returned, text returned} of (display dialog "Enter the minisign public key, or select the key from a local public key (.pub) file." ¬
		default answer "" ¬
		buttons {"Cancel", "Select Key File", "Enter"} ¬
		default button 3 ¬
		with title "Verify " & "$TARGET_NAME" ¬
		with icon file theLogoPath ¬
		giving up after 180)
	if theButton = "Enter" then
		set theButton to "key"
	else if theButton = "Select Key File" then
		set theButton to "keyfile"
	end if
end tell
theButton & "@@@" & theReply
EOT)
	if [[ "$METHOD_ALL" == "" ]] || [[ "$METHOD_ALL" == "false" ]] || [[ "$METHOD_ALL" == "key@@@" ]] ; then
		exit # ALT: continue
	fi
	METHOD=$(echo "$METHOD_ALL" | /usr/bin/awk -F@@@ '{print $1}')
	PUBKEY=$(echo "$METHOD_ALL" | /usr/bin/awk -F@@@ '{print $2}')
	if [[ "$PUBKEY" == "@@@"* ]] || [[ "$METHOD" == *"@@@" ]] ; then
		notify "Internal error" "Could not parse input"
		exit # ALT: continue
	fi
	if [[ "$METHOD" == "key" ]] ; then
		PK_CHECK=$(pkch "$PUBKEY")
		if [[ "$PK_CHECK" == "false" ]] ; then
			notify "Error" "Not a minisign public key"
			exit # ALT: continue
		fi
		TOSAVE="input"
	fi
fi

# choose public key file
if [[ "$METHOD" == "keyfile" ]] ; then
	# choose from existing public key file list
	PK_LIST=$(find "$SIGS_DIR" -maxdepth 1 -name \*.pub | /usr/bin/rev | /usr/bin/awk -F/ '{print $1}' | /usr/bin/awk -F. '{print substr($0, index($0,$2))}' | /usr/bin/rev | /usr/bin/sort -n)
	if [[ "$PK_LIST" != "" ]] ; then
		PKLIST_CHOICE=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theList to {}
	set theItems to paragraphs of "$PK_LIST"
	repeat with anItem in theItems
		set theList to theList & {(anItem) as string}
	end repeat
	set theList to theList & {"🔎 Locate manually…"}
	set AppleScript's text item delimiters to return & linefeed
	set theResult to choose from list theList with prompt "Choose the key from one of your saved public key files, or locate the public key file manually." with title "Select Public Key" OK button name "Select" cancel button name "Cancel" without multiple selections allowed
	return the result as string
	set AppleScript's text item delimiters to ""
end tell
theResult
EOT)
		if [[ "$PKLIST_CHOICE" == "" ]] || [[ "$PKLIST_CHOICE" == "false" ]] ; then
			exit # ALT: continue
		fi
		if [[ "$PKLIST_CHOICE" == "🔎 Locate manually…" ]] ; then
			MANUAL="true"
		else
			MANUAL="false"
			TOSAVE="false"
			PUBKEY_LOC="$SIGS_DIR/$PKLIST_CHOICE.pub"
		fi
	else
		MANUAL="true"
	fi
elif [[ "$METHOD" == "key" ]] ; then
	if [[ "$PUBKEY" == "" ]] ; then
		notify "Internal error" "Could not parse input"
		exit # ALT: continue
	fi
else
	notify "Internal error" "Could not parse input"
	exit # ALT: continue
fi

# manual public key file location method
if [[ "$MANUAL" == "true" ]] ; then
	PUBKEY_CHOICE=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theKeyDirectory to "$TARGET_DIR" as string
	set aKey to choose file with prompt "Select the public key (.pub) file…" default location theKeyDirectory without invisibles
	set theKeyPath to (POSIX path of aKey)
end tell
theKeyPath
EOT)
	if [[ "$PUBKEY_CHOICE" == "" ]] || [[ "$PUBKEY_CHOICE" == "false" ]] ; then
		exit # ALT: continue
	fi
	if [[ "$PUBKEY_CHOICE" != *".pub" ]]; then
		CHOICE_BASENAME=$(/usr/bin/basename "$PUBKEY_CHOICE")
		notify "Error: not a .pub file" "$CHOICE_BASENAME"
		exit # ALT: continue
	fi
	CHOICE_DIR=$(/usr/bin/dirname "$PUBKEY_CHOICE")
	if [[ "$CHOICE_DIR" == "$SIGS_DIR" ]] ; then
		PARENT="false"
		TOSAVE="false"
		notify "Notification: public key" "Key already installed"
	else
		PARENT="true"
		TOSAVE="copy"
	fi
	PUBKEY_LOC="$PUBKEY_CHOICE"
fi

# verify
if [[ "$METHOD" == "keyfile" ]] || [[ "$SAVE_STATUS" == "true" ]] ; then
	echo "Verifying with public key file: $PUBKEY_LOC"
	MS_OUT=$("$MINISIGN" -V -x "$MINISIG_LOC" -p "$PUBKEY_LOC" -m "$VER_FILE" 2>&1)
else
	echo "Verifying with public key: $PUBKEY"
	MS_OUT=$("$MINISIGN" -V -x "$MINISIG_LOC" -P "$PUBKEY" -m "$VER_FILE" 2>&1)
fi
echo "---"
echo "$MS_OUT"
if [[ $(echo "$MS_OUT" | /usr/bin/grep "Signature and comment signature verified") == "" ]] ; then
	notify "Verification error" "$TARGET_NAME"
	exit # ALT: continue
fi

# parse comments
UNTRUSTED_COMMENT=$(/usr/bin/sed -n '1p' "$MINISIG_LOC" | /usr/bin/awk '/untrusted comment/ {print substr($0, index($0,$3))}')
TRUSTED_COMMENT=$(echo "$MS_OUT" | /usr/bin/awk '/Trusted comment/ {print substr($0, index($0,$3))}')
if [[ "$UNTRUSTED_COMMENT" == "" ]] ; then
	UNTRUSTED_COMMENT="n/a"
fi
if [[ "$TRUSTED_COMMENT" == "" ]] ; then
	TRUSTED_COMMENT="n/a"
fi
MS_OUT_INFO=$(echo "$MS_OUT" | /usr/bin/sed -n '1p')

# checksums
CHECKSUM21=$(/usr/bin/shasum -a 256 "$VER_FILE" | /usr/bin/awk '{print $1}')

# additional checksums (optional); uncomment if needed, then extend $INFO_TXT
# CHECKSUM5=$(/sbin/md5 -q "$VER_FILE")
# CHECKSUM1=$(/usr/bin/shasum -a 1 "$VER_FILE" | /usr/bin/awk '{print $1}')
# CHECKSUM22=$(/usr/bin/shasum -a 512 "$VER_FILE" | /usr/bin/awk '{print $1}')

# file size
BYTES=$(/usr/bin/stat -f%z "$VER_FILE")
MEGABYTES=$(/usr/bin/bc -l <<< "scale=6; $BYTES/1000000")
if [[ ($MEGABYTES<1) ]] ; then
	SIZE="0$MEGABYTES"
else
	SIZE="$MEGABYTES"
fi

# set info text
INFO_TXT="■︎■■ File ■■■
$TARGET_NAME

■■■ Size ■■■
$SIZE MB

■︎■■ Hash (SHA-2, 256 bit) ■■■
$CHECKSUM21

■︎■■ Untrusted minisign comment ■︎■■
$UNTRUSTED_COMMENT

■︎■■ Trusted minisign comment ■︎■■
$TRUSTED_COMMENT

■︎■■ Minisign output ■■■
$MS_OUT_INFO"

# notify
notify "Verification successful" "$TARGET_NAME"

# ask to save current public key
if [[ "$TOSAVE" != "false" ]] && [[ "$TOSAVE" != "" ]] ; then
	SAVE_CHOICE=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.minisign:lcars.png"
	set theButton to button returned of (display dialog "Do you want to save the current public key for later use?" ¬
		buttons {"No", "Yes"} ¬
		default button 2 ¬
		with title "Save Public Key" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
theButton
EOT)
	if [[ "$SAVE_CHOICE" == "Yes" ]] ; then
		CURRENT_DATE=$(date +%Y%m%d-%H%M%S)
		# save the public key (manual entry or clipboard)
		if [[ "$TOSAVE" == "input" ]] ; then
			NEW_PUBKEY_NAME=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.minisign:lcars.png"
	set theReply to text returned of (display dialog "Please enter the file name of the new public key file. The current date and the suffix .pub will added automatically." ¬
		default answer "" ¬
		buttons {"Enter"} ¬
		default button 1 ¬
		with title "Save Public Key" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
theReply
EOT)
			if [[ "$NEW_PUBKEY_NAME" == "" ]] ; then
				NEW_PUBKEY_NAME="minisign"
			fi

			if [[ "$NEW_PUBKEY_NAME" == *".pub" ]] ; then
				NEW_PUBKEY_NAME="${NEW_PUBKEY_NAME%.pub}"
			fi
			PUBKEY_LOC="$SIGS_DIR/$NEW_PUBKEY_NAME-$CURRENT_DATE.pub"
			echo -e "untrusted comment: minisign public key \n$PUBKEY" > "$PUBKEY_LOC"
		# move the public key file to the minisign folder
		elif [[ "$TOSAVE" == "copy" ]] ; then
			CHOICE_BASENAME=$(/usr/bin/basename "$PUBKEY_CHOICE")
			if [[ "$CHOICE_BASENAME" == "minisign.pub" ]] ; then # ask to rename the default name
				NEW_COPY_NAME=$(/usr/bin/osascript 2>&1 << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.minisign:lcars.png"
	set theReply to text returned of (display dialog "The public key (.pub) file has the default filename \"minisign\". Please choose a better one before moving it to your minisign folder." ¬
		default answer "" ¬
		buttons {"Cancel", "Enter"} ¬
		default button 2 ¬
		with title "Choose New Filename" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
theReply
EOT)
				if [[ $(echo "$NEW_COPY_NAME" | /usr/bin/grep "User canceled.") != "" ]] ; then
					exit # ALT: continue
				fi
				if [[ "$NEW_COPY_NAME" != "" ]] ; then
					if [[ "$NEW_COPY_NAME" == *".pub" ]] ; then
						CHOICE_BASENAME="${NEW_COPY_NAME%.pub}"
					else
						CHOICE_BASENAME="$NEW_COPY_NAME"
					fi
				else
					CHOICE_BASENAME="minisign"
				fi
				CHOICE_BASENAME="$CHOICE_BASENAME-$CURRENT_DATE.pub"
			else
				CHOICE_BASENAME="${CHOICE_BASENAME%.pub}"
				CHOICE_BASENAME="$CHOICE_BASENAME-$CURRENT_DATE.pub"
			fi
			cp "$PUBKEY_CHOICE" "$SIGS_DIR/$CHOICE_BASENAME" && rm -rf "$PUBKEY_CHOICE"
		fi
	fi
fi

# info window
INFO=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.minisign:lcars.png"
	set userChoice to button returned of (display dialog "$INFO_TXT" ¬
		buttons {"OK"} ¬
		default button 1 ¬
		with title "Results" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOT)

# bye
exit
