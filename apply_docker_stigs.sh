#!/bin/bash
set -e
# set -x

function display_help() {
  CMD='\033[0;31m'
  NC='\033[0m'
  echo "Usage IE:"
  echo "${0} --verbose"
  echo    ""
  echo    "Flag                                        Description"
  echo    "---------------------------------------------------------------------------------------------------------------"
  echo -e "| ${CMD}-h|--help${NC}                  | Display this help menu                                                      |"
  echo -e "| ${CMD}-v|--verbose${NC}               | Show output of STIG validation commands                                     |"
  echo    "---------------------------------------------------------------------------------------------------------------"
}

# Command line opts
ARGS=("$@")
for index in "${!ARGS[@]}"; do
  case ${ARGS[index]} in
    -v|--verbose)
      SHOW_ARTIFACT=true
      ;;
    -h|--help)
      display_help
      exit 1
      ;;
    -*|--*)
      echo "Unknown option ${ARGS[index]}"
      display_help
      cleanup_log
      exit 1
      ;;
  esac
done

ARCH=$(uname -m | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')
if [ "$ARCH" != "amd64" ] ; then
    echo "Unable to continue. Kasm hardening scripts support AMD64 only."
fi

command -v jq >/dev/null 2>&1 || { echo >&2 "The jq package is required, please install and restart the script.  Aborting."; exit 1; }
command -v auditctl >/dev/null 2>&1 || { echo >&2 "The audit package is required, please install and restart the script.  Aborting."; exit 1; }
command -v ausearch >/dev/null 2>&1 || { echo >&2 "The audit package is required, please install and restart the script.  Aborting."; exit 1; }

jqi() {
  cat <<< "$(jq "$1" < "$2")" > "$2"
}


CON_RED='\033[0;31m'
CON_GREEN='\033[0;32m'
CON_ORANGE='\033[0;33m'
CON_NC='\033[0m' # No Color

log_succes() {
    printf "$1, ${CON_GREEN}PASS${CON_NC}, $2\n"
}

log_failure() {
    printf "$1, ${CON_RED}FAIL${CON_NC}, $2\n"
}

log_na() {
	printf "$1, ${CON_ORANGE}N/A${CON_NC}, $2\n"
}

log_manual() {
	printf "$1, ${CON_ORANGE}MANUAL${CON_NC}, $2\n"
}

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

DOCKER_DAEMON_JSON_PATH=/etc/docker/daemon.json
DOCKER_SOCK_PATH=/run/containerd/containerd.sock
DOCKER_LEGACY_CONF=/etc/default/docker
DEFAULT_DOCKER_PATH=/var/lib/docker
ETC_DOCKER_PATH=/etc/docker/
DOCKER_SOCKET_PATH=/lib/systemd/system/docker.socket
DOCKER_SERVICE_PATH=/lib/systemd/system/docker.service
PRI_INTERFACE=$(ip route | grep -m 1 'default via' | grep -Po '(?<=dev )\S+')
PRI_IP=$(ip -f inet addr show "$PRI_INTERFACE" | grep -Po '(?<=inet )(\d{1,3}\.)+\d{1,3}')

read -p "Please verify that $PRI_IP is the IP address that docker should bind to (y/n)? " choice
    case "$choice" in
      y|Y )
        ;;
      n|N )
        echo "Cannot continue, manually set the PRI_INTERFACE and PRI_IP variables in the script as desired."
        exit 1
        ;;
      * )
        echo "Invalid Response"
        echo "Installation cannot continue"
        exit 1
        ;;
    esac

if [ ! -f "$DOCKER_DAEMON_JSON_PATH" ] ; then
	echo "$DOCKER_DAEMON_JSON_PATH does not exist, creating"
	echo "{}" > $DOCKER_DAEMON_JSON_PATH
else
    cp $DOCKER_DAEMON_JSON_PATH ${DOCKER_DAEMON_JSON_PATH}.bak
	echo "A backup of the docker daemon configuration has been placed at ${DOCKER_DAEMON_JSON_PATH}.bak"
fi

if [ ! -S "$DOCKER_SOCK_PATH" ] ; then
	echo "ERROR: Docker sock at $DOCKER_SOCK_PATH does not exist, exiting"
	exit 1
fi

chown root:root $DOCKER_DAEMON_JSON_PATH
log_succes "V-235867" "set daemon.json ownership to root:root"
if [ ! -z "$SHOW_ARTIFACT" ] ; then
   echo "Command: stat -c %U:%G $DOCKER_DAEMON_JSON_PATH"
   echo "Output: $(stat -c %U:%G $DOCKER_DAEMON_JSON_PATH)"
fi

chmod 0644 $DOCKER_DAEMON_JSON_PATH
log_succes "V-235868" "set daemon.json permissions to 644"
if [ -n "$SHOW_ARTIFACT" ] ; then
   echo "Command: stat -c %a $DOCKER_DAEMON_JSON_PATH"
   echo "Output: $(stat -c %a $DOCKER_DAEMON_JSON_PATH)"
fi

chmod 0660 $DOCKER_SOCK_PATH
log_succes "V-235866" "Set docker sock permission to 660"
if [ ! -z "$SHOW_ARTIFACT" ] ; then
   echo "Command: stat -c %a $DOCKER_SOCK_PATH"
   echo "Output: $(stat -c %a $DOCKER_SOCK_PATH)"
fi

chown root:docker $DOCKER_SOCK_PATH
log_succes "V-235865" "Set docker sock ownership to root:docker"
if [ ! -z "$SHOW_ARTIFACT" ] ; then
   echo "Command: stat -c %U:%G $DOCKER_SOCK_PATH"
   echo "Output: $(stat -c %U:%G $DOCKER_SOCK_PATH)"
fi

if [ ! -f "$DOCKER_LEGACY_CONF" ] ; then
  log_na 'V-235869' 'Legacy Docker configuration file not present.'
	log_na "V-235870" "Legacy Docker configuration file not present."
else
  chown root:root $DOCKER_LEGACY_CONF
	log_succes 'V-235869' 'Set ownership of legacy docker conf file to root:root.'
  if [ ! -z "$SHOW_ARTIFACT" ] ; then
     echo "Command: stat -c %U:%G $DOCKER_LEGACY_CONF"
     echo "Output: $(stat -c %U:%G $DOCKER_LEGACY_CONF)"
  fi
  chmod 0644 $DOCKER_LEGACY_CONF
  log_succes "V-235870" "Set $DEFAULT_DOCKER_PATH permissions to 644"
  if [ ! -z "$SHOW_ARTIFACT" ] ; then
     echo "Command: stat -c %a $DOCKER_LEGACY_CONF"
     echo "Output: $(stat -c %a $DOCKER_LEGACY_CONF)"
  fi
fi

chown root:root $ETC_DOCKER_PATH
log_succes "V-235855" "Set $ETC_DOCKER_PATH ownership to root:root"
if [ ! -z "$SHOW_ARTIFACT" ] ; then
   echo "Command: stat -c %U:%G $ETC_DOCKER_PATH"
   echo "Output: $(stat -c %U:%G $ETC_DOCKER_PATH)"
fi

chmod 755 $ETC_DOCKER_PATH
log_succes "V-235856" "Set $ETC_DOCKER_PATH permissions to 755"
if [ ! -z "$SHOW_ARTIFACT" ] ; then
   echo "Command: stat -c %a $ETC_DOCKER_PATH"
   echo "Output: $(stat -c %a $ETC_DOCKER_PATH)"
fi

chown root:root $DOCKER_SOCKET_PATH
log_succes "V-235853" "Set docker.socket file ownership to root:root"
if [ ! -z "$SHOW_ARTIFACT" ] ; then
   echo "Command: stat -c %U:%G $DOCKER_SOCKET_PATH"
   echo "Output: $(stat -c %U:%G $DOCKER_SOCKET_PATH)"
fi

chmod 0644 $DOCKER_SOCKET_PATH
log_succes "V-235854" "Set docker.socket file permissions to 644"
if [ ! -z "$SHOW_ARTIFACT" ] ; then
   echo "Command: stat -c %a $DOCKER_SOCKET_PATH"
   echo "Output: $(stat -c %a $DOCKER_SOCKET_PATH)"
fi

chown root:root $DOCKER_SERVICE_PATH
log_succes "V-235851" "Set docker.service file ownership to root:root"
if [ ! -z "$SHOW_ARTIFACT" ] ; then
   echo "Command:stat -c %U:%G $DOCKER_SERVICE_PATH"
   echo "Output: $(stat -c %U:%G $DOCKER_SERVICE_PATH)"
fi

chmod 0644 $DOCKER_SERVICE_PATH
log_succes "V-235852" "Set docker.service file permissions to 0644"
if [ ! -z "$SHOW_ARTIFACT" ] ; then
   echo "Command: stat -c %a $DOCKER_SERVICE_PATH"
   echo "Output: $(stat -c %a $DOCKER_SERVICE_PATH)"
fi

if docker ps --all | grep -iv "ucp\|kube\|dtr" | awk '{print $1}' | xargs docker inspect --format '{{ .Id }}: SecurityOpt={{ .HostConfig.SecurityOpt }}' 2>/dev/null | grep -i --quiet unconfined ; then
	log_failure "V-235812" "found container with seccomp unconfined."
else
	log_succes "V-235812" "no seccomp unconfined containers found"
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: docker ps --all | grep -iv "ucp\|kube\|dtr" | awk '{print $1}' | xargs docker inspect --format '{{ .Id }}: SecurityOpt={{ .HostConfig.SecurityOpt }}' "
  echo "Output: $(docker ps --all | grep -iv "ucp\|kube\|dtr" | awk '{print $1}' | xargs docker inspect --format '{{ .Id }}: SecurityOpt={{ .HostConfig.SecurityOpt }}')"
fi

if docker ps --quiet --all | xargs --no-run-if-empty -- docker inspect --format '{{ .Id }}: Ulimits={{ .HostConfig.Ulimits }}' 2>/dev/null | grep -v "no value" ; then
    log_failure "V-235844" "container overrides ulimit"
else
	log_succes "V-235844" "no containers override default ulimit"
fi

if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: Ulimits={{ .HostConfig.Ulimits }}' "
   echo "Output: $(docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: Ulimits={{ .HostConfig.Ulimits }}')"
fi

if [ $(sudo jq -r '."log-opts"."max-size"' /etc/docker/daemon.json) != 'null' ] && [ $(sudo jq -r '."log-opts"."max-file"' /etc/docker/daemon.json) != 'null' ] ; then
  log_succes "V-235786" "max-size and max-file are set."
else
  if  [ $(sudo jq -r '."log-opts"."max-size"' /etc/docker/daemon.json) == 'null' ] ; then
    if which jq ; then
        cat <<< $(sudo jq '."log-opts" |= . + {"max-size": "50m"}' /etc/docker/daemon.json) > /etc/docker/daemon.json
        log_succes "V-235786" "(1 of 2) max-size has been set by this script, be sure to restart the docker service."
    else
        log_failure "V-235786" "(1 of 2) max-size is not explicitly set, unable to fix, jq package not installed."
        echo "	TIP: add '\"max-size\": \"50m\"' to /etc/docker/daemon.json and restart the docker service"
    fi
  else
    log_succes "V-235786" "(1 of 2) max-size is set."
  fi
  if [ $(sudo jq -r '."log-opts"."max-file"' /etc/docker/daemon.json) == 'null' ] ; then
    if which jq ; then
        cat <<< $(sudo jq '."log-opts" |= . + {"max-file": 10}' /etc/docker/daemon.json) > /etc/docker/daemon.json
        log_succes "V-235786" "(2 of 2) max-file has been set by this script, be sure to restart the docker service."
    else
        log_failure "V-235786" "(2 of 2) max-file is not explicitly set, unable to fix, jq package not installed."
        echo "	TIP: add '\"max-file\": 10' to /etc/docker/daemon.json and restart the docker service"
    fi
  else 
  log_succes "V-235786" "(2 of 2) max-file is set."
  fi
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: grep -Pi '"max-file"\s*:\s*\d+' /etc/docker/daemon.json"
  echo "Output: $(grep -Pi '"max-file"\s*:\s*\d+' /etc/docker/daemon.json)" 
  echo "Command: grep -Pi '"max-size"\s*:\s*\d+' /etc/docker/daemon.json"
  echo "Output: $(grep -Pi '"max-size"\s*:\s*\d+' /etc/docker/daemon.json)" 
fi

# can be configured as docker daemon argument
if ps -ef | grep dockerd | grep --quiet 'insecure-registry'; then
  log_failure "V-235789" "insecure Registries are configured."
else
  log_succes "V-235789" "no insecure Registries configured."
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: ps -ef | grep dockerd "
  echo "Output: $(ps -ef | grep dockerd)"
fi

# can be configured in daemon.json
if grep --quiet 'insecure-registry' /etc/docker/daemon.json ; then
  log_failure "V-235789" "insecure Registries are configured."
else
  log_succes "V-235789" "no insecure Registries configured."
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: grep 'insecure-registry' /etc/docker/daemon.json"
  
  echo "Output $(grep 'insecure-registry' /etc/docker/daemon.json)" 
fi

if docker ps --all | grep -iv "ucp\|kube\|dtr" | awk '{print $1}' | xargs docker inspect --format '{{ .Id }}: PidMode={{ .HostConfig.PidMode }}' 2>/dev/null | grep -i pidmode=host ; then
  log_failure 'V-235784' 'containers present running with host PID namespace'
else
  log_succes 'V-235784' 'no containers running with host PID namespace detected'
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: docker ps --all | grep -iv "ucp\|kube\|dtr" | awk '{print $1}' | xargs docker inspect --format '{{ .Id }}: PidMode={{ .HostConfig.PidMode }}'"
  
   echo "Output: $(docker ps --all | grep -iv 'ucp\|kube\|dtr' | awk '{print $1}' | xargs docker inspect --format '{{ .Id }}: PidMode={{ .HostConfig.PidMode }}')" 
fi

if docker ps --all | grep -iv "ucp\|kube\|dtr" | awk '{print $1}' | xargs docker inspect --format '{{ .Id }}: IpcMode={{ .HostConfig.IpcMode }}' 2>/dev/null | grep -i ipcmode=host ; then
  log_failure 'V-235785' 'containers present running with host IPC namespace'
else
  log_succes 'V-235785' 'no containers running with host IPC namespace detected'
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: docker ps --all | grep -iv 'ucp\|kube\|dtr' | awk '{print $1}' | xargs docker inspect --format '{{ .Id }}: IpcMode={{ .HostConfig.IpcMode }}'"
  
   echo "Output: $(docker ps --all | grep -iv 'ucp\|kube\|dtr' | awk '{print $1}' | xargs docker inspect --format '{{ .Id }}: IpcMode={{ .HostConfig.IpcMode }}')" 
fi

# can be configured as docker daemon argument
if ps -ef | grep dockerd | grep --quiet 'userland-proxy'; then
  log_failure "V-235791" "Remove userland-proxy flag from docker service arguments, use /etc/docker/daemon.json."
else
  log_succes "V-235791" "userland-proxy flag not used as docker service arguments."
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: ps -ef | grep dockerd"
   echo "Output: $(ps -ef | grep dockerd)" 
fi
# can be configured in daemon.json
if grep --quiet -Pi '"userland-proxy"\s*:\s*false' /etc/docker/daemon.json ; then
  log_succes "V-235791" "userland-proxy is disabled."
else
  if which jq ; then
      cat <<< $(sudo jq '. |= . + {"userland-proxy": false}' /etc/docker/daemon.json) > /etc/docker/daemon.json
    log_succes "V-235791" "userland-proxy has been disabled by this script, be sure to restart the docker service."
  else
    log_failure "V-235791" "userland-proxy is not explicitly disabled, unable to fix, jq package not installed."
  echo "	TIP: add '\"userland-proxy\": false' to /etc/docker/daemon.json and restart the docker service"
  fi
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: grep -Pi '"userland-proxy"\s*:\s*false' /etc/docker/daemon.json"
  
   echo "Output: $(grep -Pi '"userland-proxy"\s*:\s*false' /etc/docker/daemon.json)" 
fi

if grep --quiet -Pi '"ip"\s*:\s*"[^0]' /etc/docker/daemon.json ; then
  log_succes "V-235820" "Docker is configured to listen on specific IP address."
else
  if which jq ; then
    if grep '"ip"' /etc/docker/daemon.json ; then
      log_failure 'V-235820' '/etc/docker/daemon.json configured with IP set to 0.0.0.0, manually fix and rerun'
    else
      cat <<< $(sudo jq ". |= . + {\"ip\": \"$PRI_IP\"}" /etc/docker/daemon.json) > /etc/docker/daemon.json
      log_succes "V-235820" "docker has been bound to $PRI_IP, be sure to restart the docker service."
    fi
  else
    log_failure "V-235820" "docker is not configured to bind to specific interface, unable to fix, jq package not installed."
    echo "	TIP: add '\"ip\": \"192.168.1.10\"' to /etc/docker/daemon.json, replace the IP address with the system's IP and restart the docker service"
  fi
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
   echo "Command: grep -Pi '\"ip\"\s*:\s*\"[^0]' /etc/docker/daemon.json"
   echo "Output: $(grep -Pi '"ip"\s*:\s*"[^0]' /etc/docker/daemon.json)"
fi

if docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: AppArmorProfile={{ .AppArmorProfile }}' | grep -i "AppArmorProfile=unconfined" ; then
  log_failure 'V-235799' 'containers present running without apparmor'
else
  log_succes 'V-235799' 'all containers running with apparmor profiles'
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: AppArmorProfile={{ .AppArmorProfile }}'"
  echo "Output: $(docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: AppArmorProfile={{ .AppArmorProfile }}')" 
fi

log_manual 'V-235837' 'review below ports and ensure they are in the SSP, look at the HostPort field.'
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: docker ps -q | xargs docker inspect --format '{{ .Id }}: {{ .Name }}: Ports={{ .NetworkSettings.Ports }}' | grep HostPort "
  echo "Output: $(docker ps -q | xargs docker inspect --format '{{ .Id }}: {{ .Name }}: Ports={{ .NetworkSettings.Ports }}' | grep HostPort) " 
else
  docker ps -q | xargs docker inspect --format '{{ .Id }}: {{ .Name }}: Ports={{ .NetworkSettings.Ports }}' | grep HostPort
fi

log_manual 'V-235804' 'review below ports and ensure they are in the SSP, look at the HostPort field.'
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: docker ps --quiet | xargs docker inspect --format '{{ .Id }}: Ports={{ .NetworkSettings.Ports }}' | grep -i host"
  echo "Output: $(docker ps --quiet | xargs docker inspect --format '{{ .Id }}: Ports={{ .NetworkSettings.Ports }}' | grep -i host) " 
else
  docker ps --quiet | xargs docker inspect --format '{{ .Id }}: Ports={{ .NetworkSettings.Ports }}' | grep -i host
fi


if which ausearch ; then
    if sudo ausearch -k docker | grep exec | grep --quiet privileged ; then
      log_failure 'V-235813' 'there is an exec session running with privileged flag'
    else
      log_succes 'V-235813' 'no exec sessions with privilged flag found'
    if [ ! -z "$SHOW_ARTIFACT" ] ; then
      echo "Command: sudo ausearch -k docker | grep exec | grep privileged "
      echo "Output: $(sudo ausearch -k docker | grep exec | grep privileged)" 
    fi
  fi
else
  log_failure 'V-235813' 'ausearch package not installed not able to assess. This implies auditd is not installed.'
fi

if docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: UsernsMode={{ .HostConfig.UsernsMode }}' | grep --quiet -i "UsernsMode=host" ; then
  log_failure 'V-235817' 'containers present sharing host user namespace'
else
  log_succes 'V-235817' 'no containers running sharing host user namespace detected'
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: UsernsMode={{ .HostConfig.UsernsMode }}'"
  echo "Output: $(docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: UsernsMode={{ .HostConfig.UsernsMode }}')" 
fi

LOW_HOST_PORT=$(docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: Ports={{ .NetworkSettings.Ports }}' | grep -Pio '(?<=HostPort:)\d+' | sort -n | head -n 1)
if [ "$LOW_HOST_PORT" -lt 1024 ] ; then 
  log_failure 'V-235819' 'host ports below 1024 are mapped into containers.'; 
else 
  log_succes 'V-235819' 'no host ports mapped below 1024'; 
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: Ports={{ .NetworkSettings.Ports }}' "
  echo "Output: $(docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: Ports={{ .NetworkSettings.Ports }}') " 
fi

if docker ps --all | grep -iv "ucp\|kube\|dtr" | awk '{print $1}' | xargs docker inspect --format '{{ .Id }}: NetworkMode={{ .HostConfig.NetworkMode }}' 2>/dev/null | grep --quiet -i "NetworkMode=host" ; then
  log_failure 'V-235805' 'containers present sharing hosts network namespace'
else
  log_succes 'V-235805' 'no containers running sharing hosts netork namespace'
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: docker ps --all | grep -iv "ucp\|kube\|dtr" | awk '{print $1}' | xargs docker inspect --format '{{ .Id }}: NetworkMode={{ .HostConfig.NetworkMode }}'"
  echo "Output: $(docker ps --all | grep -iv "ucp\|kube\|dtr" | awk '{print $1}' | xargs docker inspect --format '{{ .Id }}: NetworkMode={{ .HostConfig.NetworkMode }}') " 
fi


if docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: Devices={{ .HostConfig.Devices }}' | grep --quiet -i 'pathincontainer' ; then
  log_failure 'V-235809' 'containers present with host devices passed in.'
else
  log_succes 'V-235809' 'no containers running with host devices passed in.'
fi 
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: Devices={{ .HostConfig.Devices }}'"
  echo "Output: $(docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: Devices={{ .HostConfig.Devices }}')" 
fi


if docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: Volumes={{ .Mounts }}' | grep -iv "ucp\|kubelet\|dtr" | grep -Po 'Source:\S+' | grep -P '\:(/|/boot|/dev|/etc|/lib|/proc|/sys|/usr)$' ; then
  log_failure 'V-235783' 'sensitive directories mapped into containers detected.'
else
  log_succes 'V-235783' 'no sensitive directories found mappend into containers'
fi 
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: Volumes={{ .Mounts }}' | grep -iv 'ucp\|kubelet\|dtr'"
  echo "Output: $(docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: Volumes={{ .Mounts }}' | grep -iv 'ucp\|kubelet\|dtr')" 
fi

if docker info | grep --quiet -e "^Storage Driver:\s*aufs\s*$" ; then
  log_failure 'V-235790' 'aufs file system detected.'
else
  log_succes 'V-235790' 'aufs file system not detected'
fi 
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: docker info | grep -e '^Storage Driver:\s*aufs\s*$'"
  echo "Output: $(docker info | grep -e '^Storage Driver:\s*aufs\s*$')"  
fi

if docker ps --all | grep -iv "ucp\|kube\|dtr" | awk '{print $1}' | xargs docker inspect --format '{{ .Id }}: Propagation={{range $mnt := .Mounts}} {{json $mnt.Propagation}} {{end}}' 2>/dev/null | grep --quiet 'shared' ; then
  log_failure 'V-235810' 'mount progagation mode set to shared.'
else
  log_succes 'V-235810' 'no mounts set to shared propogation mode found'
fi 
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: docker ps --all | grep -iv 'ucp\|kube\|dtr' | awk '{print $1}' | xargs docker inspect --format '{{ .Id }}: Propagation={{range $mnt := .Mounts}} {{json $mnt.Propagation}} {{end}}'"
  echo "Output: $(docker ps --all | grep -iv 'ucp\|kube\|dtr' | awk '{print $1}' | xargs docker inspect --format '{{ .Id }}: Propagation={{range $mnt := .Mounts}} {{json $mnt.Propagation}} {{end}}')" 
fi

if docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: UTSMode={{ .HostConfig.UTSMode }}' | grep -i '=host' ; then
  log_failure 'V-235811' 'host UTS namespace shared to container.'
else
  log_succes 'V-235811' 'no containers found with host UTC namespace shared'
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: UTSMode={{ .HostConfig.UTSMode }}'"
  echo "Output: $(docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: UTSMode={{ .HostConfig.UTSMode }}')" 
fi

if ps aux | grep 'docker exec' | grep '\-\-user' ; then
  log_failure 'V-235814' 'there is an exec session running with user flag'
else
  log_succes 'V-235814' 'no exec sessions with user flag found'
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: sudo ausearch -k docker | grep exec | grep user"
  echo "Output: $(sudo ausearch -k docker | grep exec | grep user)" 
fi

if docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: CgroupParent={{ .HostConfig.CgroupParent }}' | grep -P '=\w+' ; then
  log_failure 'V-235815' 'cgroup usage detected, must be manually checked.'
else
  log_succes 'V-235815' 'only default cgroups defined on running containers'
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: CgroupParent={{ .HostConfig.CgroupParent }}'"
  
  echo "Output: $(docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: CgroupParent={{ .HostConfig.CgroupParent }}')" 
fi

if docker ps --quiet --all | grep -iv "ucp\|kube\|dtr" | awk '{print $1}' | xargs docker inspect --format '{{ .Id }}: Privileged={{ .HostConfig.Privileged }}' | grep true ; then
  log_failure 'V-235802' 'containers running as privileged.'
else
  log_succes 'V-235802' 'no containers found running as privileged'
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: docker ps --quiet --all | grep -iv 'ucp\|kube\|dtr' | awk '{print $1}' | xargs docker inspect --format '{{ .Id }}: Privileged={{ .HostConfig.Privileged }}'"
  echo "Output: $(docker ps --quiet --all | grep -iv 'ucp\|kube\|dtr' | awk '{print $1}' | xargs docker inspect --format '{{ .Id }}: Privileged={{ .HostConfig.Privileged }}')" 
fi

if which auditctl ; then
  if !(systemctl show -p FragmentPath docker.service or auditctl -l | grep docker.service) then
    log_failure 'V-235779' 'docker.service auditd rule missing'
  fi
  if !(systemctl show -p FragmentPath docker.socket or auditctl -l | grep docker.sock) then
    log_failure 'V-235779' 'docker.docket auditd rule missing'
  fi
  log_succes 'V-235779' 'Required auditd rules for docker are present'
  if [ ! -z "$SHOW_ARTIFACT" ] ; then
    echo "Command: systemctl show -p FragmentPath docker.service or auditctl -l | grep docker.service"
     echo "Output: $(systemctl show -p FragmentPath docker.service or auditctl -l | grep docker.service)"
    echo "Command: systemctl show -p FragmentPath docker.socket or auditctl -l | grep docker.sock "
     echo "Output: $(systemctl show -p FragmentPath docker.socket or auditctl -l | grep docker.sock )"
  fi
else
  log_failure 'V-235779' 'auditd does not appear to be installed, which will result in many STIG findings'
fi

if docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: CapAdd={{ .HostConfig.CapAdd }} CapDrop={{ .HostConfig.CapDrop }}' | grep -v ': CapAdd=<no value> CapDrop=<no value>$' ; then
  log_failure 'V-235801' 'containers running with added capabilities, you will need to manually confirm with SSP.'
else
  log_succes 'V-235801' 'no containers found with additional capabilities passed in.'
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: CapAdd={{ .HostConfig.CapAdd }} CapDrop={{ .HostConfig.CapDrop }}'"
  echo "Output: $(docker ps --quiet --all | xargs docker inspect --format '{{ .Id }}: CapAdd={{ .HostConfig.CapAdd }} CapDrop={{ .HostConfig.CapDrop }}')" 
fi

PASS=1
for i in $(docker ps -qa); do 
  if docker exec $i ps -el | grep -i sshd ; then
    log_failure 'V-235803' 'containers running sshd found.'
    if [ ! -z "$SHOW_ARTIFACT" ] ; then
    echo "Command: docker exec $i ps -el | grep -i sshd"
    echo "Output: $(docker exec $i ps -el | grep -i sshd)" 
    fi  
    PASS=0
  fi
done
if [ $PASS -eq 1 ] ; then
  log_succes 'V-235803' 'no containers running sshd found.'  
fi

if docker version --format '{{ .Server.Experimental }}' | grep --quiet false; then
  log_succes "V-235792" "Experimental features are disabled"
else
  log_failure "V-235792" "Experimental features are enabled"
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: docker version --format '{{ .Server.Experimental }}' | grep false"
  echo "Output: $(docker version --format '{{ .Server.Experimental }}' | grep false)" 
fi

if jq -e '."log-driver" == "syslog"' /etc/docker/daemon.json | grep --quiet true; then
  log_succes "V-235831" "log driver is enabled"
else
  jqi '. + {"log-driver": "syslog"}' /etc/docker/daemon.json
  log_succes "V-235831" "log driver has been configured in script"
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: cat $DOCKER_DAEMON_JSON_PATH | grep -i log-driver"
  echo "Output: $(cat $DOCKER_DAEMON_JSON_PATH | grep -i log-driver)" 
fi

if [ $(sudo jq -r '."log-opts"."max-size"' /etc/docker/daemon.json) != 'null' ] && [ $(sudo jq -r '."log-opts"."max-file"' /etc/docker/daemon.json) != 'null' ] ; then
  log_succes "V-235832" "max-size and max-file are set."
else
  if  [ $(sudo jq -r '."log-opts"."max-size"' /etc/docker/daemon.json) == 'null' ] ; then
    if which jq ; then
        cat <<< $(sudo jq '."log-opts" |= . + {"max-size": 100}' /etc/docker/daemon.json) > /etc/docker/daemon.json
        log_succes "V-235832" "(1 of 2) max-size has been set by this script, be sure to restart the docker service."
    else
        log_failure "V-235832" "(1 of 2) max-size is not explicitly set, unable to fix, jq package not installed."
        echo "	TIP: add '\"max-size\": 100' to /etc/docker/daemon.json and restart the docker service"
    fi
  else
    log_succes "V-235832" "(1 of 2) max-size is set."
  fi
  if [ $(sudo jq -r '."log-opts"."max-file"' /etc/docker/daemon.json) == 'null' ] ; then
    if which jq ; then
        cat <<< $(sudo jq '."log-opts" |= . + {"max-file": 100}' /etc/docker/daemon.json) > /etc/docker/daemon.json
        log_succes "V-235832" "(2 of 2) max-file has been set by this script, be sure to restart the docker service."
    else
        log_failure "V-235832" "(2 of 2) max-file is not explicitly set, unable to fix, jq package not installed."
        echo "	TIP: add '\"max-file\": 100' to /etc/docker/daemon.json and restart the docker service"
    fi
  else 
  log_succes "V-235832" "(2 of 2) max-file is set."
  fi
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: grep -Pi '"max-file"\s*:\s*\d+' /etc/docker/daemon.json"
  echo "Output: $(grep -Pi '"max-file"\s*:\s*\d+' /etc/docker/daemon.json)" 
  echo "Command: grep -Pi '"max-size"\s*:\s*\d+' /etc/docker/daemon.json"
  echo "Output: $(grep -Pi '"max-size"\s*:\s*\d+' /etc/docker/daemon.json)" 
fi


if ! (grep --quiet "syslog-address" /etc/docker/daemon.json) ; then
  jqi '. + {"log-opts": {"syslog-address": "udp://127.0.0.1:25224", "tag": "container_name/{{.Name}}", "syslog-facility": "daemon" }}' /etc/docker/daemon.json
  log_succes "V-235833" "Script configured docker daemon remote syslog settings"
else
    log_succes "V-235833" "Remote syslog already configured"
fi
if [ ! -z "$SHOW_ARTIFACT" ] ; then
  echo "Command: cat $DOCKER_DAEMON_JSON_PATH | grep -i log-driver"
  echo "Output: $(cat $DOCKER_DAEMON_JSON_PATH | grep -i log-driver)" 
fi
