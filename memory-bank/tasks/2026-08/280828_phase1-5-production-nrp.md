# 280828_phase1-5-production-nrp

## Objective
Phase 1.5 production half: make the RHEL9 selkies image (GNOME + SLU wallpaper + proot-apps, c8) deployable on the **current** NRP cluster. Per user decisions (2026-08-28): tag = "cleanest" → `v4-llvmpipe` (the name the earlier-attempt config already references); repo stays **private** (imagePullSecret); `/config` **ephemeral** (emptyDir); **no edits to NRP-side repos** — `slu-nrp-k8s-vm/` is the earlier attempt, reference only; the production artifact lives in OUR repo.

## Outcome
- ✅ **Image pinned**: `docker.io/dgilli/selkies-rhel9:v4-llvmpipe` = c8 `5c835fb6a147` (manifest `sha256:b70d42e30c7bef93ca7f0a4bd6a46540d4dfd2eabff1eafadd1d82fbdec5d059`, identical to `:latest` — dev tracks it); repo private
- ✅ **Production template**: `deploy/nrp/selkies-rhel9.yaml.template` (commit `525f38d`) — drop-in NRP placeholder template (Deployment+Service+Ingress, `nrp-workspace-*` labels, haproxy ingress, auto-TLS host `@@NAME@@.@@INGRESS_DOMAIN@@`) using **only the standard 19-expression sed set** from the reference renderer; verified by replicating that exact render + YAML parse + structural cross-check (**ALL PASS**)
- ✅ **Mismatches fixed vs the reference template** (F57): ports 8080→**3000** (Service targetPort; ws same-origin via nginx `/websocket`, no 8082 exposure) · auth `PASSWD`/`BASIC_AUTH_*`→**`USERNAME: abc` + `PASSWORD` secretRef** (missing PASSWORD = no-auth UI on our image) · encoder **deliberately not templated** (reference config's `vp8enc` is rejected by our selkies 348bc4f — verified `WARNING: Invalid value(s) 'vp8enc'…`; H.264 streams via the pixelflux wheel; system gstreamer x264enc absent & unneeded, vp8enc plugin present but not in the allowed set) · volumes `+/config` `+/dev/shm` emptyDirs, `−/cache` `−/home/rheluser` (foreign) · `imagePullSecrets: dockerhub-dgilli` hardcoded (private repo; their sed set has no such placeholder) · no securityContext (F28) · Guaranteed QoS `@@CPU@@/@@MEMORY@@` (limits==requests) · `@@GPU_*@@` kept for phase 2
- ⏳ **Cluster-side E2E (needs NRP kube access — user/NRP ops)**: create pull secret · ensure `selkies-password` secret · namespace PSA label check (F28 residual — `restricted` blocks root) · swap the template into the current NRP tooling · run one workspace → browser `abc` + secret → desktop + wallpaper + H.264 stream + dashboard **Install app → FileZilla** (R1)

## Key Decisions (full ADR in `decisions.md`)
- **Our repo owns the NRP template** (not the NRP-side repos) — single source of truth travels with the image; renderer-compatible by construction (standard placeholder set only)
- **Encoder immune by omission** — no `@@ENCODER@@` in our template, so any config value (vp8enc/x264enc/…) is irrelevant; our baked pixelflux H.264 path applies
- **Known divergence documented**: reference config's 30fps/4Mbps cap is unenforceable via env on our selkies build (client-side settings only); reference tooling's "Username: rheluser" console line is cosmetic (ours is `abc`)

## Files
- `deploy/nrp/selkies-rhel9.yaml.template` (new — production artifact)
- `deploy/nrp-selkies-rhel9.yaml` (header note: standalone dev manifest; production artifact = the template)
- `memory-bank/`: F57, F30 → fully resolved, ADR (template drop-in), this doc, progress/README/toc/activeContext/ops-log
- Reference (NOT modified): `/home/its_admin/projects/slu-nrp-k8s-vm/{nrp-workspace,workspace-config.conf,selkies-rhel9.yaml.template,validate.sh}` — earlier attempt

## Artifacts
- Commit: `525f38d` on `rhel9` (+ MB commit)
- Image: `docker.io/dgilli/selkies-rhel9:v4-llvmpipe` = c8 (private)
- Verify render: /tmp/opencode/rendered-test.yaml + cross-check output

## NRP-side checklist (for the E2E, from cluster access)
1. `kubectl -n <ns> create secret docker-registry dockerhub-dgilli --docker-server=https://index.docker.io/v1/ --docker-username=dgilli --docker-password=<token>`
2. `kubectl -n <ns> get secret selkies-password` (exists? create: `--from-literal=password=…`)
3. `kubectl -n <ns> get ns <ns> -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'` → must NOT be `restricted` (F28)
4. Install `deploy/nrp/selkies-rhel9.yaml.template` as the rhel9 desktop template in the current NRP tooling
5. Create a test workspace (name e.g. `slu-rhel9-e2e`, image `docker.io/dgilli/selkies-rhel9:v4-llvmpipe`, 2 CPU/4Gi) → `https://slu-rhel9-e2e.<ingress-domain>` → login `abc`/secret → verify desktop + SLU wallpaper + H.264 + FileZilla install via dashboard
