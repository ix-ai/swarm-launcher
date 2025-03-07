# Gluetun and Plex

Setting up [gluetun](https://github.com/qdm12/gluetun) can be achieved using the `LAUNCH_ARG_ENVFILE` variable.

## The stack.yaml file

Prerequisites:

* knowledge about how to:
  * create a docker config
  * create a docker secret
  * run a docker stack deployment
* create a docker config named `plex.docker-compose.yml` (see below)
* create a docker secret named `plex-gluetun.env` (see below)
* this stack will be called `gluetun-plex`

```yml
---
networks:
  ext-gluetun:
    attachable: true
configs:
  plex.docker-compose.yaml:
    external: true
secrets:
  plex-gluetun.env:
    external: true
services:
  gluetun-plex-launcher:
    configs:
      - mode: 0644
        source: plex.docker-compose.yaml
        target: /docker-compose.yml
    environment:
      LAUNCH_PROJECT_NAME: gluetun-plex
      LAUNCH_ARG_ENVFILE: /plex-gluetun.env
    image: ghcr.io/ix-ai/swarm-launcher:v0.21.3@sha256:5da4ca3b33481dd646841a1bbb354d072620d713a4d3015d1d54fc1767ecfef7
    secrets:
      - mode: 0600
        source: plex-gluetun.env
        target: /plex-gluetun.env
    stop_grace_period: 121s
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:rw
version: '3.9'

```

## The plex.docker-compose.yml file

```yml
---
networks:
  gluetun-plex_ext-gluetun:
    external: true
services:
  plex-gluetun:
    cap_add:
      - NET_ADMIN
    container_name: plex-gluetun
    hostname: plex-gluetun
    devices:
      - /dev/net/tun:/dev/net/tun
    environment:
      TZ: Europe/Berlin
      # See https://github.com/qdm12/gluetun-wiki/tree/main/setup#setup
      VPN_SERVICE_PROVIDER: custom
      VPN_TYPE: wireguard
      WIREGUARD_ADDRESSES: 192.168.0.2/32
      WIREGUARD_ALLOWED_IPS: 0.0.0.0/0
      WIREGUARD_ENDPOINT_IP: 999.999.999.999
      WIREGUARD_ENDPOINT_PORT: 51820
      WIREGUARD_PERSISTENT_KEEPALIVE_INTERVAL: 25s
      WIREGUARD_PRESHARED_KEY: ${GLUETUN_WIREGUARD_PRESHARED_KEY?err}
      WIREGUARD_PRIVATE_KEY: ${GLUETUN_WIREGUARD_PRIVATE_KEY?err}
      WIREGUARD_PUBLIC_KEY: ${GLUETUN_WIREGUARD_PUBLIC_KEY?err}
    image: ghcr.io/qdm12/gluetun:v3.40.0@sha256:2b42bfa046757145a5155acece417b65b4443c8033fb88661a8e9dcf7fda5a00
    networks:
      - gluetun-plex_ext-gluetun
    restart: 'no'
    volumes:
      - /path/to/my/gluetun/config:/gluetun
  plex:
    cap_add:
      - SYS_NICE
    container_name: plex
    environment:
      TZ: Europe/Berlin
      VERSION: latest
    depends_on:
      - plex-gluetun
    image: ghcr.io/linuxserver/plex:1.41.4@sha256:d4ea24c1f42d36f3c5ee485418a746be0440fe3c2b735c162c15d028f3495a6f
    network_mode: service:plex-gluetun
    restart: 'no'
    stop_grace_period: 121s
    ulimits:
      core: 0
      nofile: 60000
      nproc: 131072
      sigpending: 62793
    volumes:
      - /path/to/my/media:/my-media:rw
      - /path/to/my/plex/library:/config:rw
      - /etc/localtime:/etc/localtime:ro
```

## The plex-gluetun.env file

```txt
GLUETUN_WIREGUARD_PUBLIC_KEY='my_wireguard_public_key'
GLUETUN_WIREGUARD_PRIVATE_KEY='my_wireguard_private_key'
GLUETUN_WIREGUARD_PRESHARED_KEY='my_wireguard_preshared_key'
```
