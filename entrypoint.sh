#!/usr/bin/env bash

set -e

if [ "${DEBUG}" == 'true' ]; then
  set -x
fi

_term() {
  _echo "Caught SIGTERM signal!"
  _cleanup
}

_cleanup() {
  _echo "Cleaning up"
  docker compose --project-name "${LAUNCH_PROJECT_NAME}" down --remove-orphans
  exit $?
}

_startup_check() {
  _echo "Doing startup check"

  # Check that no conflicting options are passed and display warning
  if [ "${LAUNCH_HOST_NETWORK}" == true ] || [ -n "${LAUNCH_NETWORK_MODE}" ]; then
    if [ "${LAUNCH_HOST_NETWORK}" == true ] && [ -n "${LAUNCH_NETWORK_MODE}" ]; then
      _echo "WARNING! LAUNCH_HOST_NETWORK is set. Ignoring LAUNCH_NETWORK_MODE"
    fi
    if [ -n "${LAUNCH_PORTS}" ]; then
      _echo "WARNING! LAUNCH_HOST_NETWORK or LAUNCH_NETWORK_MODE is set. Ignoring LAUNCH_PORTS"
    fi
    if [ -n "${LAUNCH_NETWORKS}" ]; then
      _echo "WARNING! LAUNCH_HOST_NETWORK or LAUNCH_NETWORK_MODE is set. Ignoring LAUNCH_NETWORKS"
    fi
    if [ -n "${LAUNCH_EXT_NETWORKS}" ]; then
      _echo "WARNING! LAUNCH_HOST_NETWORK or LAUNCH_NETWORK_MODE is set. Ignoring LAUNCH_EXT_NETWORKS"
    fi
  else
    # Check if the networks are attachable
    if [ -n "${LAUNCH_EXT_NETWORKS}" ]; then
      for NETWORK in ${LAUNCH_EXT_NETWORKS}; do
        ATTACHABLE=$(docker network inspect "${NETWORK}" | jq -r ".[].Attachable")
        if [ -z "${ATTACHABLE}" ]; then
          _echo "ERROR! Network ${NETWORK} does not exist. Exiting."
          NEED_EXIT=true
        fi
        if [ "${ATTACHABLE}" == 'false' ]; then
          _echo "ERROR! Network '${NETWORK}' is not attachable. Exiting."
          NEED_EXIT=true
        fi
      done
    fi
  fi

  if [ -n "${LAUNCH_ARG_ENVFILE}" ]; then
    if [ ! -f "${LAUNCH_ARG_ENVFILE}" ]; then
      _echo "ERROR! LAUNCH_ARG_ENVFILE is set but ${LAUNCH_ARG_ENVFILE} cannot be found. Exiting."
    fi
  fi

  # Check if there's a need to exit now
  if [ "${NEED_EXIT}" == true ]; then
    exit 1
  fi
}

_echo() {
  echo "swarm-launcher: $*"
}

COMPOSE_FILE="/docker-compose.yml"

CREATE_COMPOSE_FILE=true
if [ -f "${COMPOSE_FILE}" ]; then
  _echo "Detected mounted docker-compose.yml file"

  LAUNCH_VARIABLES=(
    'LAUNCH_IMAGE'
    'LAUNCH_PROJECT_NAME'
    'LAUNCH_SERVICE_NAME'
    'LAUNCH_CONTAINER_NAME'
    'LAUNCH_PRIVILEGED'
    'LAUNCH_HOSTNAME'
    'LAUNCH_ENVIRONMENTS'
    'LAUNCH_ENVFILES'
    'LAUNCH_DEVICES'
    'LAUNCH_VOLUMES'
    'LAUNCH_HOST_NETWORK'
    'LAUNCH_PORTS'
    'LAUNCH_NETWORKS'
    'LAUNCH_NETWORK_MODE'
    'LAUNCH_EXT_NETWORKS'
    'LAUNCH_EXT_NETWORKS_IPV4'
    'LAUNCH_EXT_NETWORKS_IPV6'
    'LAUNCH_EXT_NETWORKS_MIXED'
    'LAUNCH_CAP_ADD'
    'LAUNCH_CAP_DROP'
    'LAUNCH_SECURITY_OPT'
    'LAUNCH_LABELS'
    'LAUNCH_PULL'
    'LAUNCH_SYSCTLS'
    'LAUNCH_COMMAND'
    'LAUNCH_CGROUP_PARENT'
    'LAUNCH_STOP_GRACE_PERIOD'
    'LAUNCH_PID_MODE'
    'LAUNCH_ULIMITS'
    'LAUNCH_EXTRA_HOSTS'
    'LAUNCH_DNS'
    'LAUNCH_DNS_SEARCH'
  )
  for LAUNCH_VARIABLE in "${LAUNCH_VARIABLES[@]}"; do
    if [ -n "${!LAUNCH_VARIABLE}" ]; then
      _echo "WARNING: ${LAUNCH_VARIABLE} is set, but a docker-compose.yml file has been provided. ${LAUNCH_VARIABLE} will be ignored!"
    fi
  done
  CREATE_COMPOSE_FILE=false
fi

# creates a docker-compose.yml file
if [ "${CREATE_COMPOSE_FILE}" == "true" ]; then
  _startup_check
  # exits if there's no LAUNCH_IMAGE set
  if [ -z "${LAUNCH_IMAGE}" ]; then
    _echo "LAUNCH_IMAGE is not set! Exiting!"
    exit 1
  fi

  if [ -z "${LAUNCH_PROJECT_NAME}" ]; then
    LAUNCH_PROJECT_NAME="sl-$(tr -cd '[:alnum:]' </dev/urandom | fold -w6 | head -n1)"
  fi

  # sets a default name for the service
  if [ -z "${LAUNCH_SERVICE_NAME}" ]; then
    LAUNCH_SERVICE_NAME="$(tr -cd '[:alnum:]' </dev/urandom | fold -w6 | head -n1)"
  fi

  cat <<xEOF >"${COMPOSE_FILE}"
version: "3.8"

services:
  "${LAUNCH_SERVICE_NAME}":
    image: "${LAUNCH_IMAGE}"
    restart: "no"
    labels:
      - "ai.ix.started-by=ix.ai/swarm-launcher"
xEOF

  # additional labels for the container
  if [ -n "${LAUNCH_LABELS}" ]; then
    for LABEL in ${LAUNCH_LABELS}; do
      echo "      - \"${LABEL}\"" >>"${COMPOSE_FILE}"
    done
  fi

  # name the container
  if [ -n "${LAUNCH_CONTAINER_NAME}" ]; then
    echo "    container_name: \"${LAUNCH_CONTAINER_NAME}\"" >>"${COMPOSE_FILE}"
  fi

  # set container hostname
  if [ -n "${LAUNCH_HOSTNAME}" ]; then
    echo "    hostname: \"${LAUNCH_HOSTNAME}\"" >>"${COMPOSE_FILE}"
  fi

  # run in privileged mode
  if [ "${LAUNCH_PRIVILEGED}" = true ]; then
    echo "    privileged: true" >>"${COMPOSE_FILE}"
  fi

  # specify an optional parent cgroup for the container
  if [ "${LAUNCH_CGROUP_PARENT}" = true ]; then
    echo "    cgroup_parent: ${LAUNCH_CGROUP_PARENT}" >>"${COMPOSE_FILE}"
  fi

  # the environment variables
  if [ -n "${LAUNCH_ENVIRONMENTS}" ]; then
    echo "    environment:" >>"${COMPOSE_FILE}"
    read -ra ARR <<<"${LAUNCH_ENVIRONMENTS}"
    for ENVIRONMENT in "${ARR[@]}"; do
      echo "      - ${ENVIRONMENT//@_@/' '}" >>"${COMPOSE_FILE}"
    done
  fi

  # the environment files
  if [ -n "${LAUNCH_ENVFILES}" ]; then
    echo "    env_file:" >>"${COMPOSE_FILE}"
    read -ra ARR <<<"${LAUNCH_ENVFILES}"
    for ENVFILE in "${ARR[@]}"; do
      echo "      - ${ENVFILE}" >>"${COMPOSE_FILE}"
    done
  fi

  # devices
  if [ -n "${LAUNCH_DEVICES}" ]; then
    echo "    devices:" >>"${COMPOSE_FILE}"
    for DEVICE in ${LAUNCH_DEVICES}; do
      echo "      - ${DEVICE}" >>"${COMPOSE_FILE}"
    done
  fi

  # the volumes
  if [ -n "${LAUNCH_VOLUMES}" ]; then
    echo "    volumes:" >>"${COMPOSE_FILE}"
    for VOLUME in ${LAUNCH_VOLUMES}; do
      echo "      - ${VOLUME}" >>"${COMPOSE_FILE}"
    done
  fi

  # Add capabilities
  if [ -n "${LAUNCH_CAP_ADD}" ]; then
    echo "    cap_add:" >>"${COMPOSE_FILE}"
    for CAP in ${LAUNCH_CAP_ADD}; do
      echo "      - ${CAP}" >>"${COMPOSE_FILE}"
    done
  fi

  # Drop capabilities
  if [ -n "${LAUNCH_CAP_DROP}" ]; then
    echo "    cap_drop:" >>"${COMPOSE_FILE}"
    for CAP in ${LAUNCH_CAP_DROP}; do
      echo "      - ${CAP}" >>"${COMPOSE_FILE}"
    done
  fi

  # Security opt
  if [ -n "${LAUNCH_SECURITY_OPT}" ]; then
    echo "    security_opt:" >>"${COMPOSE_FILE}"
    for SECURITY_OPT in ${LAUNCH_SECURITY_OPT}; do
      echo "      - ${SECURITY_OPT}" >>"${COMPOSE_FILE}"
    done
  fi

  # sysctls
  if [ -n "${LAUNCH_SYSCTLS}" ]; then
    echo "    sysctls:" >>"${COMPOSE_FILE}"
    for SYSCTL in ${LAUNCH_SYSCTLS}; do
      echo "      - ${SYSCTL}" >>"${COMPOSE_FILE}"
    done
  fi

  # Override the command
  if [ -n "${LAUNCH_COMMAND}" ]; then
    echo "    command: \"${LAUNCH_COMMAND}\"" >>"${COMPOSE_FILE}"
  fi

  # stop grace period
  if [ -n "${LAUNCH_STOP_GRACE_PERIOD}" ]; then
    echo "    stop_grace_period: ${LAUNCH_STOP_GRACE_PERIOD}" >>"${COMPOSE_FILE}"
  fi

  # stop grace period
  if [ "${LAUNCH_PID_MODE:-}x" = "hostx" ]; then
    echo "    pid: host" >>"${COMPOSE_FILE}"
  fi

  # ulimits
  if [ -n "${LAUNCH_ULIMITS}" ]; then
    echo "    ulimits:" >>"${COMPOSE_FILE}"
    read -ra ARR <<<"${LAUNCH_ULIMITS}"
    for ULIMIT in "${ARR[@]}"; do
      IFS='=' read -r ULIMIT_KEY ULIMIT_VALUE <<<"${ULIMIT}"
      echo "      ${ULIMIT_KEY}: ${ULIMIT_VALUE}" >>"${COMPOSE_FILE}"
    done
  fi

  # extra_hosts
  if [ -n "${LAUNCH_EXTRA_HOSTS}" ]; then
    echo "    extra_hosts:" >>"${COMPOSE_FILE}"
    for EXTRA_HOST in ${LAUNCH_EXTRA_HOSTS}; do
      echo "      - \"${EXTRA_HOST}\"" >>"${COMPOSE_FILE}"
    done
  fi

  # Custom DNS
  if [ -n "${LAUNCH_DNS}" ]; then
    echo "    dns:" >>"${COMPOSE_FILE}"
    for DNS in ${LAUNCH_DNS}; do
      echo "      - \"${DNS}\"" >>"${COMPOSE_FILE}"
    done
  fi

  # Custom DNS Search domains
  if [ -n "${LAUNCH_DNS_SEARCH}" ]; then
    echo "    dns_search:" >>"${COMPOSE_FILE}"
    for DOMAIN in ${LAUNCH_DNS_SEARCH}; do
      echo "      - ${DOMAIN}" >>"${COMPOSE_FILE}"
    done
  fi

  # Specific Mac Address for the container
  if [ -n "${LAUNCH_MAC_ADDRESS}" ]; then
    echo "    mac_address: ${LAUNCH_MAC_ADDRESS}" >>"${COMPOSE_FILE}"
  fi

  # run on the host network - it's incompatible with ports or with named networks
  if [ "${LAUNCH_HOST_NETWORK}" = true ]; then
    echo "    network_mode: host" >>"${COMPOSE_FILE}"
  elif [ -n "${LAUNCH_NETWORK_MODE}" ]; then
    echo "    network_mode: ${LAUNCH_NETWORK_MODE}" >>"${COMPOSE_FILE}"
  else
    if [ -n "${LAUNCH_PORTS}" ]; then
      echo "    ports:" >>"${COMPOSE_FILE}"
      for PORT in ${LAUNCH_PORTS}; do
        echo "      - \"$PORT\"" >>"${COMPOSE_FILE}"
      done
    fi

    ##
    # The four major network variables:
    # LAUNCH_NETWORKS
    # LAUNCH_EXT_NETWORKS
    # LAUNCH_EXT_NETWORKS_IPV4
    # LAUNCH_EXT_NETWORKS_IPV6
    # LAUNCH_EXT_NETWORKS_MIXED
    #
    # Keep them separated for better readability and easier treoubleshooting, at the cost of code duplication
    ##
    if
      [ -n "${LAUNCH_NETWORKS}" ] ||
        [ -n "${LAUNCH_EXT_NETWORKS}" ] ||
        [ -n "${LAUNCH_EXT_NETWORKS_IPV4}" ] ||
        [ -n "${LAUNCH_EXT_NETWORKS_IPV6}" ] ||
        [ -n "${LAUNCH_EXT_NETWORKS_MIXED}" ] \
        ;
    then
      # LAUNCH_NETWORKS are networks that get created on the fly, at start
      echo "    networks:" >>"${COMPOSE_FILE}"
      for NETWORK in ${LAUNCH_NETWORKS}; do
        echo "      ${NETWORK}:" >>"${COMPOSE_FILE}"
      done
      # LAUNCH_EXT_NETWORKS are existing attachable networks
      for NETWORK in ${LAUNCH_EXT_NETWORKS}; do
        echo "      ${NETWORK}:" >>"${COMPOSE_FILE}"
      done
      # LAUNCH_EXT_NETWORKS_IPV4 are existing attachable networks, where the IP is manually assigned
      # The format is `network1:ip1 network2:ip2 ... networkN:ipN`
      if [ -n "${LAUNCH_EXT_NETWORKS_IPV4}" ]; then
        read -ra ARR <<<"${LAUNCH_EXT_NETWORKS_IPV4}"
        for NETWORK in "${ARR[@]}"; do
          IFS=':' read -r NETWORK IPV4 <<<"${NETWORK}"
          {
            echo "      ${NETWORK}:"
            echo "        ipv4_address: '${IPV4}'"
          } >>"${COMPOSE_FILE}"
        done
      fi
      # LAUNCH_EXT_NETWORKS_IPV6 are existing attachable networks, where the IP is manually assigned
      # The format is `network1-ip1 network2-ip2 ... networkN-ipN`
      if [ -n "${LAUNCH_EXT_NETWORKS_IPV6}" ]; then
        read -ra ARR <<<"${LAUNCH_EXT_NETWORKS_IPV6}"
        for NETWORK in "${ARR[@]}"; do
          IFS='-' read -r NETWORK IPV6 <<<"${NETWORK}"
          {
            echo "      ${NETWORK}:"
            echo "        ipv6_address: '${IPV6}'"
          } >>"${COMPOSE_FILE}"
        done
      fi
      # LAUNCH_EXT_NETWORKS_MIXED are existing attachable networks, where the IPV4 and IPV6 is manually assigned
      # The format is `network1-ipv4-ipv6 network2-ipv4-ipv6 ... networkN-ipv4-ipv6`
      if [ -n "${LAUNCH_EXT_NETWORKS_MIXED}" ]; then
        read -ra ARR <<<"${LAUNCH_EXT_NETWORKS_MIXED}"
        for NETWORK in "${ARR[@]}"; do
          IFS='-' read -r NETWORK IPV4 IPV6 <<<"${NETWORK}"
          {
            echo "      ${NETWORK}:"
            echo "        ipv4_address: '${IPV4}'"
            echo "        ipv6_address: '${IPV6}'"
          } >>"${COMPOSE_FILE}"
        done
      fi
      # Here starts the `networks` section
      echo "networks:" >>"${COMPOSE_FILE}"
      for NETWORK in ${LAUNCH_NETWORKS}; do
        {
          echo "  ${NETWORK}:"
          echo "    driver: bridge"
          echo "    attachable: true"
        } >>"${COMPOSE_FILE}"
      done
      for NETWORK in ${LAUNCH_EXT_NETWORKS}; do
        {
          echo "  ${NETWORK}:"
          echo "    external: true"
        } >>"${COMPOSE_FILE}"
      done
      if [ -n "${LAUNCH_EXT_NETWORKS_IPV4}" ]; then
        read -ra ARR <<<"${LAUNCH_EXT_NETWORKS_IPV4}"
        for NETWORK in "${ARR[@]}"; do
          IFS=':' read -r NETWORK IPV4 <<<"${NETWORK}"
          {
            echo "  ${NETWORK}:"
            echo "    external: true"
          } >>"${COMPOSE_FILE}"
        done
      fi
      if [ -n "${LAUNCH_EXT_NETWORKS_IPV6}" ]; then
        read -ra ARR <<<"${LAUNCH_EXT_NETWORKS_IPV6}"
        for NETWORK in "${ARR[@]}"; do
          IFS='-' read -r NETWORK IPV6 <<<"${NETWORK}"
          {
            echo "  ${NETWORK}:"
            echo "    external: true"
          } >>"${COMPOSE_FILE}"
        done
      fi
      if [ -n "${LAUNCH_EXT_NETWORKS_MIXED}" ]; then
        read -ra ARR <<<"${LAUNCH_EXT_NETWORKS_MIXED}"
        for NETWORK in "${ARR[@]}"; do
          IFS='-' read -r NETWORK IPV4 IPV6 <<<"${NETWORK}"
          {
            echo "  ${NETWORK}:"
            echo "    external: true"
          } >>"${COMPOSE_FILE}"
        done
      fi
    fi
  fi
fi

# does a docker login
if [[ -n "${LOGIN_USER}" && (-f "${LOGIN_PASSWORD_FILE}" || -n "${LOGIN_PASSWORD}") ]]; then
  if [ -f "${LOGIN_PASSWORD_FILE}" ]; then
    LOGIN_PASSWORD=$(cat "${LOGIN_PASSWORD_FILE}")
  fi
  _echo "Logging in"
  echo "${LOGIN_PASSWORD}" | docker login -u "${LOGIN_USER}" --password-stdin "${LOGIN_REGISTRY}"
fi

# tests the config file
_echo "Testing compose file:"
_echo "-----------------------------------"
cat "${COMPOSE_FILE}"
_echo "-----------------------------------"

COMMAND=(
  --project-name "${LAUNCH_PROJECT_NAME}"
  config
)

[[ -n "${LAUNCH_ARG_ENVFILE}" ]] && COMMAND=(--env-file "${LAUNCH_ARG_ENVFILE}" "${COMMAND[@]}")

docker compose "${COMMAND[@]}"

# pull latest image version
if [ "${LAUNCH_PULL}" = true ] && [ -n "${LAUNCH_IMAGE}" ]; then
  _echo "Pulling ${LAUNCH_IMAGE}"
  docker pull "${LAUNCH_IMAGE}"
fi

# Ensures that a stop of this container cleans up any stranded services
trap _term SIGTERM

_echo "-----------------------------------"

COMMAND=(
  --project-name "${LAUNCH_PROJECT_NAME}" up
  --always-recreate-deps
  --force-recreate
  --abort-on-container-exit
  --remove-orphans
  --no-color
)

[[ -n "${LAUNCH_ARG_ENVFILE}" ]] && COMMAND=(--env-file "${LAUNCH_ARG_ENVFILE}" "${COMMAND[@]}")

# Here is the container started
docker compose "${COMMAND[@]}" &
wait $!

_cleanup
