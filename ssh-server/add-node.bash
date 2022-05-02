#!/usr/bin/env bash
graceful_exit(){
  exit 0
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
json_node() {
    cat <<-_EOF_
		{
			"uuid":"%uuid%",
			"name":"%name%",
			"ip_address":"%ip_address%",
			"user":"%user%",
			"port":"%port%",
			"ssh_key":"%ssh_key%"
		}

_EOF_
}

out=$(json_node)
echo -e "$out"

printf "Type name "
read -r _name
printf "Type ip address or symbolic name "
read -r _address
printf "Type user "
read -r _user
printf "Type port "
read -r _port
printf "Type ssh key path "
read -r _path

out=$(echo -e "$out" | sed -e "s|%uuid%|$(uuidgen)| g" \
-e "s|%name%|$_name|g" \
-e "s|%ip_address%|$_address|g" \
-e "s|%user%|$_user|g" \
-e "s|%port%|$_port|g" \
-e "s|%ssh_key%|$_path|g")

echo -e "$out" | jq .
ask_user_permission "Is it correct?"

# shellcheck disable=SC2094
# shellcheck disable=SC2002
cat config.json | jq ".servers[.servers|length] +=  $out" > config.json
