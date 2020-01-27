# official Docker (CLI) image
FROM docker:latest
LABEL maintainer="docker@ix.ai"\
      ai.ix.repository="ix.ai/swarm-launcher"

# launch parameters
ENV LAUNCH_IMAGE=hello-world \
    LAUNCH_PULL=false \
    LAUNCH_CONTAINER_NAME="" \
    LAUNCH_PRIVILEGED=false \
    LAUNCH_INTERACTIVE=false \
    LAUNCH_TTY=false \
    LAUNCH_HOST_NETWORK=false \
    LAUNCH_ENVIRONMENT="" \
    LAUNCH_VOLUMES="" \
    LAUNCH_EXTRA_ARGS="" \
    LOGIN_USER="" \
    LOGIN_PASSWORD="" \
    LOGIN_REGISTRY=""

# add entrypoint.sh launcher script
ADD entrypoint.sh /

# run the image
ENTRYPOINT /entrypoint.sh
