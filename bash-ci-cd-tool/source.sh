DAEMON_NAME=$(jq .daemon.name config.json | sed -e "s|\"||g")
DAEMON_VERSION=$( jq .daemon.version config.json | sed -e "s|\"||g")
DAEMON_CHECK_RATE=$(jq .daemon.check_rate config.json | sed -e "s|\"||g")
DAEMON_ENABLE_GIT_DISCOVERY=$(jq .daemon.enable_git_discovery config.json | sed -e "s|\"||g")

PROJECTS=$(jq .projects config.json)

echo $DAEMON_NAME
echo $DAEMON_VERSION
echo $DAEMON_CHECK_RATE
echo $PROJECTS
echo $DAEMON_ENABLE_GIT_DISCOVERY