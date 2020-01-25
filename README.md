# swarm-launcher
A docker image to allow the launch of container in docker swarm, with options normally unavailable to swarm mode

## Usage example
```yml
version: "3.7"

services:
  swarm-launcher:
    image: ixdotai/swarm-launcher:dev-master
    environment:
      LAUNCH_IMAGE: ix-ai/tinc:latest
      LAUNCH_PULL: "true"
      LAUNCH_PRIVILEGED: "true"
      LAUNCH_HOST_NETWORK: "true"
      LAUNCH_ENVIRONMENT: "--env IP_ADDR=1.2.3.4 --env ADDRESS=10.20.30.1 --env NETMASK=255.255.255.0 --env NETWORK=10.20.30.0/24 --env RUNMODE=server --env VERBOSE=2"
      LAUNCH_VOLUMES: "-v /var/storage/docker/tinc:/etc/tinc -v /etc/localtime:/etc/localtime:ro"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

## Resources:
* GitLab: https://gitlab.com/ix.ai/swarm-launcher
* GitHub: https://github.com/ix-ai/swarm-launcher
* Docker Hub: https://hub.docker.com/r/ixdotai/swarm-launcher

## Credits
This Docker image is inspired by the post by [@akomelj](https://github.com/akomelj) in [moby/moby#25885](https://github.com/moby/moby/issues/25885#issuecomment-573449645)
