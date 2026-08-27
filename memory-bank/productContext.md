# Product Context

## Users
- **Primary**: SLU IT / downstream container builders who need a RHEL-9-based web-desktop base image (enterprise compliance, standardization on RHEL).
- **End consumers**: Anyone running a web-native Linux desktop in a browser via these base images.

## Upstream Relationship
- Source of truth for behavior: [`linuxserver/docker-baseimage-selkies`](https://github.com/linuxserver/docker-baseimage-selkies).
- This repo tracks upstream `master` / `debiantrixie` release tag (see `jenkins-vars.yml:7`).
- Support from upstream is "Reasonable Endeavours" only (README). SLU owns the RHEL9 delta.

## Market / Why RHEL9
- SLU workloads standardize on RHEL. A Debian-only base image blocks reuse.
- RHEL9 brings `dnf`/`rpm` packaging, different package availability, and glibc/locale handling that must be reconciled with the desktop stack (Xorg, Wayland/labwc, pulseaudio, GPU/VA-API, NVIDIA).

## Out of Scope (unless requested)
- Changing Selkies/pixelflux upstream behavior.
- Introducing a `latest` tag.
- Replacing the s6-overlay service model.

## Open Product Questions (for RHEL9)
1. Target tag name: `rhel9`? Also an aarch64 variant?
2. RHEL9 base: `registry.access.redhat.com/ubi9` (U9/UBI) vs full RHEL repo access? (license/registry availability)
3. Parity level: full feature parity with Debian image, or a reduced core set first?
