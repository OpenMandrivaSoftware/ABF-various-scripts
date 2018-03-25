#!/bin/bash
# Author: Tomasz Pawel Gajc tpgxyz@gmail.com 2015
# GPL

if [ "$(id -u)" != '0' ]; then
    printf '%s\n'  "Can not run as non root user! Exiting"
    exit 1
fi

[ "$(pidof -o %PPID -x $(basename $0))" ] && printf '%s\n' "Signing rpm proces is currently running." && exit 1

# use only allowed arguments
if [ $# -ge 1 ]; then
    for k in "$@"; do
	case "$k" in
	    --repository=*)
		REPOSITORY=${k#*=}
		shift
		;;
	esac
	shift
    done
else
    printf '%s\n'  "Please run script with --repository= argument."
    exit 1
fi

SECRET="SET PATH TO YOUR SECRET FILE"
[ ! -e "${SECRET}" ] && printf '%s\n' "Your secret file does not exist. Exiting." && exit 255

KEYNAME="$(gpg --list-public-keys --homedir /root/.gnupg |sed -n 4p | awk '{ print $1 }' | awk '{print substr($0,length-7,9)}'| awk '{ sub(/.*\//, ""); print tolower($0) }')"

if [ "${KEYNAME^^}" != 'BF81DE15' ]; then
    printf '%s\n'  "Wrong GPG key! Please check your rpm macros. Exiting."
    exit 1
fi

GPG_PASS="$(echo y1ahka0j | tr 'A-Za-z' 'N-ZA-Mn-za-m')"

sign_rpms() {
    REPOSITORY=$1
    LAST_RPMS="$(dirname "$0")/LAST_RPMS.lst"

# /home/abf-downloads/cooker/repository/x86_64/main/release/
    NEW_ARRAY=($(find $REPOSITORY/{cooker,openmandriva*,3.0}/repository -type f -name "*.rpm" -cmin -1500 -printf '%h/%f\n' | sort -u))
    if [ ${#NEW_ARRAY[@]} -gt 0 ]; then
	printf '%s\n'  "New RPM files found: ${#NEW_ARRAY[@]}"
	printf '%s\n'  "Checking old result..."

	if [ -e "$LAST_RPMS" ]; then
	    readarray -t OLD_ARRAY < "$LAST_RPMS"
	else
	    touch "$LAST_RPMS"
	fi

	OLD="${OLD_ARRAY[*]}"
	for item in "${NEW_ARRAY[@]}"; do
	    if ! [[ $OLD =~ $item ]]; then
		RESULT+=("$item")
	    fi
	done

	if [ ${#RESULT[@]} -eq 0 ]; then
	    printf '%s\n'  "No new RPM files needs signing."
	    exit 255
	else
	    printf '%s\n'  "New RPM files to sign check: ${#RESULT[@]}"
        fi

    else
	exit 255
    fi

    printf '%s\n'  "Key used to sign rpm files: ${KEYNAME}"
    for i in ${RESULT[*]}; do
	has_key="$(rpm -Kv "$i" | grep 'key ID' | grep -ow ${KEYNAME,,})"
	if [ "${has_key}" != "${KEYNAME,,}" ]; then
	    printf '%s\n'  "--> Starting to sign $i"
	    chmod 0666 "$i";
	    cat /dev/null | setsid rpm \
	    --define "_gpg_name '$KEYNAME'" \
	    --define "__gpg /usr/bin/gpg" \
	    --define "_signature gpg" \
	    --define "__gpg_check_password_cmd /bin/true" \
	    --define "__gpg_sign_cmd %{__gpg} gpg --no-tty --pinentry-mode loopback --batch --no-armor --digest-algo 'sha512' --passphrase-file '$SECRET' --no-secmem-warning -u '%{_gpg_name}' --sign --detach-sign --output %{__signature_filename} %{__plaintext_filename}" \
	    --resign "$i" >/dev/null 2>&1;
	    chmod 0644 "$i";
	fi

# Save exit code
	rc=$?
	if [ "$rc" != '0' ] ; then
	    printf '%s\n'  "--> RPM file $i has not been signed successfully!"
	    exit 255
	fi
	printf '%s\n' "${i}" >> "${LAST_RPMS}"
    done

    printf '%s\n' "${RESULT[@]}" > "${LAST_RPMS}"
}


sign_rpms "${REPOSITORY}"
