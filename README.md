# swarm-launcher
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Fix-ai%2Fswarm-launcher.svg?type=shield)](https://app.fossa.io/projects/git%2Bgithub.com%2Fix-ai%2Fswarm-launcher?ref=badge_shield)

A docker image to allow the launch of container in docker swarm, with options normally unavailable to swarm mode

## How it works

The image uses `docker-compose` to start a new project (see `LAUNCH_PROJECT_NAME`). You can either use the environment variables to configure the service started inside, or you can supply your own `/docker-compose.yml` file.

Either way, `swarm-launcher` takes care of the setup, tear-down and cleanup of the project.

## Usage examples

### GitLab CI Runner with Docker in Docker (`docker:dind`) and healthcheck

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
      labels:
        ai.ix.auto-update: 'true'
    image: ixdotai/swarm-launcher:latest
    networks:
      - runners
    volumes:
      - '/var/run/docker.sock:/var/run/docker.sock:rw'
    environment:
      LAUNCH_IMAGE: gitlab/gitlab-runner:alpine
      LAUNCH_PULL: 'true'
      LAUNCH_EXT_NETWORKS: 'runners_runners'
      LAUNCH_PROJECT_NAME: 'ci'
      LAUNCH_SERVICE_NAME: 'runner'
      LAUNCH_CONTAINER_NAME: 'gitlab-ci-runner'
      LAUNCH_PRIVILEGED: 'true'
      LAUNCH_VOLUMES: '/var/run/docker.sock:/var/run/docker.sock:rw /var/storage/docker/gitlab-runner:/etc/gitlab-runner:rw'
      LAUNCH_PULL: 'true'
      LAUNCH_LABELS: 'ai.ix.auto-update=true'
      LAUNCH_COMMAND: 'run --listen-address=:9252 --user=gitlab-runner --working-directory=/home/gitlab-runner'
    healthcheck:
      test: ["CMD", "curl", "-f", "http://gitlab-ci-runner:9252/metrics"]
      timeout: 5s
      retries: 15
      start_period: 30s
networks:
  runners:
    driver: overlay
    driver_opts:
      encrypted: 'true'
    attachable: true

```

Then deploy it on your docker swarm:
```sh
$ sudo docker stack deploy --compose-file stack.yml --prune --with-registry-auth runners
Creating network runners_runners
Creating service runners_runner-launcher
```

After a minute or two, you will see everything running:
```sh
$ sudo docker service ls -f name=runner
ID                  NAME                      MODE                REPLICAS            IMAGE                               PORTS
vxgmp8v25kkk        runners_runner-launcher   global              3/3                 ixdotai/swarm-launcher:latest
$ sudo docker ps -f name=runner
CONTAINER ID        IMAGE                               COMMAND                  CREATED              STATUS                        PORTS               NAMES
371f43b30bd3        gitlab/gitlab-runner:alpine         "/usr/bin/dumb-init …"   About a minute ago   Up About a minute                                 gitlab-ci-runner
15be5268f736        ixdotai/swarm-launcher:latest       "/bin/sh -c /entrypo…"   About a minute ago   Up About a minute (healthy)                       runners_runner-launcher.wgay0ielark3a2wgnthkvy7fc.swq8jqxmonm4ay5gxjb62a2n0
```

Since **swarm-launcher** generates a `docker-compose.yml` file, this is how the file looks like (after applying `docker-compose config`):

```yml
networks:
  runners_runners:
    external: true
    name: runners_runners
services:
  runner:
    command: run --listen-address=:9252 --user=gitlab-runner --working-directory=/home/gitlab-runner
    container_name: gitlab-ci-runner
    image: gitlab/gitlab-runner:alpine
    labels:
      ai.ix.auto-update: "true"
    networks:
      runners_runners: null
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
    attachable: true
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
| `LAUNCH_HOST_NETWORK`   | `false`                    | NO            | Set this to `true` to start the container on the host network. This option is not compatible with `LAUNCH_PORTS`, `LAUNCH_NETWORKS` and `LAUNCH_EXT_NETWORKS` |
| `LAUNCH_PORTS`          | -                          | NO            | Space separated list of PortOnHost:PortInContainer |
| `LAUNCH_NETWORKS`       | -                          | NO            | Space separated list of project networks to create. All networks are created with `attachable: true` |
| `LAUNCH_EXT_NETWORKS`   | -                          | NO            | Space separated list of external networks to attach to |
| `LAUNCH_CAP_ADD`        | -                          | NO            | Space separated list of capabilities to add |
| `LAUNCH_CAP_DROP`       | -                          | NO            | Space separated list of capabilities to drop |
| `LAUNCH_LABELS`         | `ai.ix.started-by=ix.ai/swarm-launcher` | NO | Space separated list of Label=Value pairs |
| `LAUNCH_PULL`           | `false`                    | NO            | Set this to `true` to check at every container start for the latest image version |
| `LAUNCH_SYSCTLS`        | -                          | NO            | Space separated list of sysctl=value |
| `LAUNCH_COMMAND`        | -                          | NO            | A string that overrides the default command |
| `LAUNCH_CGROUP_PARENT`  | -                          | NO            | A string that specify the parent cgroup for the container |

**Note**: Make sure you check out the documentation in the [Wiki](https://github.com/ix-ai/swarm-launcher/wiki).

## Resources:
* Wiki: https://github.com/ix-ai/swarm-launcher/wiki
* GitLab: https://gitlab.com/ix.ai/swarm-launcher
* GitHub: https://github.com/ix-ai/swarm-launcher
* Docker Hub: https://hub.docker.com/r/ixdotai/swarm-launcher

## Credits
This Docker image is inspired by the post by [@akomelj](https://github.com/akomelj) in [moby/moby#25885](https://github.com/moby/moby/issues/25885#issuecomment-573449645)


## License
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Fix-ai%2Fswarm-launcher.svg?type=large)](https://app.fossa.io/projects/git%2Bgithub.com%2Fix-ai%2Fswarm-launcher?ref=badge_large)