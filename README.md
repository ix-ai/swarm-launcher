# swarm-launcher
A docker image to allow the launch of container in docker swarm, with options normally unavailable to swarm mode

## Usage example
```yml
version: "3.7"

services:
  swarm-launcher:
    image: ixdotai/swarm-launcher:dev-master
    environment:
      LAUNCH_IMAGE: registry.gitlab.com/ix.ai/tinc:dev-master
      LAUNCH_PROJECT_NAME: "vpn"
      LAUNCH_SERVICE_NAME: "tinc"
      LAUNCH_PULL: "true"
      LAUNCH_PRIVILEGED: "true"
      LAUNCH_HOST_NETWORK: "true"
      LAUNCH_ENVIRONMENTS: "IP_ADDR=1.2.3.4 ADDRESS=10.20.30.1 NETMASK=255.255.255.0 NETWORK=10.20.30.0/24 RUNMODE=server VERBOSE=2"
      LAUNCH_DEVICES: "/dev/ttyUSB0:/dev/ttyUSB0 /dev/ttyUSB1:/dev/ttyUSB1"
      LAUNCH_VOLUMES: "/var/storage/docker/tinc:/etc/tinc /etc/localtime:/etc/localtime:ro"
      LOGIN_USER: "gitlab+deploy-token-13"
      LOGIN_PASSWORD: "bar1u18sJ53,rP1gySg_"
      LOGIN_REGISTRY: "registry.gitlab.com"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

or just give it a spin manually

```sh
docker run --rm \
           -e LAUNCH_IMAGE=registry.gitlab.com/ix.ai/tinc:dev-master \
           -e LAUNCH_PULL="true" \
           -e LAUNCH_PRIVILEGED="true" \
           -e LAUNCH_HOST_NETWORK="true" \
           -e LAUNCH_ENVIRONMENTS="IP_ADDR=1.2.3.4 ADDRESS=10.20.30.1 NETMASK=255.255.255.0 NETWORK=10.20.30.0/24 RUNMODE=server VERBOSE=2" \
           -e LAUNCH_VOLUMES="/etc/localtime:/etc/localtime:ro" \
           -v /var/run/docker.sock:/var/run/docker.sock \
           ixdotai/swarm-launcher:dev-master
```

## Environment variables

The following environment variables are important, if you plan on using a private repository:

| **Variable**     |
|:-----------------|
| `LOGIN_USER`     |
| `LOGIN_PASSWORD` |
| `LOGIN_REGISTRY` |

The following environment variables are important if you don't supply a `/docker-compose.yml` file in the swarm-launcher container:

| **Variable**            | **Default**                | **Mandatory** | **Description**                                 |
|:------------------------|:--------------------------:|:-------------:|:------------------------------------------------|
| `LAUNCH_IMAGE`          | -                          | **YES**       | The image for the container |
| `LAUNCH_PROJECT_NAME`   | `swarm-launcher`           | NO            | If you want to use a specific name for the project (similar to the stack name) |
| `LAUNCH_SERVICE_NAME`   | random (by swarm-launcher) | NO            | If you want to use a specific name for the service |
| `LAUNCH_CONTAINER_NAME` | random (by docker)         | NO            | If you want to use a specific name for the container (similar to the task name) |
| `LAUNCH_PRIVILEGED`     | `false`                    | NO            | Set this to `true` if you want to start a privileged container |
| `LAUNCH_ENVIRONMENTS`   | -                          | NO            | Space separated list of Key=Value pairs |
| `LAUNCH_DEVICES`        | -                          | NO            | Space separated list of DeviceOnHost:DeviceInContainer |
| `LAUNCH_VOLUMES`        | -                          | NO            | Space separated list of File/FolderOnHost:File/FolderInContainer |
| `LAUNCH_HOST_NETWORK`   | `false`                    | NO            | Set this to `true` to start the container on the host network. This option is not compatible with `LAUNCH_PORTS` and `LAUNCH_NETWORKS` |
| `LAUNCH_PORTS`          | -                          | NO            | Space separated list of PortOnHost:PortInContainer |
| `LAUNCH_NETWORKS`       | -                          | NO            | Space separated list of project networks to attach to. All networks are created with `attachable: false` |
| `LAUNCH_EXT_NETWORKS`   | -                          | NO            | Space separated list of external networks to attach to |
| `LAUNCH_PULL`           | `false`                    | NO            | Set this to `true` to check at every container start for the latest image version |

The `docker-compose.yml` file that gets generated looks like this:

```yml
version: "3.7"

services:
  t8rcVy:
    image: "registry.gitlab.com/ix.ai/tinc:dev-master"
    restart: "no"
    labels:
      ai.ix.started-by: ix.ai/swarm-launcher
    privileged: "true"
    environment:
      - IP_ADDR=1.2.3.4
      - ADDRESS=10.20.30.1
      - NETMASK=255.255.255.0
      - NETWORK=10.20.30.0/24
      - RUNMODE=server
      - VERBOSE=2
    devices:
      - /dev/ttyUSB1:/dev/ttyUSB0
    volumes:
      - /docker/foo:/docker/bar:ro
    networks:
      - vpn
      - abc
networks:
  vpn:
    driver: bridge
    attachable: false
  abc:
    driver: bridge
    attachable: false
```

## Resources:
* GitLab: https://gitlab.com/ix.ai/swarm-launcher
* GitHub: https://github.com/ix-ai/swarm-launcher
* Docker Hub: https://hub.docker.com/r/ixdotai/swarm-launcher

## Credits
This Docker image is inspired by the post by [@akomelj](https://github.com/akomelj) in [moby/moby#25885](https://github.com/moby/moby/issues/25885#issuecomment-573449645)
