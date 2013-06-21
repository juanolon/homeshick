# whether bash supports associative arrays
function supports_storage {
	declare -A a 2>/dev/null;
	if [[ $? == 0 ]]; then
		return 1
	else
		return 0
	fi
}

function load_secrets {
	secrets_file=${HOMESHICK_SECRETS_PATH :-"$HOME/.briefcase_secrets"}
	declare -A secrets

	while read line; do
		if [[ $line =~ ^([a-zA-Z0-9_-]+)=(.*)$ ]]; then
			secrets[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
		fi
	done < $secrets_file
}

function save_secrets {
	secrets_file=${HOMESHICK_SECRETS_PATH :-"$HOME/.briefcase_secrets"}
	for i in "${!secrets[@]}"; do
		echo "$i=${secrets[$i]}"
	done > $secrets_file
}

function set_secret {
	secrets[$1]=$2
}

function populate_placeholders {
	local redacted=$1
	local destination=$2

	if [[ supports_storage = 1 ]]; then
		while read line; do
			if [[ $line =~ ^(.*)\#\ briefcase\(([a-zA-Z0-9_-]+)\)(.*)$ ]]; then
				local start=${BASH_REMATCH[1]}
				local replacement=${secrets[${BASH_REMATCH[2]}]}
				local end=${BASH_REMATCH[3]}

				echo "$start$replacement$end"
			else
				echo "$line"
			fi
		done < $redacted > $destination
	else
		# replace all instances of briefcase in file
		sed -i 's/# briefcase([a-zA-Z0-9_-]\+)//g' $redacted > $destination
	fi
}

function parse_secrets {
	load_secrets

	exec 5< $1
	exec 6< $2
	
	while read line1 <&5 && read line2 <&6
	do
		if [[ $line2 =~ ^(.*)\#\ briefcase\(([a-zA-Z0-9_-]+)\)(.*)$ ]]; then
			local start=${BASH_REMATCH[1]}
			local name=${BASH_REMATCH[2]}
			local end=${BASH_REMATCH[3]}
			if [[ $line2 = $start*$end ]]; then
				local content=${line1#$start}
				content=${content%$end}
				set_secret "$name" "$content"
			fi
		fi
	done

	save_secrets
}