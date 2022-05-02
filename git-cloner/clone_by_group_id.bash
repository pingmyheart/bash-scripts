#!/usr/bin/env bash

### Trap signals
signal_exit() {
    local l_signal
    l_signal="$1"

    case "$l_signal" in
    INT)
        error_exit "Program interrupted by user"
        ;;
    TERM)
        error_exit "Program terminated"
        ;;
    *)
        error_exit "Terminating on unknown signal"
        ;;
    esac
}

trap "signal_exit TERM" TERM HUP
trap "signal_exit INT" INT

### Const
readonly PROGRAM_NAME=${0##*/}
readonly PROGRAM_VERSION="1.0.0"
readonly EXTERNAL_BINARIES="git jq sed curl base64 head awk uuidgen"

### Args
LOG_LEVEL="STABLE"
GROUP_ID=""
TOKEN=""
GITLAB_IP=""
CONFIG_FILE=""
METHOD=".ssh_url_to_repo"

### Var

### Welcome
printf "Hello %s - Welcome to %s v%s\n" "$(whoami)" "$PROGRAM_NAME" "$PROGRAM_VERSION"

# Helpers
clean_up() {
    return
}

error_exit() {
    local l_error_message
    l_error_message="$1"

    printf "[ERROR] - %s\n" "${l_error_message:-'Unknown Error'}" >&2
    echo "Exiting with exit code 1"
    clean_up
    exit 1
}

graceful_exit() {
    clean_up
    exit 0
}

load_libraries() {
    for _ext_bin in $EXTERNAL_BINARIES; do
        if ! which "$_ext_bin" &>/dev/null; then
            error_exit "Required binary $_ext_bin not found."
        fi
    done
}

help_message() {
    cat <<-_EOF_

Description  : Git clone via SSH(default behaviour without --https flag) a set of project 
               under a specific groupId, projects will be cloned in specific directory created through api infos.

Example usage: 
bash clone_by_goup_id.bash --config path/to/config.json --https
bash clone_by_goup_id.bash --config path/to/config.json

Options:
  [-h | --help]                      Display this help message
  [-v | --verbose]        (OPTIONAL) More verbose output
  [--trace]               (OPTIONAL) Set -o xtrace
  [--config]                         Specify configuration json file
  [--https]                          Clone repos with https instead of default ssh
_EOF_
    return
}

### Func
log_debug() {
    local l_message
    l_message="$1"

    if [ $LOG_LEVEL == "DEBUG" ]; then
        echo "$l_message"
    fi
}


ask_user_permission() {
    local l_message
    l_message="$1"

    printf "%s (y/n): " "$l_message"

    local l_continue
    read -r l_continue

    if [ "$l_continue" == "y" ]; then
        echo "OK"
    elif [ "$l_continue" == "n" ]; then
        graceful_exit
    else
        echo "Invalid choice [$l_continue]! Retrying..."
        ask_user_permission "$l_message"
    fi
}

check_non_corrupted_json() {
		local _json=$1
		# shellcheck disable=SC2002
		if cat "$_json" | jq -e . >/dev/null 2>&1; then
			if cat "$_json" | grep gitlab_ip >/dev/null 2>&1; then
					if cat "$_json" | grep group_id >/dev/null 2>&1; then
							# shellcheck disable=SC2086
							if cat $_json | grep token >/dev/null 2>&1; then
									return 0
							fi
					fi
			fi
		fi
		error_exit "Configuration file is invalid or corrupted. Aborting..."
}

### Check binaries
load_libraries

### Parse args
while [[ -n "$1" ]]; do
    case "$1" in
    -h | --help)
        help_message
        graceful_exit
        ;;
    -v | --verbose)
        LOG_LEVEL="DEBUG"
        ;;
    --trace)
        set -o xtrace
        ;;
    --config)
        CONFIG_FILE=$2
        ;;
    --https)
      METHOD=".http_url_to_repo"
        ;;
    --* | -*)
        usage >&2
        error_exit "Unknown option $1"
        ;;
    esac
    shift
done

### Checking args
if [[ -z "$CONFIG_FILE" ]]; then
  error_exit "config file - missing parameter"
fi

check_non_corrupted_json "$CONFIG_FILE"

# shellcheck disable=SC2002
GITLAB_IP=$(cat "$CONFIG_FILE" | jq .gitlab_ip | sed -e "s/\"//g")
# shellcheck disable=SC2002
GROUP_ID=$(cat "$CONFIG_FILE" | jq .group_id | sed -e "s/\"//g")
# shellcheck disable=SC2002
TOKEN=$(cat "$CONFIG_FILE" | jq .token | sed -e "s/\"//g" | base64 -d)

### Main logic
evaluate_curl=$(curl -o - -I --header "PRIVATE-TOKEN: ${TOKEN}" "${GITLAB_IP}/api/v4/groups/${GROUP_ID}/projects?per_page=1000000" | head -n1 | awk '{print $2}')
if [ "$evaluate_curl" -gt "300" ]; then
  error_exit "Curl failed with status code: $evaluate_curl"
else
  echo -e "\nCurl successfully tested\n"
fi

_json_response=$(curl --header "PRIVATE-TOKEN: ${TOKEN}" "${GITLAB_IP}/api/v4/groups/${GROUP_ID}/projects?per_page=1000000")
for row in $(echo "${_json_response}" | jq -r '.[] | @base64'); do
	_jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }
   # shellcheck disable=SC2207
   projects+=($(_jq "$METHOD"))
done

#_folder=$(curl --header "PRIVATE-TOKEN: ${TOKEN}" "${GITLAB_IP}/api/v4/groups/${GROUP_ID}" | jq '.web_url' | sed -e 's/"//g' -e 's|https://||g' -e 's|http://||g' -e 's|/|-|g' -e 's/\./_/g')
_folder=$(curl --header "PRIVATE-TOKEN: ${TOKEN}" "${GITLAB_IP}/api/v4/groups/${GROUP_ID}" | jq '.full_path' | sed -e 's/"//g' -e 's|/|-|g' -e 's/\./_/g')
_pwd=$(pwd)
if [ -d "$_folder" ]; then
	ask_user_permission "Folder $_folder already exists. Delete and override?"
	rm -rf "$_folder"
fi
mkdir "$_folder"
cd "$_folder"

# shellcheck disable=SC2068
for _p in ${projects[@]}; do
	# shellcheck disable=SC2034
	_proj=$(echo ${_p} | rev | cut -d/ -f1 | rev | sed -r "s/.git//g")
	git clone "${_p}"
done

# shellcheck disable=SC2012
for _d in $(ls -la --ignore=. --ignore=.. | awk '{print $9}'); do
	if [[ -d "${_d}" ]]; then
		# shellcheck disable=SC2164
		cd "${_d}"
		git branch -a | grep develop
		# shellcheck disable=SC2181
		if [[ "$?" -eq 0 ]]; then
			git checkout develop
		fi
	fi
	cd ..
done

# shellcheck disable=SC2164
cd "$_pwd"

###
graceful_exit

