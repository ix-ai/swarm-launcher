#!/usr/bin/env bash

set -e

_term() {
  echo "Caught SIGTERM signal!"
  _cleanup
}

_cleanup(){
  echo "Cleaning up"
  docker-compose --project-name "${LAUNCH_PROJECT_NAME}" down --remove-orphans
}

COMPOSE_FILE="/docker-compose.yml"

CREATE_COMPOSE_FILE=true
if [ -f ${COMPOSE_FILE} ]; then
  echo "Detected mounted docker-compose.yml file. Starting directly."
  CREATE_COMPOSE_FILE=false
fi

# creates a docker-compose.yml file
if [ "${CREATE_COMPOSE_FILE}" == "true" ]; then
  # exits if there's no LAUNCH_IMAGE set
  if [ -z "${LAUNCH_IMAGE}" ]; then
    echo "LAUNCH_IMAGE is not set! Exiting!"
    exit 1
  fi

  if [ -z "${LAUNCH_PROJECT_NAME}" ]; then
    LAUNCH_PROJECT_NAME="swarm-launcher"
  fi

  # sets a default name for the service
  if [ -z "${LAUNCH_SERVICE_NAME}" ]; then
    LAUNCH_SERVICE_NAME="$(tr -cd '[:alnum:]' < /dev/urandom | fold -w6 | head -n1)"
  fi

  cat <<xEOF > ${COMPOSE_FILE}
version: "3.7"

services:
  ${LAUNCH_SERVICE_NAME}:
    image: "${LAUNCH_IMAGE}"
    restart: "no"
    labels:
xEOF

  # additional labels for the container
  if [ -n "${LAUNCH_LABELS}" ]; then
    for LABEL in ${LAUNCH_LABELS}; do
      echo "      - \"${LABEL}\"" >> ${COMPOSE_FILE}
    done
  else
    echo "    - \"ai.ix.started-by=ix.ai/swarm-launcher\"" >> ${COMPOSE_FILE}
  fi

  # name the container
  if [ -n "${LAUNCH_CONTAINER_NAME}" ]; then
    echo "    container_name: \"${LAUNCH_CONTAINER_NAME}\"" >> ${COMPOSE_FILE}
  fi

  # run in privileged mode
  if [ "${LAUNCH_PRIVILEGED}" = true ]; then
    echo "    privileged: \"true\"" >> ${COMPOSE_FILE}
  fi
  
  # specify an optional parent cgroup for the container
  if [ "${LAUNCH_CGROUP_PARENT}" = true ]; then
    echo "    cgroup_parent: ${LAUNCH_CGROUP_PARENT}" >> ${COMPOSE_FILE}
  fi

  # the environment variables
  if [ -n "${LAUNCH_ENVIRONMENTS}" ]; then
    echo "    environment:" >> ${COMPOSE_FILE}
    for ENVIRONMENT in ${LAUNCH_ENVIRONMENTS}; do
      echo "      - ${ENVIRONMENT}" >> ${COMPOSE_FILE}
    done
  fi

  # devices
  if [ -n "${LAUNCH_DEVICES}" ]; then
    echo "    devices:" >> ${COMPOSE_FILE}
    for DEVICE in ${LAUNCH_DEVICES}; do
      echo "      - ${DEVICE}" >> ${COMPOSE_FILE}
    done
  fi

  # the volumes
  if [ -n "${LAUNCH_VOLUMES}" ]; then
    echo "    volumes:" >> ${COMPOSE_FILE}
    for VOLUME in ${LAUNCH_VOLUMES}; do
      echo "      - ${VOLUME}" >> ${COMPOSE_FILE}
    done
  fi

  # Add capabilities
  if [ -n "${LAUNCH_CAP_ADD}" ]; then
    echo "    cap_add:" >> ${COMPOSE_FILE}
    for CAP in ${LAUNCH_CAP_ADD}; do
      echo "      - ${CAP}" >> ${COMPOSE_FILE}
    done
  fi

  # Drop capabilities
  if [ -n "${LAUNCH_CAP_DROP}" ]; then
    echo "    cap_drop:" >> ${COMPOSE_FILE}
    for CAP in ${LAUNCH_CAP_DOP}; do
      echo "      - ${CAP}" >> ${COMPOSE_FILE}
    done
  fi

  # sysctls
  if [ -n "${LAUNCH_SYSCTLS}" ]; then
    echo "    sysctls:" >> ${COMPOSE_FILE}
    for SYSCTL in ${LAUNCH_SYSCTLS}; do
      echo "      - ${SYSCTL}" >> ${COMPOSE_FILE}
    done
  fi

  # Override the command
  if [ -n "${LAUNCH_COMMAND}" ]; then
    echo "    command: \"${LAUNCH_COMMAND}\"" >> ${COMPOSE_FILE}
  fi

  # run on the host network - it's incompatible with ports or with named networks
  if [ "${LAUNCH_HOST_NETWORK}" = true ]; then
    echo "    network_mode: host" >> ${COMPOSE_FILE}
  else
    if [ -n "${LAUNCH_PORTS}" ]; then
      echo "    ports:" >> ${COMPOSE_FILE}
      for PORT in ${LAUNCH_PORTS}; do
        echo "      - \"$PORT\"" >> ${COMPOSE_FILE}
      done
    fi
    if [ -n "${LAUNCH_NETWORKS}" ] || [ -n "${LAUNCH_EXT_NETWORKS}" ]; then
      echo "    networks:" >> ${COMPOSE_FILE}
      for NETWORK in ${LAUNCH_NETWORKS}; do
        echo "      - ${NETWORK}" >> ${COMPOSE_FILE}
      done
      for NETWORK in ${LAUNCH_EXT_NETWORKS}; do
        echo "      - ${NETWORK}" >> ${COMPOSE_FILE}
      done
      echo "networks:" >> ${COMPOSE_FILE}
      for NETWORK in ${LAUNCH_NETWORKS}; do
        {
          echo "  ${NETWORK}:";
          echo "    driver: bridge";
          echo "    attachable: false";
        } >> ${COMPOSE_FILE}
      done
      for NETWORK in ${LAUNCH_EXT_NETWORKS}; do
        {
          echo "  ${NETWORK}:";
          echo "    external: true";
        } >> ${COMPOSE_FILE}
      done
    fi
  fi
fi

# does a docker login
if [ -n "${LOGIN_USER}" ] && [ -n "${LOGIN_PASSWORD}" ]; then
  echo "Logging in"
  echo "${LOGIN_PASSWORD}" | docker login -u "${LOGIN_USER}" --password-stdin "${LOGIN_REGISTRY}"
fi

# tests the config file
echo "Testing compose file"
docker-compose config

# pull latest image version
if [ "${LAUNCH_PULL}" = true ] && [ -n "${LAUNCH_IMAGE}" ] ; then
    echo "Pulling ${LAUNCH_IMAGE}"
    docker pull "${LAUNCH_IMAGE}"
fi

# Ensures that a stop of this container cleans up any stranded services
trap _term SIGTERM

docker-compose --project-name "${LAUNCH_PROJECT_NAME}" up \
               --force-recreate\
               --abort-on-container-exit\
               --remove-orphans\
               --no-color &
echo "------------------------------------------------------"
child=$!
wait "$child"
_cleanup
