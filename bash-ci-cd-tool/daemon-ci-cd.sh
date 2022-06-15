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
readonly EXTERNAL_BINARIES="jq docker docker-compose sed git"
readonly EXTERNAL_SOURCES="source.sh functions.sh"

### Args
LOG_LEVEL="STABLE"

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
    if ! hash "$_ext_bin" &>/dev/null; then
      error_exit "Required binary $_ext_bin not found."
    fi
  done
}

load_sources() {
  for _ext_src in $EXTERNAL_SOURCES; do
    printf "Loading %s\n" "$_ext_src"
    # shellcheck disable=SC1090
    if ! source "$_ext_src" &>/dev/null; then
      error_exit "[$_ext_src] - Source import returned non-zero code"
    fi
  done
}

help_message() {
  cat <<-_EOF_

Description  : Git clone via SSH a set of project under a specific groupId,
               projects will be cloned in launch directory.
Example usage:

Options:
  [-h | --help]                      Display this help message
  [-v | --verbose]        (OPTIONAL) More verbose output
  [--trace]               (OPTIONAL) Set -o xtrace
  [--version]                        Show program version
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

### Load Sources
load_sources

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
  --* | -*)
    usage >&2
    error_exit "Unknown option $1"
    ;;
  esac
  shift
done

### Checking args

### Main logic
# Create cache file and start all projects
for row in $(echo "$PROJECTS" | jq -r '.[] | @base64'); do
  _jq() {
    echo "${row}" | base64 --decode | jq -r "${1}"
  }
  _compose_uuid=$(echo -e "$(_jq .uuid)")
  _compose_path=$(echo -e "$(_jq .compose_path)")
  cp "$_compose_path" ./cache/"$_compose_uuid"
  docker-compose -f "$_compose_path" up -d --build
done

# Daemon Section
while [ 1 == 1 ]; do
  for row in $(echo "$PROJECTS" | jq -r '.[] | @base64'); do
    _jq() {
      echo "${row}" | base64 --decode | jq -r "${1}"
    }
    _compose_uuid=$(echo -e "$(_jq .uuid)")
    _compose_path=$(echo -e "$(_jq .compose_path)")
    _compose_directory=$(dirname "$_compose_path")

    check_repo_and_pull "$_compose_directory" "$VERSION_CONTROL_DEFAULT_BRANCH"

    # if there are differences between cached file and docker-compose
    if ! diff ./cache/"$_compose_uuid" "$_compose_path" &>/dev/null; then
      # Differences found
      # Refresh docker-compose affected
      if docker-compose -f "$_compose_path" up -d --build &>/dev/null; then
        # if new docker compose works, copy it into cache
        cp "$_compose_path" ./cache/"$_compose_uuid"
      fi
    fi

  done

  sleep "$DAEMON_CHECK_RATE"
done

###
graceful_exit
