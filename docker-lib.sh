# Ref: https://github.com/concourse/docker-image-resource/blob/master/assets/common.sh

#takes the following positional arguments
# max-concurrent-downlaods max-concurrent-uploads registries registry-mirrors
start_docker() {
  mkdir -p /var/log
  mkdir -p /var/run

  # check for /proc/sys being mounted readonly, as systemd does
  if grep '/proc/sys\s\+\w\+\s\+ro,' /proc/mounts >/dev/null; then
    mount -o remount,rw /proc/sys
  fi

  local mtu=$(cat /sys/class/net/$(ip route get 8.8.8.8|awk '{ print $5 }')/mtu)
  local server_args="--mtu ${mtu}"
  local registry=""
  
  server_args="${server_args} --max-concurrent-downloads=${1-3} --max-concurrent-uploads=${2-3}"

  for registry in $1; do
    server_args="${server_args} --insecure-registry ${registry}"
  done

  if [ -n "$4" ]; then
    server_args="${server_args} --registry-mirror=$4"
  fi

  #dind will conditionally mount a tmpfs at /tmp which seems like a good idea but hides the build artifacts from concourse, 
  #docker logs and docker pid we are trying to capture.  So we just umount it again (saves having to fork the DIND script to remove)
  #that behaviour in the first place.

  dind umount /tmp && dockerd --data-root /scratch/docker --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2375 ${server_args} >/tmp/docker.log 2>&1 &

  echo $! > /tmp/docker.pid

  trap stop_docker EXIT

  sleep 1

  until docker info >/dev/null 2>&1; do
    echo waiting for docker to come up...
    sleep 1
  done
}

stop_docker() {
  local pid=$(cat /tmp/docker.pid)
  if [ -z "$pid" ]; then
    return 0
  fi

  kill -TERM $pid
  wait $pid
}
