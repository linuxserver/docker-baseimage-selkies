# 280828_phase1-5-nrp-dev-push

## Objective
Phase 1.5 (dev scope): push the final RHEL9 GNOME selkies image to the user's dev registry (**Docker Hub `dgilli/selkies-rhel9`** — user decision 2026-08-28), verify the registry copy end-to-end, and deliver the NRP k8s deployment mapping for the LSIO-parity image. Resolves the open gates: F28 (rootful into NRP), F30 (registry/tag), F55 (docker seccomp/ptrace for future proot-apps R1).

## Outcome
- ✅ **Push**: `docker.io/dgilli/selkies-rhel9:latest` = manifest `sha256:462464663a88e8126a96764edccc878c78ef765008a3ccab9ad65300905117e5` (OCI; config digest = local c7 image `99da8c1475f5` — byte-identical source). *Registry current state: re-pushed same day with R1 c8 = manifest `sha256:b70d42e3…` (see `280828_r1-proot-apps.md`)*
- ✅ **Verify (registry round-trip)**: pull **by registry digest** (guaranteed network fetch — that digest was never in the local store) → identical image ID → cold-boot smoke on a **fresh volume**: http :3000 200 + https :3001 200 (abc:baseimage123) · **ws `/websocket` → HTTP 101 Switching Protocols** (same-origin selkies stream: nginx → internal :8082) · gnome-shell up · wallpaper gsettings applied on fresh volume (per-boot dconf re-apply confirmed) · SSL certs auto-generated in `/config/ssl` · TZ applied (overview clock 13:01 CDT @ 18:01 UTC) · desktop overview screenshot (SLU wallpaper workspace + app dash: firefox/gedit/terminal/grid)
- ✅ **NRP mapping**: `deploy/nrp-selkies-rhel9.yaml` (Deployment+Service+Ingress in NRP template shape — `nrp-workspace-*` labels, haproxy ingress) with full env-mapping table in header. Validated: strict YAML parse + structural cross-checks (svc→container ports, no securityContext per F28). (`kubectl apply --dry-run=client` not possible from this host — kubeconfig requires browser OAuth, no TTY.)
- ✅ **Gates closed**: F28 resolved (NRP templates carry no securityContext/runAsNonRoot — verified 2026-08-28), F30 dev-resolved (Docker Hub, `latest`, production tag ceremony deferred by user), F55 verified (stock docker default seccomp allows ptrace on kernel ≥4.8 cap-less — proot-apps R1 needs **no** seccomp override)

## Key Facts Established (for the NRP production merge)
- **Our selkies build (348bc4f) env surface** (verified in-image): `SELKIES_{ENCODER, MANUAL_WIDTH, MANUAL_HEIGHT, PORT, USE_CPU, AUTO_GPU, CURSOR_SIZE, MASTER_TOKEN, RENDER_DRI, CLOUDFLARE_TURN_*}`. NRP template's `SELKIES_VIDEO_BITRATE` / `SELKIES_FRAMERATE` / `SELKIES_AUDIO_BITRATE` / `SELKIES_ENABLE_RESIZE` / `SELKIES_ENABLE_BASIC_AUTH` / `BASIC_AUTH_*` / `SELKIES_TURN_REST_URI/PROTOCOL/TLS` target **their** selkies fork — **not applicable** to our image (encoder bitrate/framerate defaults apply; basic auth is nginx-side `USERNAME`/`PASSWORD`).
- **Single-port k8s fit**: nginx `location /websocket` (on both :3000 and :3001 servers) proxies to `127.0.0.1:$CUSTOM_WS_PORT` (default 8082) → expose **only 3000** (http; 3001 = https self-signed alternate) — NRP's one-port-per-workspace Ingress works with no template restructuring.
- **Rootful is fine** (F28): no securityContext in any NRP template; our s6 image runs as root with services dropping to `abc`.
- **OCI format** (F30): podman pushes OCI manifests to Docker Hub; local store digest ≠ registry manifest digest — pin by registry digest (recipe in `build-deployment.md`).
- **F55/docker seccomp**: ptrace allowed (moby/profiles main, minKernel 4.8, cap-less) → proot-apps (R1) viable under stock docker; unshare needs CAP_SYS_ADMIN but F54's bwrap stub removes the dependency.

## Files
- `deploy/nrp-selkies-rhel9.yaml` (new — NRP dev deployment + mapping table)
- `memory-bank/`: `findings.md` (F28/F30/F55 resolutions), `build-deployment.md` (push recipe + registry), this doc, `progress.md`, `tasks/2026-08/README.md`, `toc.md`, `activeContext.md`, `ops-log.jsonl`

## Artifacts
- Commits: code + MB (see `git log`, branch `rhel9`)
- Image: `docker.io/dgilli/selkies-rhel9:latest` (dev; production tag TBD)
- Verify container: `selkies-verify-pull` on :3100/:3101/:3182 (abc/baseimage123)
- Evidence: /tmp/opencode/{reg-manifest.json, verify-pull.png, docker-default-seccomp.json}

## Follow-ups (not this task)
- NRP production merge: apply mapping into NRP's `@@PLACEHOLDER@@` template system + `imagePullSecret` (Docker Hub repo is private by default) + their dnsPolicy block + `@@GPU_*@@` at phase 2
- R1 proot-apps (roadmap, deferred by user): now unblocked on the runtime side (F55) — image-side steps in `activeContext.md#Roadmap`
- Production tag scheme (F30): with the SLU registry decision
