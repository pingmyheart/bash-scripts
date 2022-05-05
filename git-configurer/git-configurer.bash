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
readonly EXTERNAL_BINARIES="jq git xargs column"

### Args
LOG_LEVEL="STABLE"
PROFILE=""
CONFIG_FILE=""
SHOW_CONF="FALSE"

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

Description  : Git configure profile on local project.
               Advice: Create an alias to call it directly from everywhere

Example usage:
bash git-configurer.bash --config path/to/config.json --list
bash git-configurer.bash --config path/to/config.json -p profile_name_from_json_config

Options:
  [-h | --help]                      Display this help message
  [-v | --verbose]        (OPTIONAL) More verbose output
  [--trace]               (OPTIONAL) Set -o xtrace
  [-p | --profile]                   Specify profile to be used
  [--config]                         Specify json configuration file
  [--list]                           Show all profiles config availlable
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
    return 0
  fi
  error_exit "Configuration file is invalid or corrupted. Aborting..."
}

check_git_repo() {
  if git status >/dev/null 2>&1; then
    return 0
  fi
  error_exit "Not a git repo"
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
  -p | --profile)
    PROFILE=$2
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
if [[ -z "$PROFILE" && "$SHOW_CONF" == "FALSE" ]]; then
  error_exit "profile - missing parameter"
fi
sed -E -i "s/%uuid%/$(uuidgen)/g" "$CONFIG_FILE"
check_non_corrupted_json "$CONFIG_FILE"

### Main logic
# shellcheck disable=SC2002
_credentials=$(cat "$CONFIG_FILE" | jq .git)
_table_credentials="UUID PROFILE USERNAME EMAIL"
for row in $(echo "${_credentials}" | jq -r '.[] | @base64'); do
  _jq() {
    echo ${row} | base64 --decode | jq -r ${1}
  }
  _table_credentials+=" $(_jq .uuid)"
  _table_credentials+=" $(_jq .profile)"
  _table_credentials+=" $(_jq .username)"
  _table_credentials+=" $(_jq .email)"
done
log_debug "$_table_credentials"
if [[ "$SHOW_CONF" == "TRUE" ]]; then
  # shellcheck disable=SC2059
  printf "${_table_credentials[@]}" | xargs -n4 | column -t -c 50
  graceful_exit
fi

check_git_repo

for row in $(echo "${_credentials}" | jq -r '.[] | @base64'); do
  _jq() {
    echo ${row} | base64 --decode | jq -r ${1}
  }
  if [[ "$(_jq .profile)" == "$PROFILE" ]]; then
    git config user.name "$(_jq .username)" &>/dev/null
    git config user.email "$(_jq .email)" &>/dev/null
    git config --list
    graceful_exit
  fi
done

###
error_exit "No profile found"
