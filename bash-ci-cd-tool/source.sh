DAEMON_NAME=$(jq .daemon.name config.json | sed -e "s|\"||g")
DAEMON_VERSION=$( jq .daemon.version config.json | sed -e "s|\"||g")
DAEMON_CHECK_RATE=$(jq .daemon.check_rate config.json | sed -e "s|\"||g")
VERSION_CONTROL_ENABLE_GIT_DISCOVERY=$(jq version_control.enable_git_discovery config.json | sed -e "s|\"||g")
VERSION_CONTROL_DEFAULT_BRANCH=$(jq .version_control.default_branch config.json | sed -e "s|\"||g")

PROJECTS=$(jq .projects config.json)

echo $DAEMON_NAME
echo $DAEMON_VERSION
echo $DAEMON_CHECK_RATE
echo $PROJECTS
echo $VERSION_CONTROL_ENABLE_GIT_DISCOVERY
echo $VERSION_CONTROL_DEFAULT_BRANCH