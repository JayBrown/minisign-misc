#!/bin/bash

# minisign-verify v1.5 (shell script version)

LANG=en_US.UTF-8
export PATH=/usr/local/bin:$PATH
ACCOUNT=$(who am i | /usr/bin/awk '{print $1}')
CURRENT_VERSION="1.5"

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

# look for minisign binary
MINISIGN=$(which minisign 2>&1)
if [[ "$MINISIGN" == "minisign not found" ]] || [[ "$MINISIGN" == "which: no minisign in"* ]] ; then
	notify "Error: minisign not found" "Please install minisign first"
	exit
fi

# touch JayBrown public key file
if [[ ! -e "$PUBKEY_LOC" ]] ; then
	touch "$PUBKEY_LOC"
	echo -e "untrusted comment: minisign public key 37D030AC5E03C787\nRWSHxwNerDDQN8RlBeFUuLkB9bPqsR2T6es0jmzguvpvqWiXjxzTfaRY" > "$PUBKEY_LOC"
fi

# check for update
NEWEST_VERSION=$(/usr/bin/curl --silent https://api.github.com/repos/JayBrown/minisign-misc/releases/latest | /usr/bin/awk '/tag_name/ {print $2}' | xargs)
NEWEST_VERSION=${NEWEST_VERSION//,}
if [[ $NEWEST_VERSION>$CURRENT_VERSION ]] ; then
	notify "Update available" "Minisign Miscellanea v$NEWEST_VERSION"
	/usr/bin/open "https://github.com/JayBrown/minisign-misc/releases/latest"
fi

# check for false input
VER_FILE="$1"
TARGET_NAME=$(/usr/bin/basename "$VER_FILE")
if [[ "$VER_FILE" == *".minisig" ]] || [[ "$VER_FILE" == *".pub" ]] || [[ "$VER_FILE" == *".key" ]]; then
	notify "Error: wrong file" "$TARGET_NAME"
	exit
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
	set theDirectory to (path to downloads folder from user domain)
	set aKey to choose file with prompt "Locate the signature (.minisig) file for " & "$TARGET_NAME" & "…" default location theDirectory without invisibles
	set theKeyPath to (POSIX path of aKey)
end tell
theKeyPath
EOT)
	if [[ "$MINISIG_LOC" == "" ]] || [[ "$MINISIG_LOC" == "false" ]] ; then
		exit
	elif [[ "$MINISIG_LOC" != *".minisig" ]] ; then
		CHOICE_BASENAME=$(/usr/bin/basename "$MINISIG_LOC")
		notify "Error: not a .minisig file" "$CHOICE_BASENAME"
		exit
	fi
fi

# choose: enter pub key or choose pub key file
METHOD_ALL=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.minisign:lcars.png"
	set {theButton, theReply} to {button returned, text returned} of (display dialog "Enter a minisign public key or select a local public key (.pub) file." ¬
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
	exit
fi
METHOD=$(echo "$METHOD_ALL" | /usr/bin/awk -F@@@ '{print $1}')
PUBKEY=$(echo "$METHOD_ALL" | /usr/bin/awk -F@@@ '{print $2}')
if [[ "$PUBKEY" == "@@@"* ]] || [[ "$METHOD" == *"@@@" ]] ; then
	notify "Internal error" "Could not parse input"
	exit
fi

# choose public key file or enter public key file name, if user wants to save
if [[ "$METHOD_ALL" == "keyfile@@@"* ]] ; then
	PUBKEY_CHOICE=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theKeyDirectory to (((path to documents folder from user domain) as text) & "minisign") as alias
	set aKey to choose file with prompt "Select the relevant minisign public key (.pub) file…" default location theKeyDirectory without invisibles
	set theKeyPath to (POSIX path of aKey)
end tell
theKeyPath
EOT)
	if [[ "$PUBKEY_CHOICE" == "" ]] || [[ "$PUBKEY_CHOICE" == "false" ]] ; then
		exit
	fi
	if [[ "$PUBKEY_CHOICE" != *".pub" ]]; then
		CHOICE_BASENAME=$(/usr/bin/basename "$PUBKEY_CHOICE")
		notify "Error: not a .pub file" "$CHOICE_BASENAME"
		exit
	fi
	CHOICE_DIR=$(/usr/bin/dirname "$PUBKEY_CHOICE")
	CHOICE_BASENAME=$(/usr/bin/basename "$PUBKEY_CHOICE")
	if [[ "$CHOICE_DIR" != "$SIGS_DIR" ]] ; then
		cp "$PUBKEY_CHOICE" "$SIGS_DIR/$CHOICE_BASENAME"
	fi
	PUBKEY_LOC="$SIGS_DIR/$CHOICE_BASENAME"
elif [[ "$METHOD" == "key" ]] ; then
	if [[ "$PUBKEY" == "" ]] ; then
		notify "Internal error" "Could not parse input"
		exit
	else
		SAVE_CHOICE=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.minisign:lcars.png"
	set theButton to button returned of (display dialog "Do you want to save this public key in a .pub file for later use?" ¬
		buttons {"Cancel", "Verify Only", "Save"} ¬
		default button 3 ¬
		with title "Save Public Key File" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
theButton
EOT)
		if [[ "$SAVE_CHOICE" == "" ]] || [[ "$SAVE_CHOICE" == "false" ]] ; then
			exit
		fi
		if [[ "$SAVE_CHOICE" == "Save" ]] ; then
			SAVE_STATUS="true"
			NEW_PUBKEY_NAME=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.minisign:lcars.png"
	set theReply to text returned of (display dialog "Please enter the file name of the new public key file. The current date and the suffix .pub will added automatically." ¬
		default answer "" ¬
		buttons {"Cancel", "Enter"} ¬
		default button 2 ¬
		with title "Save Public Key File" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
theReply
EOT)
			if [[ "$NEW_PUBKEY_NAME" == "" ]] || [[ "$NEW_PUBKEY_NAME" == "false" ]] ; then
				exit
			fi
			CURRENT_DATE=$(date +%Y%m%d-%H%M%S)
			if [[ "$NEW_PUBKEY_NAME" == *".pub" ]] ; then
				NEW_PUBKEY_NAME="${NEW_PUBKEY_NAME%.*}"
			fi
			PUBKEY_LOC="$SIGS_DIR/$NEW_PUBKEY_NAME-$CURRENT_DATE.pub"
			echo -e "untrusted comment: minisign public key \n$PUBKEY" > "$PUBKEY_LOC"
		elif [[ "$SAVE_CHOICE" == "Verify Only" ]] ; then
			SAVE_STATUS="false"
		fi
	fi
else
	notify "Internal error" "Could not parse input"
	exit
fi

# verify
if [[ "$METHOD" == "keyfile" ]] || [[ "$SAVE_STATUS" == "true" ]] ; then
	MS_OUT=$("$MINISIGN" -V -x "$MINISIG_LOC" -p "$PUBKEY_LOC" -m "$VER_FILE")
else
	MS_OUT=$("$MINISIGN" -V -x "$MINISIG_LOC" -P "$PUBKEY" -m "$VER_FILE")
fi
if [[ $(echo "$MS_OUT" | /usr/bin/grep "Signature and comment signature verified") == "" ]] ; then
	notify "Verification error" "$TARGET_NAME"
	exit
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

# additional checksums (optional); uncomment if needed, then extend $INFO_TXT and $CLIPBOARD_TXT
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

# notify
notify "Verification successful" "$TARGET_NAME"

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
$MS_OUT_INFO

This information has also been copied to your clipboard"

CLIPBOARD_TXT="File: $TARGET_NAME
Size: $SIZE MB
Hash (SHA-2, 256 bit): $CHECKSUM21
Untrusted minisign comment: $UNTRUSTED_COMMENT
Trusted minisign comment: $TRUSTED_COMMENT
Minisign output: $MS_OUT_INFO"

# send info to clipboard
echo "$CLIPBOARD_TXT" | /usr/bin/pbcopy

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
