# Networking

There are currently three ways of configuring the network of a container launched by `swarm-launcher`, which are partially mutually-exclusive:

* [LAUNCH_HOST_NETWORK](#launch_host_network)
* [LAUNCH_EXT_NETWORKS](#launch_ext_networks)
* [LAUNCH_NETWORKS](#launch_networks)

## Ingress network

The container started by swarm-launcher does **not** run as a [docker service](https://docs.docker.com/engine/reference/commandline/service/), but as a stand-alone container. Because the [ingress](https://docs.docker.com/engine/swarm/ingress/) network is not [attachable](https://docs.docker.com/network/overlay/#customize-the-default-ingress-network), the only way for a published port to be opened on all nodes is with a proxy service deployed in swarm (for example: [haproxy](https://hub.docker.com/_/haproxy), [traefik](https://docs.traefik.io/)), connected to the same overlay network as the container.

## LAUNCH_HOST_NETWORK

If the option `LAUNCH_HOST_NETWORK` is set, the following other options are ignored:
* `LAUNCH_PORTS`
* `LAUNCH_NETWORKS`
* `LAUNCH_EXT_NETWORKS`

The container then receives the option `network_mode: host` ([link to documentation](https://docs.docker.com/compose/compose-file/#network_mode)).

## LAUNCH_EXT_NETWORKS

This is a **space** separated list of already existing networks. It means, the networks specified here **must** exist when the container is created.

**Warning**: The network **must** be created with the `attachable: true` option!

There are two options here:
* The network gets created **outside** the stack (by using `docker network create`)
* The network gets created by the stack (by specifying `networks` in your stack yml file)

### Example #1:
Let's say, I want to deploy a stack called `ci-runners` for my gitlab pipeline. And I want the network to be created automatically, when deploying the stack:
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
    image: registry.gitlab.com/ix.ai/swarm-launcher:latest
    networks:
      - runners
    volumes:
      - '/var/run/docker.sock:/var/run/docker.sock:rw'
    environment:
      LAUNCH_IMAGE: gitlab/gitlab-runner:alpine
      LAUNCH_PULL: 'true'
      LAUNCH_EXT_NETWORKS: 'ci-runners_runners'
      LAUNCH_CONTAINER_NAME: 'gitlab-ci-runner'
      LAUNCH_PRIVILEGED: 'true'
      LAUNCH_VOLUMES: '/var/run/docker.sock:/var/run/docker.sock:rw /var/storage/docker/gitlab-runner:/etc/gitlab-runner:rw'
      LAUNCH_COMMAND: 'run --listen-address=:9252 --user=gitlab-runner --working-directory=/home/gitlab-runner'
    healthcheck:
      test: ["CMD", "curl", "-f", "http://gitlab-ci-runner:9252/metrics"]
      timeout: 2s
      retries: 3
      start_period: 30s
networks:
  runners:
    driver: bridge
    attachable: true
```
**Note**: The `ai.ix.auto-update: 'true'` label I'm using is for [ix-ai/cioban](/ix-ai/cioban).

As you can see, the value for `LAUNCH_EXT_NETWORKS` is set to `ci-runners_runners`. This is because the stack itself is named `ci-runners` (and gets deployed with `docker stack deploy -c stack.yml ci-runners`) and the network defined in the stack is called `runners`.

### Example #2:
Let's say, I want to deploy a stack called `ci-runners` for my gitlab pipeline. And I want it to be attached to an existing network `traefik-oauth`.

You need to make sure that the existing network allows for containers to be attached to it:
```sh
docker network inspect traefik-oauth|grep Attach
        "Attachable": true,
```

If it doesn't, you need either to create a network that allows attaching ([link to documentation](https://docs.docker.com/engine/reference/commandline/network_create/)), or delete this one and create it again with the `--attachable` option:
```sh
$ docker network rm traefik-web
traefik-web
$ docker network create --attachable --driver overlay --opt encrypted=true traefik-web
vnji34a5jzfvxnotgkznd165c
```


<details>
  <summary>Click to see the command: `docker network inspect traefik-web`</summary>


```json
[
    {
        "Name": "traefik-web",
        "Id": "vnji34a5jzfvxnotgkznd165c",
        "Created": "2020-02-18T06:15:14.190547649Z",
        "Scope": "swarm",
        "Driver": "overlay",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "10.0.28.0/24",
                    "Gateway": "10.0.28.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": true,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": null,
        "Options": {
            "com.docker.network.driver.overlay.vxlanid_list": "4124",
            "encrypted": "true"
        },
        "Labels": null
    }
]
```

</details>


The `stack.yml` only needs then to have the a minimum number of options configured:
```yml
version: "3.7"

services:
  runner-launcher:
    deploy:
      labels:
        ai.ix.auto-update: 'true'
    image: registry.gitlab.com/ix.ai/swarm-launcher:latest
    volumes:
      - '/var/run/docker.sock:/var/run/docker.sock:rw'
    environment:
      LAUNCH_IMAGE: gitlab/gitlab-runner:alpine
      LAUNCH_PULL: 'true'
      LAUNCH_EXT_NETWORKS: 'traefik-web'
      LAUNCH_PRIVILEGED: 'true'
      LAUNCH_VOLUMES: '/var/run/docker.sock:/var/run/docker.sock:rw /var/storage/docker/gitlab-runner:/etc/gitlab-runner:rw'
      LAUNCH_COMMAND: 'run --listen-address=:9252 --user=gitlab-runner --working-directory=/home/gitlab-runner'
```

You deploy it:
```sh
$ docker stack deploy -c stack.yml ci-runners
Creating network ci-runners_default
Creating service ci-runners_runner-launcher
```

And then, let's check the progress (it may take a while):
```sh
$ docker service ls
ID                  NAME                         MODE                REPLICAS            IMAGE                           PORTS
71oyeqy0rnqc        ci-runners_runner-launcher   replicated          1/1                 registry.gitlab.com/ix.ai/swarm-launcher:latest
```

<details>
  <summary>Click to see the command: `docker service inspect --pretty ci-runners_runner-launcher`</summary>

```
ID:		71oyeqy0rnqcilnd9wsgp3juz
Name:		ci-runners_runner-launcher
Labels:
 ai.ix.auto-update=true
 com.docker.stack.image=registry.gitlab.com/ix.ai/swarm-launcher:latest
 com.docker.stack.namespace=ci-runners
Service Mode:	Replicated
 Replicas:	1
Placement:
UpdateConfig:
 Parallelism:	1
 On failure:	pause
 Monitoring Period: 5s
 Max failure ratio: 0
 Update order:      stop-first
RollbackConfig:
 Parallelism:	1
 On failure:	pause
 Monitoring Period: 5s
 Max failure ratio: 0
 Rollback order:    stop-first
ContainerSpec:
 Image:		registry.gitlab.com/ix.ai/swarm-launcher:latest@sha256:2eb4d8fbc67ca15e31a6ed07ac08b3f38c4e82e46abda5c2410cc61b976518d0
 Env:		LAUNCH_COMMAND=run --listen-address=:9252 --user=gitlab-runner --working-directory=/home/gitlab-runner LAUNCH_EXT_NETWORKS=traefik-web LAUNCH_IMAGE=gitlab/gitlab-runner:alpine LAUNCH_PRIVILEGED=true LAUNCH_PULL=true LAUNCH_VOLUMES=/var/run/docker.sock:/var/run/docker.sock:rw /var/storage/docker/gitlab-runner:/etc/gitlab-runner:rw
Mounts:
 Target:	/var/run/docker.sock
  Source:	/var/run/docker.sock
  ReadOnly:	false
  Type:		bind
Resources:
Networks: ci-runners_default
Endpoint Mode:	vip
```

</details>

On the node where `swarm-launcher` is running, you can also see the other container:
```sh
$ docker ps -f label=ai.ix.started-by=ix.ai/swarm-launcher
CONTAINER ID        IMAGE                         COMMAND                  CREATED             STATUS              PORTS               NAMES
4b6ba8fdc720        gitlab/gitlab-runner:alpine   "/usr/bin/dumb-init …"   3 minutes ago       Up 3 minutes                            swarm-launcher_Xbv1eP_1
```

<details>
  <summary>Click to see the command: `docker inspect swarm-launcher_Xbv1eP_1`</summary>

```json
[
    {
        "Id": "4b6ba8fdc7202f0823860b44c7e950112fd6fb0173e6a8bc0d2ff7ba62f26c17",
        "Created": "2020-02-18T06:18:14.523467575Z",
        "Path": "/usr/bin/dumb-init",
        "Args": [
            "/entrypoint",
            "run",
            "--listen-address=:9252",
            "--user=gitlab-runner",
            "--working-directory=/home/gitlab-runner"
        ],
        "State": {
            "Status": "running",
            "Running": true,
            "Paused": false,
            "Restarting": false,
            "OOMKilled": false,
            "Dead": false,
            "Pid": 3749,
            "ExitCode": 0,
            "Error": "",
            "StartedAt": "2020-02-18T06:18:15.631715818Z",
            "FinishedAt": "0001-01-01T00:00:00Z"
        },
        "Image": "sha256:477b30b7fb67f2db80fd2d3846ca071b3327ef0fbb233316cb9c576468ac114d",
        "ResolvConfPath": "/var/lib/docker/containers/4b6ba8fdc7202f0823860b44c7e950112fd6fb0173e6a8bc0d2ff7ba62f26c17/resolv.conf",
        "HostnamePath": "/var/lib/docker/containers/4b6ba8fdc7202f0823860b44c7e950112fd6fb0173e6a8bc0d2ff7ba62f26c17/hostname",
        "HostsPath": "/var/lib/docker/containers/4b6ba8fdc7202f0823860b44c7e950112fd6fb0173e6a8bc0d2ff7ba62f26c17/hosts",
        "LogPath": "/var/lib/docker/containers/4b6ba8fdc7202f0823860b44c7e950112fd6fb0173e6a8bc0d2ff7ba62f26c17/4b6ba8fdc7202f0823860b44c7e950112fd6fb0173e6a8bc0d2ff7ba62f26c17-json.log",
        "Name": "/swarm-launcher_Xbv1eP_1",
        "RestartCount": 0,
        "Driver": "overlay2",
        "Platform": "linux",
        "MountLabel": "",
        "ProcessLabel": "",
        "AppArmorProfile": "",
        "ExecIDs": null,
        "HostConfig": {
            "Binds": [
                "/var/storage/docker/gitlab-runner:/etc/gitlab-runner:rw",
                "/var/run/docker.sock:/var/run/docker.sock:rw"
            ],
            "ContainerIDFile": "",
            "LogConfig": {
                "Type": "json-file",
                "Config": {}
            },
            "NetworkMode": "traefik-web",
            "PortBindings": {},
            "RestartPolicy": {
                "Name": "no",
                "MaximumRetryCount": 0
            },
            "AutoRemove": false,
            "VolumeDriver": "",
            "VolumesFrom": [],
            "CapAdd": null,
            "CapDrop": null,
            "Capabilities": null,
            "Dns": null,
            "DnsOptions": null,
            "DnsSearch": null,
            "ExtraHosts": null,
            "GroupAdd": null,
            "IpcMode": "shareable",
            "Cgroup": "",
            "Links": null,
            "OomScoreAdj": 0,
            "PidMode": "",
            "Privileged": true,
            "PublishAllPorts": false,
            "ReadonlyRootfs": false,
            "SecurityOpt": [
                "label=disable"
            ],
            "UTSMode": "",
            "UsernsMode": "",
            "ShmSize": 67108864,
            "Runtime": "runc",
            "ConsoleSize": [
                0,
                0
            ],
            "Isolation": "",
            "CpuShares": 0,
            "Memory": 0,
            "NanoCpus": 0,
            "CgroupParent": "",
            "BlkioWeight": 0,
            "BlkioWeightDevice": null,
            "BlkioDeviceReadBps": null,
            "BlkioDeviceWriteBps": null,
            "BlkioDeviceReadIOps": null,
            "BlkioDeviceWriteIOps": null,
            "CpuPeriod": 0,
            "CpuQuota": 0,
            "CpuRealtimePeriod": 0,
            "CpuRealtimeRuntime": 0,
            "CpusetCpus": "",
            "CpusetMems": "",
            "Devices": null,
            "DeviceCgroupRules": null,
            "DeviceRequests": null,
            "KernelMemory": 0,
            "KernelMemoryTCP": 0,
            "MemoryReservation": 0,
            "MemorySwap": 0,
            "MemorySwappiness": null,
            "OomKillDisable": false,
            "PidsLimit": null,
            "Ulimits": null,
            "CpuCount": 0,
            "CpuPercent": 0,
            "IOMaximumIOps": 0,
            "IOMaximumBandwidth": 0,
            "MaskedPaths": null,
            "ReadonlyPaths": null
        },
        "GraphDriver": {
            "Data": {
                "LowerDir": "/var/lib/docker/overlay2/bdb9c5c1216c0184e9acb263bb325006149923c0e0a2af14b528489bf5f2a865-init/diff:/var/lib/docker/overlay2/5c50da38b54ea659b8c8a254e0cfde04d2d6f55d2e7dfb332924da60bcd9bdf9/diff:/var/lib/docker/overlay2/235444f533fefd43a3f16c740bdaf9032d276485fd6d4af8e1ed7db9c9f3d220/diff:/var/lib/docker/overlay2/7dcdaad22907ecce5f0be15eecd708ba6403644f4f0d870bc6ec17db1eee38e6/diff:/var/lib/docker/overlay2/20bcd62d82a56a6f33fecc54039776082f3e5f8d19bf0b4d9159eba9c541a9f2/diff:/var/lib/docker/overlay2/fb042eeb41ca21981db662493f63ed8668b0a78e5eafb42564a1933ea500fb1d/diff:/var/lib/docker/overlay2/039617b6dd19553bebb94f8e59eb012efb7c988c6c06565a5054d0c46f063f8a/diff:/var/lib/docker/overlay2/1cd285bc316c710f75976f0aab094b8b166db1ba7784cc83db68bc3e1262985c/diff:/var/lib/docker/overlay2/6a3bb2827ec554171948604936781647709d426953cd86e5995978f7a2ab3d83/diff",
                "MergedDir": "/var/lib/docker/overlay2/bdb9c5c1216c0184e9acb263bb325006149923c0e0a2af14b528489bf5f2a865/merged",
                "UpperDir": "/var/lib/docker/overlay2/bdb9c5c1216c0184e9acb263bb325006149923c0e0a2af14b528489bf5f2a865/diff",
                "WorkDir": "/var/lib/docker/overlay2/bdb9c5c1216c0184e9acb263bb325006149923c0e0a2af14b528489bf5f2a865/work"
            },
            "Name": "overlay2"
        },
        "Mounts": [
            {
                "Type": "bind",
                "Source": "/var/storage/docker/gitlab-runner",
                "Destination": "/etc/gitlab-runner",
                "Mode": "rw",
                "RW": true,
                "Propagation": "rprivate"
            },
            {
                "Type": "bind",
                "Source": "/var/run/docker.sock",
                "Destination": "/var/run/docker.sock",
                "Mode": "rw",
                "RW": true,
                "Propagation": "rprivate"
            },
            {
                "Type": "volume",
                "Name": "6a292b20cb9c39e9875f7c6ca79d8252f8b0913cc12018759ffc6602ff1dfb54",
                "Source": "/var/lib/docker/volumes/6a292b20cb9c39e9875f7c6ca79d8252f8b0913cc12018759ffc6602ff1dfb54/_data",
                "Destination": "/home/gitlab-runner",
                "Driver": "local",
                "Mode": "",
                "RW": true,
                "Propagation": ""
            }
        ],
        "Config": {
            "Hostname": "4b6ba8fdc720",
            "Domainname": "",
            "User": "",
            "AttachStdin": false,
            "AttachStdout": false,
            "AttachStderr": false,
            "Tty": false,
            "OpenStdin": false,
            "StdinOnce": false,
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
            ],
            "Cmd": [
                "run",
                "--listen-address=:9252",
                "--user=gitlab-runner",
                "--working-directory=/home/gitlab-runner"
            ],
            "Image": "gitlab/gitlab-runner:alpine",
            "Volumes": {
                "/etc/gitlab-runner": {},
                "/home/gitlab-runner": {},
                "/var/run/docker.sock": {}
            },
            "WorkingDir": "",
            "Entrypoint": [
                "/usr/bin/dumb-init",
                "/entrypoint"
            ],
            "OnBuild": null,
            "Labels": {
                "ai.ix.started-by": "ix.ai/swarm-launcher",
                "com.docker.compose.config-hash": "528fbccc990e8d462ce6d95f40086034a6ce83be5720ff803b57a6121eb16806",
                "com.docker.compose.container-number": "1",
                "com.docker.compose.oneoff": "False",
                "com.docker.compose.project": "swarm-launcher",
                "com.docker.compose.project.config_files": "docker-compose.yml",
                "com.docker.compose.project.working_dir": "/",
                "com.docker.compose.service": "Xbv1eP",
                "com.docker.compose.version": "1.25.1"
            },
            "StopSignal": "SIGQUIT"
        },
        "NetworkSettings": {
            "Bridge": "",
            "SandboxID": "35b80fea39647f8e55931e2fcfc7c68c910ecaf0bde04170ab0111509d85e75c",
            "HairpinMode": false,
            "LinkLocalIPv6Address": "",
            "LinkLocalIPv6PrefixLen": 0,
            "Ports": {},
            "SandboxKey": "/var/run/docker/netns/35b80fea3964",
            "SecondaryIPAddresses": null,
            "SecondaryIPv6Addresses": null,
            "EndpointID": "",
            "Gateway": "",
            "GlobalIPv6Address": "",
            "GlobalIPv6PrefixLen": 0,
            "IPAddress": "",
            "IPPrefixLen": 0,
            "IPv6Gateway": "",
            "MacAddress": "",
            "Networks": {
                "traefik-web": {
                    "IPAMConfig": {
                        "IPv4Address": "10.0.28.2"
                    },
                    "Links": null,
                    "Aliases": [
                        "4b6ba8fdc720",
                        "Xbv1eP"
                    ],
                    "NetworkID": "vnji34a5jzfvxnotgkznd165c",
                    "EndpointID": "515cdd7eba1db33047d13fa6d5affb1d950bf67c88c674330bc9b7667ae64c53",
                    "Gateway": "",
                    "IPAddress": "10.0.28.2",
                    "IPPrefixLen": 24,
                    "IPv6Gateway": "",
                    "GlobalIPv6Address": "",
                    "GlobalIPv6PrefixLen": 0,
                    "MacAddress": "02:42:0a:00:1c:02",
                    "DriverOpts": null
                }
            }
        }
    }
]
```

</details>

## LAUNCH_NETWORKS

This is a space separated list of networks to be created by swarm-launcher **on the node where it's running**.

The networks are created with the driver `bridge` and will be named according to the name of project (see `LAUNCH_PROJECT_NAME` in [Environment variables](../blob/master/README.md#environment-variables))

### Example #1

I'll reuse the example above, with starting up a GitLab CI Runner.

This would be the `stack.yml` file:
```yml
version: "3.7"

services:
  runner-launcher:
    deploy:
      labels:
        ai.ix.auto-update: 'true'
    image: registry.gitlab.com/ix.ai/swarm-launcher:latest
    volumes:
      - '/var/run/docker.sock:/var/run/docker.sock:rw'
    environment:
      LAUNCH_IMAGE: gitlab/gitlab-runner:alpine
      LAUNCH_PULL: 'true'
      LAUNCH_NETWORKS: 'amazing'
      LAUNCH_PROJECT_NAME: 'ci-runner'
      LAUNCH_PRIVILEGED: 'true'
      LAUNCH_VOLUMES: '/var/run/docker.sock:/var/run/docker.sock:rw /var/storage/docker/gitlab-runner:/etc/gitlab-runner:rw'
      LAUNCH_COMMAND: 'run --listen-address=:9252 --user=gitlab-runner --working-directory=/home/gitlab-runner'
```

Deploy it and then see the networks:
```sh
$ docker stack deploy -c stack.yml ci-runner-starter
Creating network ci-runner-starter_default
Creating service ci-runner-starter_runner-launcher
$ docker network ls
[...]
be26a0a53689        ci-runner_amazing           bridge              local
[...]
```

The network has been created and has the name in the form `$LAUNCH_PROJECT_NAME_$LAUNCH_NETWORKS`.


<details>
  <summary>Click to see the command: `docker network inspect ci-runner_amazing`</summary>

```json
[
    {
        "Name": "ci-runner_amazing",
        "Id": "be26a0a536891a169211b14416de1f47f5dc7b62d42c559fd1c8e30991df51c7",
        "Created": "2020-02-18T07:14:15.038551358Z",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "172.19.0.0/16",
                    "Gateway": "172.19.0.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": true,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {
            "112fdfc7489539a630e9cd4a13efe178b96942ef68f365d951ea867c07701828": {
                "Name": "ci-runner_pYd0gd_1",
                "EndpointID": "6dc314afd3fb598256dd0113520d100797c534d1093d35becbde204309b48e85",
                "MacAddress": "02:42:ac:13:00:02",
                "IPv4Address": "172.19.0.2/16",
                "IPv6Address": ""
            }
        },
        "Options": {},
        "Labels": {
            "com.docker.compose.network": "amazing",
            "com.docker.compose.project": "ci-runner",
            "com.docker.compose.version": "1.25.1"
        }
    }
]
```

</details>


### Example #2

You can even combine `LAUNCH_NETWORKS` and `LAUNCH_EXT_NETWORKS`. Let's add to the stack.yml above also the existing `traefik-web` **attachable** network:

```yml
version: "3.7"

services:
  runner-launcher:
    deploy:
      labels:
        ai.ix.auto-update: 'true'
    image: registry.gitlab.com/ix.ai/swarm-launcher:latest
    volumes:
      - '/var/run/docker.sock:/var/run/docker.sock:rw'
    environment:
      LAUNCH_IMAGE: gitlab/gitlab-runner:alpine
      LAUNCH_PULL: 'true'
      LAUNCH_NETWORKS: 'amazing'
      LAUNCH_EXT_NETWORKS: 'traefik-web'
      LAUNCH_PROJECT_NAME: 'ci-runner'
      LAUNCH_PRIVILEGED: 'true'
      LAUNCH_VOLUMES: '/var/run/docker.sock:/var/run/docker.sock:rw /var/storage/docker/gitlab-runner:/etc/gitlab-runner:rw'
      LAUNCH_COMMAND: 'run --listen-address=:9252 --user=gitlab-runner --working-directory=/home/gitlab-runner'
```

And now, let's deploy it and see the outcome:

```sh
$ docker stack deploy -c stack.yml ci-runner-starter
Updating service ci-runner-starter_runner-launcher (id: jvxr6ukkailli4n6d1lpcbroy)
$ docker ps -f name=ci-runner
CONTAINER ID        IMAGE                           COMMAND                  CREATED              STATUS              PORTS               NAMES
1f859f84aef7        gitlab/gitlab-runner:alpine     "/usr/bin/dumb-init …"   About a minute ago   Up About a minute                       ci-runner_jzwdPf_1
915bc20df741        registry.gitlab.com/ix.ai/swarm-launcher:latest   "/bin/sh -c /entrypo…"   About a minute ago   Up About a minute                       ci-runner-starter_runner-launcher.1.i7qxfidjdd4oo2yb99m8f6en3
```

<details>
  <summary>Click to see the command: `docker inspect ci-runner_jzwdPf_1`</summary>

```json
[
    {
        "Id": "1f859f84aef7faff641c761377f938e0ee91d00768992135e026f8593c65759c",
        "Created": "2020-02-18T07:21:24.671362767Z",
        "Path": "/usr/bin/dumb-init",
        "Args": [
            "/entrypoint",
            "run",
            "--listen-address=:9252",
            "--user=gitlab-runner",
            "--working-directory=/home/gitlab-runner"
        ],
        "State": {
            "Status": "running",
            "Running": true,
            "Paused": false,
            "Restarting": false,
            "OOMKilled": false,
            "Dead": false,
            "Pid": 6311,
            "ExitCode": 0,
            "Error": "",
            "StartedAt": "2020-02-18T07:21:25.68226633Z",
            "FinishedAt": "0001-01-01T00:00:00Z"
        },
        "Image": "sha256:477b30b7fb67f2db80fd2d3846ca071b3327ef0fbb233316cb9c576468ac114d",
        "ResolvConfPath": "/var/lib/docker/containers/1f859f84aef7faff641c761377f938e0ee91d00768992135e026f8593c65759c/resolv.conf",
        "HostnamePath": "/var/lib/docker/containers/1f859f84aef7faff641c761377f938e0ee91d00768992135e026f8593c65759c/hostname",
        "HostsPath": "/var/lib/docker/containers/1f859f84aef7faff641c761377f938e0ee91d00768992135e026f8593c65759c/hosts",
        "LogPath": "/var/lib/docker/containers/1f859f84aef7faff641c761377f938e0ee91d00768992135e026f8593c65759c/1f859f84aef7faff641c761377f938e0ee91d00768992135e026f8593c65759c-json.log",
        "Name": "/ci-runner_jzwdPf_1",
        "RestartCount": 0,
        "Driver": "overlay2",
        "Platform": "linux",
        "MountLabel": "",
        "ProcessLabel": "",
        "AppArmorProfile": "",
        "ExecIDs": null,
        "HostConfig": {
            "Binds": [
                "/var/run/docker.sock:/var/run/docker.sock:rw",
                "/var/storage/docker/gitlab-runner:/etc/gitlab-runner:rw"
            ],
            "ContainerIDFile": "",
            "LogConfig": {
                "Type": "json-file",
                "Config": {}
            },
            "NetworkMode": "ci-runner_amazing",
            "PortBindings": {},
            "RestartPolicy": {
                "Name": "no",
                "MaximumRetryCount": 0
            },
            "AutoRemove": false,
            "VolumeDriver": "",
            "VolumesFrom": [],
            "CapAdd": null,
            "CapDrop": null,
            "Capabilities": null,
            "Dns": null,
            "DnsOptions": null,
            "DnsSearch": null,
            "ExtraHosts": null,
            "GroupAdd": null,
            "IpcMode": "shareable",
            "Cgroup": "",
            "Links": null,
            "OomScoreAdj": 0,
            "PidMode": "",
            "Privileged": true,
            "PublishAllPorts": false,
            "ReadonlyRootfs": false,
            "SecurityOpt": [
                "label=disable"
            ],
            "UTSMode": "",
            "UsernsMode": "",
            "ShmSize": 67108864,
            "Runtime": "runc",
            "ConsoleSize": [
                0,
                0
            ],
            "Isolation": "",
            "CpuShares": 0,
            "Memory": 0,
            "NanoCpus": 0,
            "CgroupParent": "",
            "BlkioWeight": 0,
            "BlkioWeightDevice": null,
            "BlkioDeviceReadBps": null,
            "BlkioDeviceWriteBps": null,
            "BlkioDeviceReadIOps": null,
            "BlkioDeviceWriteIOps": null,
            "CpuPeriod": 0,
            "CpuQuota": 0,
            "CpuRealtimePeriod": 0,
            "CpuRealtimeRuntime": 0,
            "CpusetCpus": "",
            "CpusetMems": "",
            "Devices": null,
            "DeviceCgroupRules": null,
            "DeviceRequests": null,
            "KernelMemory": 0,
            "KernelMemoryTCP": 0,
            "MemoryReservation": 0,
            "MemorySwap": 0,
            "MemorySwappiness": null,
            "OomKillDisable": false,
            "PidsLimit": null,
            "Ulimits": null,
            "CpuCount": 0,
            "CpuPercent": 0,
            "IOMaximumIOps": 0,
            "IOMaximumBandwidth": 0,
            "MaskedPaths": null,
            "ReadonlyPaths": null
        },
        "GraphDriver": {
            "Data": {
                "LowerDir": "/var/lib/docker/overlay2/4690e753634c35aeed7119b2c83e8711a59be8408742d0455df22b39677886e7-init/diff:/var/lib/docker/overlay2/5c50da38b54ea659b8c8a254e0cfde04d2d6f55d2e7dfb332924da60bcd9bdf9/diff:/var/lib/docker/overlay2/235444f533fefd43a3f16c740bdaf9032d276485fd6d4af8e1ed7db9c9f3d220/diff:/var/lib/docker/overlay2/7dcdaad22907ecce5f0be15eecd708ba6403644f4f0d870bc6ec17db1eee38e6/diff:/var/lib/docker/overlay2/20bcd62d82a56a6f33fecc54039776082f3e5f8d19bf0b4d9159eba9c541a9f2/diff:/var/lib/docker/overlay2/fb042eeb41ca21981db662493f63ed8668b0a78e5eafb42564a1933ea500fb1d/diff:/var/lib/docker/overlay2/039617b6dd19553bebb94f8e59eb012efb7c988c6c06565a5054d0c46f063f8a/diff:/var/lib/docker/overlay2/1cd285bc316c710f75976f0aab094b8b166db1ba7784cc83db68bc3e1262985c/diff:/var/lib/docker/overlay2/6a3bb2827ec554171948604936781647709d426953cd86e5995978f7a2ab3d83/diff",
                "MergedDir": "/var/lib/docker/overlay2/4690e753634c35aeed7119b2c83e8711a59be8408742d0455df22b39677886e7/merged",
                "UpperDir": "/var/lib/docker/overlay2/4690e753634c35aeed7119b2c83e8711a59be8408742d0455df22b39677886e7/diff",
                "WorkDir": "/var/lib/docker/overlay2/4690e753634c35aeed7119b2c83e8711a59be8408742d0455df22b39677886e7/work"
            },
            "Name": "overlay2"
        },
        "Mounts": [
            {
                "Type": "bind",
                "Source": "/var/run/docker.sock",
                "Destination": "/var/run/docker.sock",
                "Mode": "rw",
                "RW": true,
                "Propagation": "rprivate"
            },
            {
                "Type": "bind",
                "Source": "/var/storage/docker/gitlab-runner",
                "Destination": "/etc/gitlab-runner",
                "Mode": "rw",
                "RW": true,
                "Propagation": "rprivate"
            },
            {
                "Type": "volume",
                "Name": "8dc99d7b0070d69959d0c35a15e58c00803cef3f8466445d19afc64294bb3cce",
                "Source": "/var/lib/docker/volumes/8dc99d7b0070d69959d0c35a15e58c00803cef3f8466445d19afc64294bb3cce/_data",
                "Destination": "/home/gitlab-runner",
                "Driver": "local",
                "Mode": "",
                "RW": true,
                "Propagation": ""
            }
        ],
        "Config": {
            "Hostname": "1f859f84aef7",
            "Domainname": "",
            "User": "",
            "AttachStdin": false,
            "AttachStdout": false,
            "AttachStderr": false,
            "Tty": false,
            "OpenStdin": false,
            "StdinOnce": false,
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
            ],
            "Cmd": [
                "run",
                "--listen-address=:9252",
                "--user=gitlab-runner",
                "--working-directory=/home/gitlab-runner"
            ],
            "Image": "gitlab/gitlab-runner:alpine",
            "Volumes": {
                "/etc/gitlab-runner": {},
                "/home/gitlab-runner": {},
                "/var/run/docker.sock": {}
            },
            "WorkingDir": "",
            "Entrypoint": [
                "/usr/bin/dumb-init",
                "/entrypoint"
            ],
            "OnBuild": null,
            "Labels": {
                "ai.ix.started-by": "ix.ai/swarm-launcher",
                "com.docker.compose.config-hash": "16f4c8fda111e72937b69623b30b163d0f8e49d9ed0feebd11ef79f6fd94cf75",
                "com.docker.compose.container-number": "1",
                "com.docker.compose.oneoff": "False",
                "com.docker.compose.project": "ci-runner",
                "com.docker.compose.project.config_files": "docker-compose.yml",
                "com.docker.compose.project.working_dir": "/",
                "com.docker.compose.service": "jzwdPf",
                "com.docker.compose.version": "1.25.1"
            },
            "StopSignal": "SIGQUIT"
        },
        "NetworkSettings": {
            "Bridge": "",
            "SandboxID": "188af86224bb161f02692fe77a6ae158d238809831240088e5aa82f76bb97945",
            "HairpinMode": false,
            "LinkLocalIPv6Address": "",
            "LinkLocalIPv6PrefixLen": 0,
            "Ports": {},
            "SandboxKey": "/var/run/docker/netns/188af86224bb",
            "SecondaryIPAddresses": null,
            "SecondaryIPv6Addresses": null,
            "EndpointID": "",
            "Gateway": "",
            "GlobalIPv6Address": "",
            "GlobalIPv6PrefixLen": 0,
            "IPAddress": "",
            "IPPrefixLen": 0,
            "IPv6Gateway": "",
            "MacAddress": "",
            "Networks": {
                "ci-runner_amazing": {
                    "IPAMConfig": null,
                    "Links": null,
                    "Aliases": [
                        "jzwdPf",
                        "1f859f84aef7"
                    ],
                    "NetworkID": "4d407a17e8c948b8ba26caf206ad00f98657ad96c42ee96be13a19e719b78e9b",
                    "EndpointID": "c63bdfa67cc0d8170db60f1e0ce5aa082c4d894f39066ed73001846c4e24706b",
                    "Gateway": "172.20.0.1",
                    "IPAddress": "172.20.0.2",
                    "IPPrefixLen": 16,
                    "IPv6Gateway": "",
                    "GlobalIPv6Address": "",
                    "GlobalIPv6PrefixLen": 0,
                    "MacAddress": "02:42:ac:14:00:02",
                    "DriverOpts": null
                },
                "traefik-web": {
                    "IPAMConfig": {
                        "IPv4Address": "10.0.28.4"
                    },
                    "Links": null,
                    "Aliases": [
                        "jzwdPf",
                        "1f859f84aef7"
                    ],
                    "NetworkID": "vnji34a5jzfvxnotgkznd165c",
                    "EndpointID": "cfea4017dda43a2af9151f48f41d9b7bf967215feb77a3bd805d00d01876646c",
                    "Gateway": "",
                    "IPAddress": "10.0.28.4",
                    "IPPrefixLen": 24,
                    "IPv6Gateway": "",
                    "GlobalIPv6Address": "",
                    "GlobalIPv6PrefixLen": 0,
                    "MacAddress": "02:42:0a:00:1c:04",
                    "DriverOpts": null
                }
            }
        }
    }
]
```

</details>
