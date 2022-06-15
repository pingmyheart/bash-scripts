function boolean() {
  case $1 in
  true) echo true ;;
  false) echo false ;;
  *)
    echo "Err: Unknown boolean value \"$1\"" 1>&2
    exit 1
    ;;
  esac
}

check_repo_and_pull() {
  local _folder=$1
  local _branch=$2
  # shellcheck disable=SC2155
  local _pwd=$(pwd)
  if [[ $(boolean "$VERSION_CONTROL_ENABLE_GIT_DISCOVERY") == false ]]; then
    return
  fi
  # shellcheck disable=SC2164
  cd "$_folder"
  # Check if docker-compose folder il a git repo
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    # Git repo case
    git checkout "$_branch"
    git pull --rebase
  fi
  # shellcheck disable=SC2164
  cd "$_pwd"
}
