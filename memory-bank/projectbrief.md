# Project Brief

**Project**: `slu-docker-rhel-selkies`
**Lineage**: SLU (Saint Louis University) fork of [`linuxserver/docker-baseimage-selkies`](https://github.com/linuxserver/docker-baseimage-selkies) (upstream `master`, release tag `debiantrixie`).

## Vision
Provide full-featured **web-native Linux desktop** container base images. Applications run inside a container and are streamed to a browser via [Selkies](https://github.com/selkies-project) (video: pixelflux, audio: pcmflux, served by NGINX with basic auth). These base images are the foundation for downstream app containers.

## What This Fork Does
- Starts from the upstream Debian-trixie-based image (current state, see baseline commit `eb4e145`).
- **Goal: add RHEL 9 as a supported base image** so downstream SLU workloads can run on an enterprise RHEL-based stream, not only Debian.

## Key Constraints (inherited from upstream)
- No `latest` tag by design — every image is versioned by distro/stream.
- `/config` is the only default-persisted mount; everything else is ephemeral.
- Ships passwordless sudo (user `abc`) for customization.
- `README.md` and `Jenkinsfile` are **generated** — never hand-edit (see `projectRules.md`).

## Success (for RHEL9 work)
A `:rhel9` (or equivalent tag) image that boots the same desktop stack (X11 + Wayland modes), passes the same smoke test as the Debian image, and is built through the same CI/deploy flow.
