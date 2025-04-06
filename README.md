# swarm-launcher

[![Pipeline Status](https://gitlab.com/ix.ai/swarm-launcher/badges/master/pipeline.svg)](https://gitlab.com/ix.ai/swarm-launcher/)
[![Gitlab Project](https://img.shields.io/badge/GitLab-Project-554488.svg)](https://gitlab.com/ix.ai/swarm-launcher/)

A docker image to allow the launch of container in docker swarm, with options normally unavailable to swarm mode

## How it works

The image uses `docker-compose` to start a new project (see `LAUNCH_PROJECT_NAME`). You can either use the environment variables to configure the service started inside, or you can supply your own `/docker-compose.yml` file.

Either way, `swarm-launcher` takes care of the setup, tear-down and cleanup of the project.

## Supported architectures

The following architectures are supported by this image:

* `linux/amd64`
* `linux/arm64`
* `linux/arm/v7`
* `linux/arm/v6`
* `linux/386`

## Docs and Usage examples

See [Docs](docs/) and [Usage Examples](docs/usage_examples)

## Building the image

```sh
docker build -t swarm-launcher .
```

## Environment variables

The following environment variables are important, if you plan on using a private repository:

| **Variable**          |
|:----------------------|
| `LOGIN_USER`          |
| `LOGIN_PASSWORD`      |
| `LOGIN_PASSWORD_FILE` |
| `LOGIN_REGISTRY`      |

These variables are always used, if set:

| **Variable**            | **Default**                | **Mandatory** | **Description**                                 |
|:------------------------|:--------------------------:|:-------------:|:------------------------------------------------|
| `LAUNCH_PROJECT_NAME`   | random (by swarm-launcher) | NO            | If you want to use a specific name for the project (similar to the stack name) |
| `LAUNCH_PULL`           | `false`                    | NO            | Set this to `true` to check at every container start for the latest image version |
| `LAUNCH_IMAGE`          | -                          | **YES**       | The image for the container. Mandatory in the following two circumstances: no `/docker-compose.yml` file supplied or `LAUNCH_PULL` is set to `true` |
| `LAUNCH_ARG_ENVFILE`    | -                          | NO            | The path inside the `swarm-launcher` container with the [`env` file](https://docs.docker.com/compose/environment-variables/) used by `docker compose --env-file XXX up` |

The following environment variables are important if you don't supply a `/docker-compose.yml` file in the swarm-launcher container:

| **Variable**            | **Default**                | **Mandatory** | **Description**                                 |
|:------------------------|:--------------------------:|:-------------:|:------------------------------------------------|
| `LAUNCH_SERVICE_NAME`   | random (by swarm-launcher) | NO            | If you want to use a specific name for the service |
| `LAUNCH_CONTAINER_NAME` | random (by docker)         | NO            | If you want to use a specific name for the container (similar to the task name) |
| `LAUNCH_HOSTNAME`       | -                          | NO            | If you want to use a specific hostname for the container |
| `LAUNCH_PRIVILEGED`     | `false`                    | NO            | Set this to `true` if you want to start a privileged container |
| `LAUNCH_DEVICES`        | -                          | NO            | Space separated list of DeviceOnHost:DeviceInContainer |
| `LAUNCH_VOLUMES`        | -                          | NO            | Space separated list of File/FolderOnHost:File/FolderInContainer |
| `LAUNCH_HOST_NETWORK`   | `false`                    | NO            | Set this to `true` to start the container on the host network. This option is not compatible with `LAUNCH_NETWORK_MODE`, `LAUNCH_PORTS`, `LAUNCH_NETWORKS`, `LAUNCH_EXT_NETWORKS` and `LAUNCH_EXT_NETWORKS_IPV4` |
| `LAUNCH_NETWORK_MODE`   | -                   | NO            | Set this to a value that will be used as `network_mode`. This option is not compatible with `LAUNCH_HOST_NETWORK`, `LAUNCH_PORTS`, `LAUNCH_NETWORKS`, `LAUNCH_EXT_NETWORKS` and `LAUNCH_EXT_NETWORKS_IPV4` |
| `LAUNCH_PORTS`          | -                          | NO            | Space separated list of PortOnHost:PortInContainer |
| `LAUNCH_NETWORKS`       | -                          | NO            | Space separated list of project networks to create. All networks are created with `attachable: true` |
| `LAUNCH_EXT_NETWORKS`   | -                          | NO            | Space separated list of external networks to attach to |
| `LAUNCH_EXT_NETWORKS_IPV4` | -                       | NO            | Similar to `LAUNCH_EXT_NETWORKS`, this is a space separated list of ExistingExternalNetworkName:Ipv4Address |
| `LAUNCH_EXT_NETWORKS_IPV6` | -                       | NO            | Similar to `LAUNCH_EXT_NETWORKS`, this is a space separated list of ExistingExternalNetworkName-Ipv6Address |
| `LAUNCH_EXT_NETWORKS_MIXED` | -                      | NO            | Similar to `LAUNCH_EXT_NETWORKS`, this is a space separated list of ExistingExternalNetworkName-Ipv4Address-Ipv6Address |
| `LAUNCH_CAP_ADD`        | -                          | NO            | Space separated list of capabilities to add |
| `LAUNCH_CAP_DROP`       | -                          | NO            | Space separated list of capabilities to drop |
| `LAUNCH_SECURITY_OPT`   | -                          | NO            | Space separated list of security options to add |
| `LAUNCH_LABELS`         | `ai.ix.started-by=ix.ai/swarm-launcher` | NO | Space separated list of Label=Value pairs |
| `LAUNCH_SYSCTLS`        | -                          | NO            | Space separated list of sysctl=value |
| `LAUNCH_SHM_SIZE`       | -                          | NO            | Single value for the container SHM size. If omitted and not changed on a daemon level, all containers start with `67108864` (64 MB) |
| `LAUNCH_COMMAND`        | -                          | NO            | A string that overrides the default command |
| `LAUNCH_CGROUP_PARENT`  | -                          | NO            | A string that specify the parent cgroup for the container |
| `LAUNCH_STOP_GRACE_PERIOD` | `10s` (by docker)       | NO            | Allows to override the default [stop_grace_period](https://docs.docker.com/compose/compose-file/#stop_grace_period). **Note**: It makes sense to also add a slightly higher `stop_grace_period` to the `swarm-launcher` stack as well! |
| `LAUNCH_PID_MODE`       | -                          | NO            | Set this to `host` to enable PID address space sharing between container and host operating system |
| `LAUNCH_ULIMITS`        | -                          | NO            | Space separated list of Key=Value pairs. **Note**: Only integers are supported, NOT hard/soft ulimits! Example: `nproc=131072 nofile=60000 core=0` |
| `LAUNCH_EXTRA_HOSTS`    | -                          | NO            | Space separated list of HostName:Mapping pairs |
| `LAUNCH_DNS`            | -                          | NO            | Space separated list of DNS servers |
| `LAUNCH_DNS_SEARCH`     | -                          | NO            | Space separated list of DNS search domains |
| `LAUNCH_MAC_ADDRESS`    | -                          | NO            | Valid mac address for the launched container |
| `LAUNCH_ENVIRONMENTS`   | -                          | NO            | Space separated list of Key=Value pairs. **Note**: `@_@` gets replaced with a single whitespace, so you can expose environment values containing spaces |
| `LAUNCH_ENVFILES`       | -                          | NO            | Space separated list of Key=Value pairs. **Note**: These files *must* be present on the host where the container is started |

**Note**: Make sure you check out the [documentation](docs/).

## Resources

* GitLab: [gitlab.com/ix.ai/swarm-launcher](https://gitlab.com/ix.ai/swarm-launcher)
* GitHub: [github.com/ix-ai/swarm-launcher](https://github.com/ix-ai/swarm-launcher)
* GitHub Registry: `ghcr.io/ix-ai/swarm-launcher` - [ghcr.io/ix-ai/swarm-launcher](https://ghcr.io/ix-ai/swarm-launcher)
* Docker Hub: `ixdotai/swarm-launcher` - [hub.docker.com/r/ixdotai/swarm-launcher](https://hub.docker.com/r/ixdotai/swarm-launcher)

## Credits

This Docker image is inspired by the post by [@akomelj](https://github.com/akomelj) in [moby/moby#25885](https://github.com/moby/moby/issues/25885#issuecomment-573449645)
