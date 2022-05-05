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
readonly EXTERNAL_BINARIES="jq"

### Args
LOG_LEVEL="STABLE"
SHOW_CONF="FALSE"
CONFIG_FILE=""
NAME=""

### Var
# shellcheck disable=SC2089
readonly curlz="curl -s -o curl_response.json -w \"%{json}\""

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

Description  : SSH to specific server from configuration file,
Example usage: 

Options:
  [-h | --help]                      Display this help message
  [-v | --verbose]        (OPTIONAL) More verbose output
  [--trace]               (OPTIONAL) Set -o xtrace
  [--version]                        Show program version
  [-n | --name]                      Resource name
  [--config]                         Specify json configuration file
  [--list]                           Show all servers config available
_EOF_
  return
}

### Func
log_debug() {
  local l_message
  l_message="$1"

  if [ $LOG_LEVEL == "DEBUG" ]; then
    echo "[DEBUG] - $l_message"
  fi
}

log_info() {
  local l_message
  l_message="$1"

  if [ $LOG_LEVEL == "STABLE" ]; then
    echo "[INFO] - $l_message"
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
  --version)
    printf "Running version: %s\n" "$PROGRAM_VERSION"
    graceful_exit
    ;;
  -n | --name)
    NAME=$2
    ;;
  --config)
    CONFIG_FILE=$2
    ;;
  --list)
    SHOW_CONF="TRUE"
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
if [[ -z "$NAME" && "$SHOW_CONF" == "FALSE" ]]; then
  error_exit "name - missing parameter"
fi
sed -E -i "s/%uuid%/$(uuidgen)/g" "$CONFIG_FILE"

### Main logic
# shellcheck disable=SC2002
_servers=$(cat "$CONFIG_FILE" | jq .servers)
_table_servers="UUID NAME ADDRESS USER PORT KEY"
for row in $(echo "${_servers}" | jq -r '.[] | @base64'); do
  _jq() {
    echo ${row} | base64 --decode | jq -r ${1}
  }
  _table_servers+=" $(_jq .uuid)"
  _table_servers+=" $(_jq .name)"
  _table_servers+=" $(_jq .ip_address)"
  _table_servers+=" $(_jq .user)"
  _table_servers+=" $(_jq .port)"
  _table_servers+=" $(_jq .ssh_key)"
done

# shellcheck disable=SC2059
if [[ "$SHOW_CONF" == "TRUE" ]]; then
  printf "${_table_servers[@]}" | xargs -n6 | column -t -c 50
  graceful_exit
fi

for row in $(echo "${_servers}" | jq -r '.[] | @base64'); do
  _jq() {
    echo ${row} | base64 --decode | jq -r ${1}
  }
  log_debug "JQ name $(_jq .name) , Search name $NAME"
  if [[ "$(_jq .name)" == "$NAME" ]]; then
    # shellcheck disable=SC2046
    ssh -i $(_jq .ssh_key) $(_jq .user)@$(_jq .ip_address) -p $(_jq .port)
    graceful_exit
  fi
done

###
error_exit "No server found with name $NAME"
