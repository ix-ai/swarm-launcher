# swarm-launcher

[![Pipeline Status](https://gitlab.com/ix.ai/swarm-launcher/badges/master/pipeline.svg)](https://gitlab.com/ix.ai/swarm-launcher/)
[![Docker Stars](https://img.shields.io/docker/stars/ixdotai/swarm-launcher.svg)](https://hub.docker.com/r/ixdotai/swarm-launcher/)
[![Docker Pulls](https://img.shields.io/docker/pulls/ixdotai/swarm-launcher.svg)](https://hub.docker.com/r/ixdotai/swarm-launcher/)
[![Image Layers](https://images.microbadger.com/badges/image/ixdotai/swarm-launcher.svg)](https://hub.docker.com/r/ixdotai/swarm-launcher/)
[![Latest Version](https://images.microbadger.com/badges/version/ixdotai/swarm-launcher.svg)](https://hub.docker.com/r/ixdotai/swarm-launcher/)
[![Gitlab Project](https://img.shields.io/badge/GitLab-Project-554488.svg)](https://gitlab.com/ix.ai/swarm-launcher/)

A docker image to allow the launch of container in docker swarm, with options normally unavailable to swarm mode

## How it works

The image uses `docker-compose` to start a new project (see `LAUNCH_PROJECT_NAME`). You can either use the environment variables to configure the service started inside, or you can supply your own `/docker-compose.yml` file.

Either way, `swarm-launcher` takes care of the setup, tear-down and cleanup of the project.

## Docs and Usage examples

See [Docs](docs/) and [Usage Examples](docs/usage_examples)

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

**Note**: Make sure you check out the [documentation](docs/).

## Resources:
* GitLab: https://gitlab.com/ix.ai/swarm-launcher
* GitHub: https://github.com/ix-ai/swarm-launcher
* Docker Hub: https://hub.docker.com/r/ixdotai/swarm-launcher

## Credits
This Docker image is inspired by the post by [@akomelj](https://github.com/akomelj) in [moby/moby#25885](https://github.com/moby/moby/issues/25885#issuecomment-573449645)
