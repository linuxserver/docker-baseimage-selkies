# Testing Patterns

## Test Strategy
There is **no unit test suite** in this repo — the product is a Docker image. QA = build success + runtime smoke + (upstream) CI web check.

## Local Smoke Test (per image variant)
1. **Build** completes without warnings on the target arch.
2. **Boot**: `docker run` → s6 chain reaches `init-selkies-end`; no service flapping (`docker logs`).
3. **Web**: `curl -sI :3000` → 200/301; `curl -skI :3001` → TLS with self-signed cert.
4. **X11 mode** (default): `xset q` works inside; openbox running; `autostart` app launches (`st` default).
5. **Wayland mode**: `-e PIXELFLUX_WAYLAND=true` → wayland socket appears; labwc running.
6. **Stream** (manual): open dashboard in browser, verify video+audio render; use `DASHBOARDS`/`TITLE`/`PASSWORD` envs to exercise config paths.
7. **DinD** (if in scope): `--privileged` run → `docker version` works inside.
8. **GPU** (if in scope): `--gpus all` + `DRI_NODE=/dev/dri/renderD128` → `vainfo` lists encoders; Zink path for NVIDIA in X11 mode.

## Upstream CI env vars (for reference / parity)
`jenkins-vars.yml:21-28`: `CI_WEB=true`, `CI_PORT=3001`, `CI_SSL=true`, `CI_DELAY=120`, `CI_WEB_SCREENSHOT_DELAY=30`, `CI_AUTH=''`, `CI_WEBPATH=''`, `CI_DOCKERENV='TZ=US/Pacific'`.

## RHEL9-specific watch items (updated by PLAN v4 vetting — see `tasks/2026-08/270827_rhel9-vetting-plan-v4.md`)
- locale availability (`glibc-langpack-*` vs Debian `localedef` flow)
- `apt-get`-only code paths in `svc-selkies/run` DEV_MODE (must not break default boot; gate or branch)
- openbox `rc.xml` sed targets (`Dockerfile:517-527`) if openbox comes from a different package layout
- python version difference (UBI9 python3.11 vs Debian 3.13) → selkies/pixelflux/pcmflux wheel compatibility
- Xvfb: `COPY --from=xvfb / /` trick is Debian-image-specific; RHEL9 uses stock dnf Xvfb → **no `-vfbdevice` support → `DISABLE_DRI3=true` mandatory** (D5); test `--device /dev/dri/renderD128` → Xvfb must stay up
- `dbus-launch` needs `dbus-x11` on EL9 (D2); smoke-test `dbus-daemon --system` running as abc
- v4 negative matrix: `--privileged` (svc-docker guard, no flapping) | `HARDEN_DESKTOP=true` (sudoers sed round-trip, xdg/exo chmod) | `PIXELFLUX_WAYLAND=true` (documented wait-forever, no labwc phase 1) | `LC_ALL=de_DE.UTF-8` | `DEV_MODE=pixelflux` gate message
- provenance: capture `dnf repoquery --installed --qf '%{name}|%{version}|%{reponame}'` into `package_versions_rhel9.txt` (RHEL vs EPEL evidence)

## Determinism
- Builds fetch "latest release" artifacts (pelorus, proot-apps, themes) — record resulting versions in the variant's `package_versions.txt` for reproducibility audits.
- Selkies commit is pinned (`348bc4f…`) — keep pinned for CI-reproducible builds.
