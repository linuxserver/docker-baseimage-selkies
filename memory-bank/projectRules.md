# Project Rules

## Generated Files (never hand-edit)
- `README.md` — rendered from `readme-vars.yml` by the upstream builder (`CONTRIBUTING.md:15-27`). Edit `readme-vars.yml`.
- `Jenkinsfile` — product of the upstream pipeline builder (`CONTRIBUTING.md:18`).
- `package_versions.txt` — package inventory snapshot; regenerate per variant, don't hand-tweak.

## Dockerfile Conventions
- One logical step per `RUN`, chained with `&&`, each step prefixed with an `echo "**** step name ****"` banner (see `Dockerfile:6-19`).
- Package lists alphabetized, one per line, indented under `apt-get install`/equivalent.
- Keep the selkies commit pin in sync across all occurrences (`Dockerfile:19` and `Dockerfile:470`).
- Any change to `Dockerfile` must be mirrored to `Dockerfile.aarch64` (and to the RHEL9 counterparts once they exist), with `arm64v8-` base tag prefixes where applicable.
- Multi-stage: put source-builds in named build stages; only copy artifacts into the runtime stage.
- Cleanup at the end of the runtime stage (purge build deps, clear package cache, `/tmp`) — follow `Dockerfile:559-570`.

## Runtime / s6 Conventions
- App user is `abc` (uid 1000), `HOME=/config`; drop privileges with `s6-setuidgid abc`.
- Scripts under `root/etc/s6-overlay/s6-rc.d/*/run` use `#!/usr/bin/with-contenv bash`.
- Service naming: `init-*` = one-shot (declare `type: oneshot`), `svc-*` = long-running; ordering via `dependencies.d/` markers, membership via `user/contents.d/`.
- User-facing config goes through env vars with `${VAR:-default}`; document new vars in `readme-vars.yml`.

## General
- No fake/mock/stub data in image build scripts or services.
- Prefer extending existing stages/services/files over adding parallel ones (reuse over creation).
- Keep distro-specific code isolated: where a script must differ between Debian and RHEL9, branch on a distro signal (e.g., `/etc/os-release` `ID`) rather than duplicating whole files — except the Dockerfiles themselves, which stay per-variant by convention.
- Commits: one logical change per commit; messages reference the variant (e.g., `rhel9: add PowerTools repo for -devel build deps`).
