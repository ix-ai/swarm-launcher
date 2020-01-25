#!/usr/bin/env sh
# pull latest image version
if [ "$LAUNCH_PULL" = true ]; then
    echo "Pulling $LAUNCH_IMAGE: docker pull $LAUNCH_IMAGE"
    docker pull "$LAUNCH_IMAGE"
fi

# build launch parameters
DOCKER_ARGS="run --rm"
[ -n "$LAUNCH_CONTAINER_NAME" ] && DOCKER_ARGS="$DOCKER_ARGS --name $LAUNCH_CONTAINER_NAME"
[ "$LAUNCH_PRIVILEGED" = true ] && DOCKER_ARGS="$DOCKER_ARGS --privileged"
[ "$LAUNCH_INTERACTIVE" = true ] && DOCKER_ARGS="$DOCKER_ARGS -i"
[ "$LAUNCH_TTY" = true ] && DOCKER_ARGS="$DOCKER_ARGS -t"
[ "$LAUNCH_HOST_NETWORK" = true ] && DOCKER_ARGS="$DOCKER_ARGS --net host"
DOCKER_ARGS="$DOCKER_ARGS $LAUNCH_ENVIRONMENT $LAUNCH_VOLUMES $LAUNCH_EXTRA_ARGS $LAUNCH_IMAGE"

echo "Running $LAUNCH_IMAGE: exec docker $DOCKER_ARGS"
# shellcheck disable=SC2086
exec docker $DOCKER_ARGS
