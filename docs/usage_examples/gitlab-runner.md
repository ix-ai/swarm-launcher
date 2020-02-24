# GitLab CI Runner with Docker in Docker (`docker:dind`) and healthcheck

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
