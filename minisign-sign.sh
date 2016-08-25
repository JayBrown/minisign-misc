#!/bin/bash

# Minisign Miscellanea v1.7.2
# minisign-sign (shell script version)

LANG=en_US.UTF-8
export PATH=/usr/local/bin:$PATH
ACCOUNT=$(/usr/bin/id -un)
CURRENT_VERSION="1.72"

# check compatibility & determine correct Mac OS name
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
if [[ "$MACOS2NO" -ge 12 ]] ; then
	OSNAME="macOS"
elif [[ "$MACOS2NO" -ge 8 ]] && [[ "$MACOS2NO" -le 11 ]] ; then
	OSNAME="OS X"
elif [[ "$MACOS2NO" -le 7 ]] ; then # leaving Mac OS X 7, in case someone manages to add Growl support for himself
	OSNAME="Mac OS X"
fi

# set notification function
notify () {
 	if [[ "$NOTESTATUS" == "osa" ]] ; then
		/usr/bin/osascript -e 'display notification "$2" with title "minisign [$ACCOUNT]" subtitle "$1"' &>/dev/null
	elif [[ "$NOTESTATUS" == "tn" ]] ; then
		"$TERMNOTE_LOC/Contents/MacOS/terminal-notifier" \
			-title "minisign [$ACCOUNT]" \
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
PKREMOVAL_DIR="$SIGS_DIR/removed"
if [[ ! -e "$PKREMOVAL_DIR" ]] ; then
	mkdir -p "$PKREMOVAL_DIR"
fi
PRIVATE_DIR="${HOME}/.minisign"
if [[ ! -e "$PRIVATE_DIR" ]] ; then
	mkdir -p "$PRIVATE_DIR"
fi
REMOVAL_DIR="$PRIVATE_DIR/removed"
if [[ ! -e "$REMOVAL_DIR" ]] ; then
	mkdir -p "$REMOVAL_DIR"
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

# decode icon
ICON="$CACHE_DIR/lcars.png"
if [[ ! -e "$ICON" ]] ; then
	echo "$ICON64" > "$CACHE_DIR/lcars.base64"
	/usr/bin/base64 -D -i "$CACHE_DIR/lcars.base64" -o "$ICON" && rm -rf "$CACHE_DIR/lcars.base64"
fi
if [[ -e "$CACHE_DIR/lcars.base64" ]] ; then
	rm -rf "$CACHE_DIR/lcars.base64"
fi

# look for minisign binary & check version (prehashing)
MINISIGN=$(which minisign 2>&1)
if [[ "$MINISIGN" != "/"*"/minisign" ]] ; then
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
PUBKEY_NAME="jaybrown-github.pub"
PUBKEY_LOC="$SIGS_DIR/$PUBKEY_NAME"
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

SIGN_FILE="$1" # ALT: for SIGN_FILE in "$@" ### do

# check for false input
TARGET_NAME=$(/usr/bin/basename "$SIGN_FILE")
if [[ ! -f "$SIGN_FILE" ]] ; then
	PATH_TYPE=$(/usr/bin/mdls -name kMDItemContentTypeTree "$SIGN_FILE" | /usr/bin/grep -e "bundle")
	if [[ "$PATH_TYPE" != "" ]] ; then
		notify "Error: target is a bundle" "$TARGET_NAME"
		exit # ALT: continue
	fi
	if [[ -d "$SIGN_FILE" ]] ; then
		notify "Error: target is a directory" "./$TARGET_NAME"
		exit # ALT: continue
	fi
fi
if [[ "$SIGN_FILE" == *".minisig" ]] || [[ "$SIGN_FILE" == *".pub" ]] || [[ "$SIGN_FILE" == *".key" ]]; then
	notify "Error: minisign filetype" "$TARGET_NAME"
	exit # ALT: continue
fi

# settings
TARGET_DIR=$(/usr/bin/dirname "$SIGN_FILE")
MINISIG_NAME="$TARGET_NAME.minisig"
MINISIG_LOC="$TARGET_DIR/$MINISIG_NAME"

# delete private keys & associated passwords, whose public key counterparts have been manually deleted from the public "removed" subdirectory
PKRM_LIST=$(find "$PKREMOVAL_DIR" -maxdepth 1 -name \*.pub | /usr/bin/rev | /usr/bin/awk -F/ '{print $1}' | /usr/bin/awk -F. '{print substr($0, index($0,$2))}' | /usr/bin/rev | /usr/bin/sort -n)
SKRM_LIST=$(find "$REMOVAL_DIR" -maxdepth 1 -name \*.key | /usr/bin/rev | /usr/bin/awk -F/ '{print $1}' | /usr/bin/awk -F. '{print substr($0, index($0,$2))}' | /usr/bin/rev | /usr/bin/sort -n)
DIFF=$(/usr/bin/comm -13 <( echo "$PKRM_LIST" | /usr/bin/sort -n) <( echo "$SKRM_LIST" | /usr/bin/sort -n))
if [[ "$DIFF" != "" ]] ; then
	echo "$DIFF" | while IFS= read -r PKRM
	do
		rm -rf "$REMOVAL_DIR/$PKRM.key"
		/usr/bin/security delete-generic-password -D "application password" -l "minisign-$PKRM" -s "minisign-$PKRM" -a "$ACCOUNT" &>/dev/null
	done
fi

# select private key from list if there is at least one
# BREAKER="false" # ADD: only for workflow
CONTINUE="false"
while [[ "$CONTINUE" == "false" ]]
do
	SK_LIST=$(find "$PRIVATE_DIR" -maxdepth 1 -name \*.key | /usr/bin/rev | /usr/bin/awk -F/ '{print $1}' | /usr/bin/awk -F. '{print substr($0, index($0,$2))}' | /usr/bin/rev | /usr/bin/sort -n)
	if [[ "$SK_LIST" != "" ]] ; then
		SKLIST_CHOICE=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theList to {}
	set theItems to paragraphs of "$SK_LIST"
	repeat with anItem in theItems
		set theList to theList & {(anItem) as string}
	end repeat
	set theList to theList & {"🔎 Locate manually…", "➤ Create new key pair", "🔐 Update key password", "✖︎ Remove key pair"}
	set AppleScript's text item delimiters to return & linefeed
	set theResult to choose from list theList with prompt "Choose one of your existing private keys to sign the file, or use one of the alternate options." with title "Sign $TARGET_NAME" OK button name "Select" cancel button name "Cancel" without multiple selections allowed
	return the result as string
	set AppleScript's text item delimiters to ""
end tell
theResult
EOT)
		if [[ "$SKLIST_CHOICE" == "" ]] || [[ "$SKLIST_CHOICE" == "false" ]] ; then
			exit # ALT: break with CONTINUE="true" && BREAKER="true"
		fi
		if [[ "$SKLIST_CHOICE" == "🔎 Locate manually…" ]] ; then
			MS_METHOD="key"
			CONTINUE="true"
		elif [[ "$SKLIST_CHOICE" == "➤ Create new key pair" ]] ; then
			MS_METHOD="new"
			CONTINUE="true"
		elif [[ "$SKLIST_CHOICE" == "🔐 Update key password" ]] ; then
			MS_METHOD="updpw"
			# select key for password update
			UPDPW_KEY_COUNT=$(echo "$SK_LIST" | /usr/bin/wc -l | xargs)
			if [[ "$UPDPW_KEY_COUNT" -gt 1 ]] ; then
				UPDPW_KEY=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theList to {}
	set theItems to paragraphs of "$SK_LIST"
	repeat with anItem in theItems
		set theList to theList & {(anItem) as string}
	end repeat
	set AppleScript's text item delimiters to return & linefeed
	set theResult to choose from list theList with prompt "Choose the key pair for password update." with title "Update Password" OK button name "Select" cancel button name "Cancel" without multiple selections allowed
	set AppleScript's text item delimiters to ""
end tell
theResult
EOT)
				if [[ "$UPDPW_KEY" == "" ]] || [[ "$UPDPW_KEY" == "false" ]] ; then
					exit # ALT: break with CONTINUE="true" && BREAKER="true"
				fi
			else
				UPDPW_KEY="$SK_LIST"
			fi
			# update password for existing key entry in the keychain
			NEW_KEYPW=$(/usr/bin/osascript 2>&1 << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.minisign:lcars.png"
	set thePassword to text returned of (display dialog "Enter the new password for the secret key \"" & "$UPDPW_KEY" & "\". It will be updated in your " & "$OSNAME" & " keychain." ¬
		default answer "" ¬
		with hidden answer ¬
		buttons {"Cancel", "Enter"} ¬
		default button 2 ¬
		with title "Update Password" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
thePassword
EOT)
			if [[ $(echo "$NEW_KEYPW" | /usr/bin/grep "User canceled.") != "" ]] ; then
				exit # ALT: break with CONTINUE="true" && BREAKER="true"
			fi
			if [[ "$NEW_KEYPW" == "" ]] ; then
				notify "Error: no password" "Exiting…"
				exit # ALT: break with CONTINUE="true" && BREAKER="true"
			else
				/usr/bin/security add-generic-password -U -D "application password" -s "minisign-$UPDPW_KEY" -l "minisign-$UPDPW_KEY" -a "$ACCOUNT" -T /usr/bin/security -w "$NEW_KEYPW"
				CONTINUE="false"
			fi
		elif [[ "$SKLIST_CHOICE" == "✖︎ Remove key pair" ]] ; then
			# choose keys from list to remove from main private key directory
			MS_METHOD="remove"
			RM_KEY_COUNT=$(echo "$SK_LIST" | /usr/bin/wc -l | xargs)
			if [[ "$RM_KEY_COUNT" -gt 1 ]] ; then
				REMOVAL_CHOICE=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theList to {}
	set theItems to paragraphs of "$SK_LIST"
	repeat with anItem in theItems
		set theList to theList & {(anItem) as string}
	end repeat
	set AppleScript's text item delimiters to return & linefeed
	set theResult to choose from list theList with prompt "Choose the key pair to remove." with title "Remove Key Pair" OK button name "Select" cancel button name "Cancel" with multiple selections allowed
	set AppleScript's text item delimiters to ""
end tell
theResult
EOT)
				if [[ "$REMOVAL_CHOICE" == "" ]] || [[ "$REMOVAL_CHOICE" == "false" ]] ; then
					exit # ALT: break with CONTINUE="true" && BREAKER="true"
				fi
				REMOVE=$(echo "$REMOVAL_CHOICE" | /usr/bin/sed -e $'s/, /\\\n/g')
				echo "$REMOVE" | while IFS= read -r RM_KEY
				do
					cp "$PRIVATE_DIR/$RM_KEY.key" "$REMOVAL_DIR/$RM_KEY.key" && rm -rf "$PRIVATE_DIR/$RM_KEY.key"
					if [[ -e "$SIGS_DIR/$RM_KEY.pub" ]] ; then
						cp "$SIGS_DIR/$RM_KEY.pub" "$PKREMOVAL_DIR/$RM_KEY.pub" && rm -rf "$SIGS_DIR/$RM_KEY.pub"
					fi
				done
			else
				cp "$PRIVATE_DIR/$SK_LIST.key" "$REMOVAL_DIR/$SK_LIST.key" && rm -rf "$PRIVATE_DIR/$SK_LIST.key"
				if [[ -e "$SIGS_DIR/$SK_LIST.pub" ]] ; then
					cp "$SIGS_DIR/$SK_LIST.pub" "$PKREMOVAL_DIR/$SK_LIST.pub" && rm -rf "$SIGS_DIR/$SK_LIST.pub"
				fi
			fi
			CONTINUE="false"
		else
			SIGNING_KEY="$PRIVATE_DIR/$SKLIST_CHOICE.key"
			KEYPAIR_NAME="${SKLIST_CHOICE%.key}"
			PUBKEY_LOC="$SIGS_DIR/$KEYPAIR_NAME.pub"
			if [[ ! -e "$PUBKEY_LOC" ]] ; then
				notify "Error: public key" "Key file is missing"
				PUBKEY_SEARCH=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theKeyDirectory to ((path to home folder from user domain) as text) as alias
	set aKey to choose file with prompt "The public key (.pub) file is missing. Please locate it…" default location theKeyDirectory with invisibles
	set theKeyPath to (POSIX path of aKey)
end tell
theKeyPath
EOT)
				if [[ "$PUBKEY_SEARCH" == "" ]] || [[ "$PUBKEY_SEARCH" == "false" ]] ; then
					exit # ALT: break with CONTINUE="true" && BREAKER="true"
				fi
				PUBKEY_SEARCHNAME=$(/usr/bin/basename "$PUBKEY_SEARCH")
				if [[ "$PUBKEY_SEARCH" != *".pub" ]] ; then
					notify "Error: not a .pub file" "$PUBKEY_SEARCHNAME"
					exit # ALT: break with CONTINUE="true" && BREAKER="true"
				fi
				if [[ "$PUBKEY_SEARCHNAME" != "$KEYPAIR_NAME.pub" ]] ; then
					notify "Error: public key" "Wrong filename"
					exit # ALT: break with CONTINUE="true" && BREAKER="true"
				else
					cp "$PUBKEY_SEARCH" "$PUBKEY_LOC" && rm -rf "$PUBKEY_SEARCH"
				fi
			fi
			CONTINUE="true"
			MS_METHOD="standard"
		fi
	else
		notify "Error: private key" "No private keys detected"
		INITIAL=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.minisign:lcars.png"
	set initialChoice to button returned of (display dialog "There are no keys stored in the default minisign private key directory. Do you want to create a new key pair, or manually locate existing keys?" ¬
		buttons {"Cancel", "Locate", "New"} ¬
		default button 3 ¬
		with title "Setup" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
initialChoice
EOT)
		if [[ "$INITIAL" == "New" ]] ; then
			MS_METHOD="new"
			CONTINUE="true"
		elif [[ "$INITIAL" == "Locate" ]] ; then
			MS_METHOD="key"
			CONTINUE="true"
		else
			exit # ALT: break with CONTINUE="true" && BREAKER="true"
		fi
	fi
done

# check if continue is necessary -- ADD: workflow version
# if [[ "$BREAKER" == "true" ]] ; then
	# continue
# fi

# check if password exists in keychain; enter previous password, if necessary
if [[ "$MS_METHOD" == "standard" ]] ; then
	KEYPAIR_PW=$(/usr/bin/security 2>&1 >/dev/null find-generic-password -s "minisign-$KEYPAIR_NAME" -ga "$ACCOUNT" | /usr/bin/ruby -e 'print $1 if STDIN.gets =~ /^password: "(.*)"$/' | xargs)
	if [[ "$KEYPAIR_PW" == "" ]] ; then
		notify "Error: private key" "No password for $KEYPAIR_NAME"
		KEYPAIR_PW=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.minisign:lcars.png"
	set thePassword to text returned of (display dialog "There is no password stored in your " & "$OSNAME" & " keychain for this secret key. Enter the password you chose when you created this key." ¬
		default answer "" ¬
		with hidden answer ¬
		buttons {"Cancel", "Enter"} ¬
		default button 2 ¬
		with title "Enter Password" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
thePassword
EOT)
		if [[ "$KEYPAIR_PW" == "" ]] || [[ "$KEYPAIR_PW" == "false" ]] ; then
			notify "Error: no password" "Exiting…"
			exit # ALT: continue
		else
			SK_MIGR=$(/usr/bin/sed -n '2p' "$SIGNING_KEY")
			if [[ ! -e "$PUBKEY_LOC" ]] ; then
				PK_MIGR="n/a"
			else
				PK_MIGR=$(/usr/bin/sed -n '2p' "$PUBKEY_LOC")
			fi
			CURRENT_DATE=$(/bin/date)
			KEY_INFO="Private key: $SK_MIGR

Public key: $PK_MIGR

Addition date: $CURRENT_DATE"
			/usr/bin/security add-generic-password -U -D "application password" -s "minisign-$KEYPAIR_NAME" -a "$ACCOUNT" -j "$KEY_INFO" -T /usr/bin/security -w "$KEYPAIR_PW"
		fi
	fi
fi

# generate new key pair, with overwrite option
if [[ "$MS_METHOD" == "new" ]] ; then
	# BREAKER="false" # ALT: only for workflow
	CONTINUE="false"
	while [[ "$CONTINUE" == "false" ]]
	do
		KEYPAIR_NEW=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.minisign:lcars.png"
	set {theButton, theReply} to {button returned, text returned} of (display dialog "Enter the name of the new minisign key pair." ¬
		default answer "" ¬
		buttons {"Cancel", "Enter & Overwrite", "Enter"} ¬
		default button 3 ¬
		with title "Enter Key Pair Name" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
theButton & "@DELIM@" & theReply
EOT)
		if [[ "$KEYPAIR_NEW" == "" ]] || [[ "$KEYPAIR_NEW" == "false" ]] || [[ "$KEYPAIR_NEW" == "@DELIM@" ]] ; then
			exit # ALT: break with CONTINUE="true" && BREAKER="true"
		fi
		NEWKEY_METHOD=$(echo "$KEYPAIR_NEW" | /usr/bin/awk -F"@DELIM@" '{print $1}')
		if [[ "$NEWKEY_METHOD" == "Enter & Overwrite" ]] ; then
			OVERWRITE="true"
		fi
		KEYPAIR_NAME=$(echo "$KEYPAIR_NEW" | /usr/bin/awk -F"@DELIM@" '{print substr($0, index($0,$2))}')
		if [[ "$OVERWRITE" != "true" ]] ; then
			if [[ -e "$PRIVATE_DIR/$KEYPAIR_NAME.key" ]] ; then
				notify "Error: private key" "This name is already in use"
				continue
			elif [[ -e "$SIGS_DIR/$KEYPAIR_NAME.pub" ]] ; then
				notify "Error: public key" "This name is already in use"
				continue
			fi
		fi

		# enter password for the new key pair or create random password
		KEYPW_ALL=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.minisign:lcars.png"
	set {theButton, thePassword} to {button returned, text returned} of (display dialog "Enter the password for the new secret key. Any whitespace will be replaced with an underscore. The password will be stored in your " & "$OSNAME" & " keychain under the item \"" & "minisign-$KEYPAIR_NAME" & "\"." ¬
		default answer "" ¬
		with hidden answer ¬
		buttons {"Cancel", "Random", "Enter"} ¬
		default button 3 ¬
		with title "Enter Password" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
theButton & "@DELIM@" & thePassword
EOT)
		if [[ "$KEYPW_ALL" == "" ]] || [[ "$KEYPW_ALL" == "false" ]] || [[ "$KEYPW_ALL" == "@DELIM@" ]] ; then
			exit # ALT: break with CONTINUE="true" && BREAKER="true"
		fi
		notify "Please wait!" "Creating new key pair…"
		KEYPW_METHOD=$(echo "$KEYPW_ALL" | /usr/bin/awk -F"@DELIM@" '{print $1}')
		if [[ "$KEYPW_METHOD" == "Random" ]] ; then
			KEYPAIR_PW=$(/usr/bin/openssl rand -base64 47 | /usr/bin/tr -d /=+ | /usr/bin/cut -c -32)
		elif [[ "$KEYPW_METHOD" == "Enter" ]] ; then
			KEYPAIR_PW=$(echo "$KEYPW_ALL" | /usr/bin/awk -F"@DELIM@" '{print substr($0, index($0,$2))}' | /usr/bin/sed -e 's/ /_/g')
		fi
		# minisign commands; write password to keychain on success
		CURRENT_DATE=$(/bin/date)
		if [[ "$OVERWRITE" != "true" ]] ; then
			MS_OUT=$((echo "$KEYPAIR_PW";echo "$KEYPAIR_PW") | "$MINISIGN" -G -p "$SIGS_DIR/$KEYPAIR_NAME.pub" -s "$PRIVATE_DIR/$KEYPAIR_NAME.key")
		elif [[ "$OVERWRITE" == "true" ]] ; then
			MS_OUT=$((echo "$KEYPAIR_PW";echo "$KEYPAIR_PW") | "$MINISIGN" -G -f -p "$SIGS_DIR/$KEYPAIR_NAME.pub" -s "$PRIVATE_DIR/$KEYPAIR_NAME.key")
		fi
		if [[ $(echo "$MS_OUT" | /usr/bin/grep "key was saved") != "" ]] ; then
			NEW_PUBKEY=$(echo "$MS_OUT" | /usr/bin/awk '/-Vm/ {print $5}')
			NEW_SECKEY=$(/usr/bin/sed -n '2p' "$PRIVATE_DIR/$KEYPAIR_NAME.key")
			KEY_INFO="Private key: $NEW_SECKEY

Public key: $NEW_PUBKEY

Creation date: $CURRENT_DATE"
			/usr/bin/security add-generic-password -U -D "application password" -s "minisign-$KEYPAIR_NAME" -a "$ACCOUNT" -j "$KEY_INFO" -T /usr/bin/security -w "$KEYPAIR_PW"
		else
			notify "Key pair creation error" "Something seems to have gone wrong"
			exit # ALT: break with CONTINUE="true" && BREAKER="true"
		fi
		SIGNING_KEY="$PRIVATE_DIR/$KEYPAIR_NAME.key"
		PUBKEY_LOC="$SIGS_DIR/$KEYPAIR_NAME.pub"
		CONTINUE="true"
	done
	# check if continue is necessary -- ADD: workflow version
	# if [[ "$BREAKER" == "true" ]] ; then
		# continue
	# fi
fi

# manually select existing private key (non-default location)
if [[ "$MS_METHOD" == "key" ]] ; then
	SIGNING_KEY=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theKeyDirectory to ((path to home folder from user domain) as text) as alias
	set aKey to choose file with prompt "Select your minisign secret key (.key) file…" default location theKeyDirectory with invisibles
	set theKeyPath to (POSIX path of aKey)
end tell
theKeyPath
EOT)
	if [[ "$SIGNING_KEY" == "" ]] || [[ "$SIGNING_KEY" == "false" ]] ; then
		exit # ALT: continue
	fi
	if [[ "$SIGNING_KEY" != *".key" ]] ; then
		notify "Error: not a .key file" "$SIGNING_KEY"
		exit # ALT: continue
	fi
	SEC_KEY_NAME=$(/usr/bin/basename "$SIGNING_KEY")
	SEC_KEY_DIR=$(/usr/bin/dirname "$SIGNING_KEY")
	if [[ "$SEC_KEY_DIR" == "$PRIVATE_DIR" ]] ; then
		notify "Notification" "Secret key already installed"
		SK_PARENT="true"
	else
		SK_PARENT="false"
	fi
	KEYPAIR_NAME="${SEC_KEY_NAME%.*}"
	PUBKEY_NAME="$KEYPAIR_NAME.pub"
	PUBKEY_LOC="$SIGS_DIR/$PUBKEY_NAME"
	if [[ -e "$PUBKEY_LOC" ]] ; then
		notify "Notification" "Public key already installed"
		PK_PARENT="true"
	else
		PK_PARENT="false"
		LOCATE_PUBKEY=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theKeyDirectory to ((path to home folder from user domain) as text) as alias
	set aKey to choose file with prompt "Locate the corresponding public key (.pub) file…" default location theKeyDirectory without invisibles
	set theKeyPath to (POSIX path of aKey)
end tell
theKeyPath
EOT)
		if [[ "$LOCATE_PUBKEY" == "" ]] || [[ "$LOCATE_PUBKEY" == "false" ]] ; then
			exit # ALT: continue
		fi
		if [[ "$LOCATE_PUBKEY" != *".pub" ]] ; then
			notify "Error: not a .pub file" "$LOCATE_PUBKEY"
			exit # ALT: continue
		fi
	fi
	# check if password exists in keychain for old key pair
	KEYPAIR_PW=$(/usr/bin/security 2>&1 >/dev/null find-generic-password -s "minisign-$KEYPAIR_NAME" -ga "$ACCOUNT" | /usr/bin/ruby -e 'print $1 if STDIN.gets =~ /^password: "(.*)"$/' | xargs)
	if [[ "$KEYPAIR_PW" == "" ]] ; then # ask for password, if there's none in the keychain
		KEYPAIR_PW=$(/usr/bin/osascript << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.minisign:lcars.png"
	set thePassword to text returned of (display dialog "There is no password stored in your " & "$OSNAME" & " keychain for this secret key. Enter the password you chose when you created this key." ¬
		default answer "" ¬
		with hidden answer ¬
		buttons {"Cancel", "Enter"} ¬
		default button 2 ¬
		with title "Enter Password" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
thePassword
EOT)
		if [[ "$KEYPAIR_PW" == "" ]] || [[ "$KEYPAIR_PW" == "false" ]] ; then
			notify "Error: no password" "Exiting…"
			exit # ALT: continue
		else
			NEW_PW="true"
		fi
	fi
	# copy private key & delete original; set copy as signing key
	if [[ "$SK_PARENT" != "true" ]] ; then
		cp "$SIGNING_KEY" "$PRIVATE_DIR/$SEC_KEY_NAME" && rm -rf "$SIGNING_KEY"
	fi
	SIGNING_KEY="$PRIVATE_DIR/$SEC_KEY_NAME"
	# copy public key & delete original
	if [[ "$PK_PARENT" != "true" ]] ; then
		cp "$LOCATE_PUBKEY" "$PUBKEY_LOC" && rm -rf "$LOCATE_PUBKEY"
	fi
	# add new keychain entry, if the password for the old key was entered manually
	if [[ "$NEW_PW" == "true" ]] ; then
		SK_MIGR=$(/usr/bin/sed -n '2p' "$SIGNING_KEY")
		PK_MIGR=$(/usr/bin/sed -n '2p' "$PUBKEY_LOC")
		CURRENT_DATE=$(/bin/date)
		KEY_INFO="Private key: $SK_MIGR

Public key: $PK_MIGR

Addition date: $CURRENT_DATE"
		/usr/bin/security add-generic-password -D "application password" -s "minisign-$KEYPAIR_NAME" -a "$ACCOUNT" -j "$KEY_INFO" -T /usr/bin/security -w "$KEYPAIR_PW"
	fi
fi

# enter trusted comment for .minisig file
TRUSTED=$(/usr/bin/osascript 2>&1 << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.minisign:lcars.png"
	set theComment to text returned of (display dialog "Enter a one-line trusted comment for your signature file. Leave blank to skip." ¬
		default answer "" ¬
		buttons {"Cancel", "Enter"} ¬
		default button 2 ¬
		with title "Enter Trusted Comment" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
theComment
EOT)
if [[ "$TRUSTED" == *"User canceled"* ]] ; then
	exit # ALT: continue
fi

# enter untrusted comment for .minisig file
UNTRUSTED=$(/usr/bin/osascript 2>&1 << EOT
tell application "System Events"
	activate
	set theLogoPath to ((path to library folder from user domain) as text) & "Caches:local.lcars.minisign:lcars.png"
	set theComment to text returned of (display dialog "Enter a one-line untrusted comment for your signature file. Leave blank to skip." ¬
		default answer "" ¬
		buttons {"Cancel", "Enter"} ¬
		default button 2 ¬
		with title "Enter Untrusted Comment" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
theComment
EOT)
if [[ "$UNTRUSTED" == *"User canceled"* ]] ; then
	exit # ALT: continue
fi

# target file size
BYTES=$(/usr/bin/stat -f%z "$SIGN_FILE")
MEGABYTES=$(/usr/bin/bc -l <<< "scale=6; $BYTES/1000000")
if [[ ($MEGABYTES<1) ]] ; then
	SIZE="0$MEGABYTES"
else
	SIZE="$MEGABYTES"
fi
LIMIT=$(echo $SIZE">"500 | /usr/bin/bc -l)
if [[ "$LIMIT" == "0" ]] ; then
	PREHASH="false"
elif [[ "$LIMIT" == "1" ]] ; then
	PREHASH="true"
fi

# sign target file
echo "Signing with: $SIGNING_KEY"
if [[ "$PREHASH" == "true" ]] ; then
	MS_OUT=$(echo "$KEYPAIR_PW" | "$MINISIGN" -S -H -x "$MINISIG_LOC" -s "$SIGNING_KEY" -c "$UNTRUSTED" -t "$TRUSTED" -m "$SIGN_FILE" 2>&1)
elif [[ "$PREHASH" == "false" ]] ; then
	MS_OUT=$(echo "$KEYPAIR_PW" | "$MINISIGN" -S -x "$MINISIG_LOC" -s "$SIGNING_KEY" -c "$UNTRUSTED" -t "$TRUSTED" -m "$SIGN_FILE" 2>&1)
fi
echo "---"
echo "$MS_OUT"

if [[ $(echo "$MS_OUT" | /usr/bin/grep "Wrong password for that key") != "" ]] ; then
	notify "Signing error" "Wrong password"
	exit # ALT: continue
elif [[ $(echo "$MS_OUT" | /usr/bin/grep "Deriving a key from the password and decrypting the secret key... done") == "" ]] ; then
	notify "Signing error" "Something went wrong"
	exit # ALT: continue
fi

# checksums
CHECKSUM21=$(/usr/bin/shasum -a 256 "$SIGN_FILE" | /usr/bin/awk '{print $1}')

# additional checksums (optional); uncomment if needed, then expand $INFO_TXT and $CLIPBOARD_TXT
# CHECKSUM5=$(/sbin/md5 -q "$SIGN_FILE")
# CHECKSUM1=$(/usr/bin/shasum -a 1 "$SIGN_FILE" | /usr/bin/awk '{print $1}')
# CHECKSUM22=$(/usr/bin/shasum -a 512 "$SIGN_FILE" | /usr/bin/awk '{print $1}')

# notify
notify "Signing successful" "$TARGET_NAME"

# read public key
if [[ ! -e "$PUBKEY_LOC" ]] ; then
	PUBKEY="n/a"
else
	PUBKEY=$(/usr/bin/sed -n '2p' "$PUBKEY_LOC" | xargs)
fi

# set info text
if [[ "$PREHASH" == "false" ]] ; then
	PREHASH_INFO="compatible with OpenBSD signify"
elif [[ "$PREHASH" == "true" ]] ; then
	PREHASH_INFO="not compatible with OpenBSD signify"
fi
INFO_TXT="■︎■■ File ■■■
$TARGET_NAME

■■■ Size ■■■
$SIZE MB

■︎■■ Hash (SHA-2, 256 bit) ■■■
$CHECKSUM21

■︎■■ Minisign public key ■■■
$PUBKEY

■︎■■ Prehashing ■︎■■
$PREHASH
[$PREHASH_INFO]

This information has also been copied to your clipboard"

# send info to clipboard
CLIPBOARD_TXT="File: $TARGET_NAME
Size: $SIZE MB
Hash (SHA-2, 256 bit): $CHECKSUM21
Minisign public key: $PUBKEY
Prehashing: $PREHASH [$PREHASH_INFO]"
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
exit # ALT: done
