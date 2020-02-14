# swarm-launcher
A docker image to allow the launch of container in docker swarm, with options normally unavailable to swarm mode

## How it works

The image uses `docker-compose` to start a new project (see `LAUNCH_PROJECT_NAME`). You can either use the environment variables to configure the service started inside, or you can supply your own `/docker-compose.yml` file.

Either way, `swarm-launcher` takes care of the setup, tear-down and cleanup of the project.

## Usage examples

### GitLab CI Runner with Docker in Docker (`docker:dind`)

**Warning**: This creates one runner on every node you have in your swarm. If you don't want that, remove the line with `mode: global`.

First create the file `stack.yml`:
```yml
version: "3.7"

services:
  runner-launcher:
    deploy:
      mode: global
      restart_policy:
        delay: 5s
    image: ixdotai/swarm-launcher:latest
    volumes:
      - '/var/run/docker.sock:/var/run/docker.sock:rw'
    environment:
      LAUNCH_IMAGE: gitlab/gitlab-runner:alpine
      LAUNCH_PULL: 'true'
      LAUNCH_NETWORKS: 'runner-launcher'
      LAUNCH_PROJECT_NAME: 'ci'
      LAUNCH_SERVICE_NAME: 'runner'
      LAUNCH_PRIVILEGED: 'true'
      LAUNCH_VOLUMES: '/var/run/docker.sock:/var/run/docker.sock:rw /var/storage/docker/gitlab-runner:/etc/gitlab-runner:rw'
```

Then deploy it on your docker swarm:
```sh
$ sudo docker stack deploy --compose-file stack.yml --prune --with-registry-auth swarm-launcher
Creating network swarm-launcher_default
Creating service swarm-launcher_runner-launcher
```

After a minute or two, you will see everything running:
```sh
$ docker service ls -f name=swarm-launcher
ID                  NAME                             MODE                REPLICAS            IMAGE                               PORTS
ol6evlgsonht        swarm-launcher_runner-launcher   global              1/1                 ixdotai/swarm-launcher:latest
$ docker ps -f name=runner
CONTAINER ID        IMAGE                               COMMAND                  CREATED             STATUS              PORTS               NAMES
492092860a19        gitlab/gitlab-runner:alpine         "/usr/bin/dumb-init …"   2 minutes ago       Up 2 minutes                            ci_runner_1
b1d01c7eed90        ixdotai/swarm-launcher:dev-branch   "/bin/sh -c /entrypo…"   2 minutes ago       Up 2 minutes                            swarm-launcher_runner-launcher.x4aejcpuklo5bih3qmrcnxb6n.q7iajdrf2rrqibzhwvgikel80
```

Since **swarm-launcher** generates a `docker-compose.yml` file, this is how the file looks like (after applying `docker-compose config`):

```yml
networks:
  runner-launcher:
    attachable: false
    driver: bridge
services:
  runner:
    image: gitlab/gitlab-runner:alpine
    labels:
      ai.ix.started-by: ix.ai/swarm-launcher
    networks:
      runner-launcher: null
    privileged: true
    restart: "no"
    volumes:
    - /var/run/docker.sock:/var/run/docker.sock:rw
    - /var/storage/docker/gitlab-runner:/etc/gitlab-runner:rw
version: '3.7'
```

### OpenVPN Access Server

The stack.yml file:
```yml
version: "3.7"

services:
  runner-launcher:
    image: ixdotai/swarm-launcher:latest
    volumes:
      - '/var/run/docker.sock:/var/run/docker.sock:rw'
    environment:
      LAUNCH_IMAGE: linuxserver/openvpn-as:latest
      LAUNCH_PULL: 'true'
      LAUNCH_NETWORKS: 'openvpn-as'
      LAUNCH_ENVIRONMENTS: 'PUID=1000 PGID=1000 TZ=Europe/Berlin'
      LAUNCH_PORTS: '943:943 9443:9443 1194:1194/udp'
      LAUNCH_VOLUMES: '/var/storage/docker/openvpn-as:/config:rw'
      LAUNCH_CAP_ADD: 'NET_ADMIN'
```

This is how the generated `docker-compose.yml` file looks like (you'll notice the random service name, since we didn't set `LAUNCH_SERVICE_NAME`):
```yml
networks:
  openvpn-as:
    attachable: false
    driver: bridge
services:
  YVyaqr:
    cap_add:
    - NET_ADMIN
    environment:
      PGID: '1000'
      PUID: '1000'
      TZ: Europe/Berlin
    image: linuxserver/openvpn-as:latest
    labels:
      ai.ix.started-by: ix.ai/swarm-launcher
    networks:
      openvpn-as: null
    ports:
    - published: 943
      target: 943
    - published: 9443
      target: 9443
    - protocol: udp
      published: 1194
      target: 1194
    restart: "no"
    volumes:
    - /var/storage/docker/openvpn-as:/config:rw
version: '3.7'
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
| `LAUNCH_CAP_ADD`        | -                          | NO            | Space separated list of capabilities to add |
| `LAUNCH_LABELS`         | `ai.ix.started-by=ix.ai/swarm-launcher` | NO | Space separated list of Label=Value pairs |
| `LAUNCH_PULL`           | `false`                    | NO            | Set this to `true` to check at every container start for the latest image version |

The `docker-compose.yml` file that gets generated looks like this:

```yml
version: "3.7"

services:
  t8rcVy:
    image: "registry.gitlab.com/ix.ai/tinc:latest"
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
