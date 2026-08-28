#!/usr/bin/env bash
# =============================================================================
# One-shot NRP cluster-side bootstrap + E2E smoke for the RHEL9 selkies
# desktop (GNOME + SLU wallpaper + proot-apps).
#
# Companion to deploy/nrp/selkies-rhel9.yaml.template (production artifact;
# memory-bank F57). Run from a machine with kubectl access to the NRP cluster
# and a local podman login to Docker Hub as `dgilli` — the docker-registry
# pull secret is built from the local container auth file (no token paste).
#
# Steps (idempotent):
#   1. resolve namespace  (-n, else kubeconfig context default, else 'default')
#   2. (re)create docker-registry secret `dockerhub-dgilli` from local auth
#   3. verify generic secret `selkies-password` (key `password`) exists
#   4. Pod Security Admission check: namespace enforce must NOT be
#      `restricted` or `baseline` (our desktop runs rootful with no
#      securityContext — F28; both modes reject such pods)
#   5. render the template (the standard NRP placeholder set — same sed
#      expressions the NRP renderer would apply) and kubectl apply
#   6. wait for the pod Ready, print URL + login + teardown command
#
# Usage:
#   ./apply-nrp-e2e.sh [--dry-run] [-n NS] [--name NAME] [--image IMG]
#                      [--domain D] [--dns1 IP] [--dns2 IP]
#                      [--cpu N] [--memory M]
#                      [--password-secret NAME] [--password-key K]
#
# Defaults: name=slu-rhel9-e2e  image=docker.io/dgilli/selkies-rhel9:v4-llvmpipe
#           domain=nrp-nautilus.io (ADJUST to the current NRP ingress domain)
#           dns=8.8.8.8/8.8.4.4  cpu=2  memory=4Gi  secrets per step 2/3
#
# Teardown:
#   kubectl -n <ns> delete -l app=<name>
# =============================================================================
set -euo pipefail

NS="" ; NAME="slu-rhel9-e2e"
IMAGE="docker.io/dgilli/selkies-rhel9:v4-llvmpipe"
DOMAIN="nrp-nautilus.io"
DNS1="8.8.8.8" ; DNS2="8.8.4.4"
CPU="2" ; MEMORY="4Gi"
PSECRET="selkies-password" ; PKEY="password"
DRY=0
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SELF/selkies-rhel9.yaml.template"
PULLSECRET="dockerhub-dgilli"
DOCKERUSER="dgilli"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace)      NS="$2"; shift 2;;
    --name)              NAME="$2"; shift 2;;
    --image)             IMAGE="$2"; shift 2;;
    --domain)            DOMAIN="$2"; shift 2;;
    --dns1)              DNS1="$2"; shift 2;;
    --dns2)              DNS2="$2"; shift 2;;
    --cpu)               CPU="$2"; shift 2;;
    --memory)            MEMORY="$2"; shift 2;;
    --password-secret)   PSECRET="$2"; shift 2;;
    --password-key)      PKEY="$2"; shift 2;;
    --dry-run)           DRY=1; shift;;
    -h|--help)           sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "unknown arg: $1 (try --help)" >&2; exit 2;;
  esac
done

log() { echo "[apply-nrp-e2e] $*"; }
die() { echo "[apply-nrp-e2e] ERROR: $*" >&2; exit 1; }
run() { if [[ $DRY -eq 1 ]]; then log "dry-run: $*"; else "$@"; fi; }

TMP_FILES=()
cleanup() { rm -f "${TMP_FILES[@]:-}"; }
trap cleanup EXIT

command -v kubectl  >/dev/null 2>&1 || die "kubectl not found"
command -v python3  >/dev/null 2>&1 || die "python3 not found"
[[ -f $TEMPLATE ]] || die "template not found: $TEMPLATE"

# --- 1. cluster + namespace -------------------------------------------------
# `version` is an authenticated API call that works even under the minimal
# NRP RBAC (cluster-info may 403 — it lists kube-system services)
kubectl version --request-timeout=10s >/dev/null 2>&1 \
  || die "cannot reach the cluster (check kube context / VPN)"
[[ -n $NS ]] || NS="$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null | head -n1 || true)"
[[ -n $NS ]] || NS="default"
log "namespace: $NS"

# --- 2. pull secret from local container auth --------------------------------
find_auth() {
  local f
  for f in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/containers/auth.json" \
           "$HOME/.config/containers/auth.json" \
           "$HOME/.docker/config.json"; do
    [[ -r $f ]] && { echo "$f"; return 0; }
  done
  return 1
}
AUTHFILE="$(find_auth || true)"
[[ -n ${AUTHFILE:-} ]] || die "no local container auth file found (podman login $DOCKERUSER?)"
log "local auth: $AUTHFILE"
CONFIG_JSON="$(python3 - "$AUTHFILE" "$DOCKERUSER" <<'PY'
import base64, json, sys
path, want = sys.argv[1], sys.argv[2]
data = json.load(open(path))
# podman/docker store the hub under varying keys depending on how the
# login happened — accept all aliases, normalize to the canonical one
HUB_KEYS = ("docker.io", "index.docker.io", "registry-1.docker.io",
            "https://index.docker.io/v1/", "https://registry-1.docker.io/v1/")
CANON = "https://index.docker.io/v1/"
for key in HUB_KEYS:
    entry = data.get("auths", {}).get(key)
    if not entry:
        continue
    cred = entry.get("auth")
    if cred:
        user, pw = base64.b64decode(cred).decode().split(":", 1)
    else:
        user, pw = entry.get("username", ""), entry.get("password", "")
    if not (user and pw):
        continue
    if user != want:
        sys.stderr.write(f"{key}: local user is {user!r}, expected {want!r}\n")
        continue
    norm = base64.b64encode(f"{user}:{pw}".encode()).decode()
    print(json.dumps({"auths": {CANON: {"username": user, "password": pw,
                                        "auth": norm}}}))
    sys.exit(0)
sys.exit(1)
PY
)" || die "no usable $DOCKERUSER docker.io credential in $AUTHFILE"
TMPJSON="$(mktemp)" ; TMP_FILES+=("$TMPJSON")
umask 077 ; printf '%s' "$CONFIG_JSON" > "$TMPJSON"

if kubectl -n "$NS" get secret "$PULLSECRET" >/dev/null 2>&1; then
  log "$PULLSECRET exists — replacing (fresh token)"
  run kubectl -n "$NS" delete secret "$PULLSECRET"
fi
run kubectl -n "$NS" create secret generic "$PULLSECRET" \
  --type=kubernetes.io/dockerconfigjson \
  --from-file=.dockerconfigjson="$TMPJSON"

# --- 3. password secret -------------------------------------------------------
if kubectl -n "$NS" get secret "$PSECRET" >/dev/null 2>&1; then
  log "password secret $PSECRET present (key: $PKEY)"
else
  die "password secret $PSECRET missing in ns $NS — create it, or pass -n / --password-secret"
fi

# --- 4. Pod Security Admission -------------------------------------------------
ENFORCE="$(kubectl -n "$NS" get ns "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || true)"
AUDIT="$(kubectl -n "$NS" get ns "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/audit}' 2>/dev/null || true)"
WARN="$(kubectl -n "$NS" get ns "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/warn}' 2>/dev/null || true)"
log "PSA labels: enforce=${ENFORCE:-<unset>} audit=${AUDIT:-<unset>} warn=${WARN:-<unset>}"
case "$ENFORCE" in
  restricted|baseline)
    die "namespace enforces PSA '$ENFORCE' — the desktop pod is rootful with no securityContext (F28); that mode rejects it. Use a namespace at 'privileged' (or unlabeled)."
    ;;
  privileged) log "PSA enforce=privileged — rootful pod allowed" ;;
  "")         log "no PSA enforce label — rootful pod allowed" ;;
  *)          log "PSA enforce='$ENFORCE' (unexpected mode; proceeding — kubectl apply will be the judge)" ;;
esac

# --- 5. render + apply ----------------------------------------------------------
RENDERED="$(mktemp)" ; [[ $DRY -eq 1 ]] || TMP_FILES+=("$RENDERED")
# (values must not contain the sed delimiter '|' — none of the defaults do)
sed -e "s|@@NAME@@|$NAME|g" \
    -e "s|@@IMAGE@@|$IMAGE|g" \
    -e "s|@@CPU@@|$CPU|g" \
    -e "s|@@MEMORY@@|$MEMORY|g" \
    -e "s|@@GPU_LIMITS@@||g" \
    -e "s|@@GPU_REQUESTS@@||g" \
    -e "s|@@PASSWORD_SECRET@@|$PSECRET|g" \
    -e "s|@@PASSWORD_KEY@@|$PKEY|g" \
    -e "s|@@DNS_PRIMARY@@|$DNS1|g" \
    -e "s|@@DNS_SECONDARY@@|$DNS2|g" \
    -e "s|@@INGRESS_DOMAIN@@|$DOMAIN|g" \
    -e "s|@@AFFINITY@@||g" \
    "$TEMPLATE" > "$RENDERED"
if grep -qE '@@[A-Z_]+@@' "$RENDERED"; then
  die "unrendered placeholders remain in manifest"
fi
log "rendered manifest: $RENDERED$([[ $DRY -eq 1 ]] && echo ' (kept for inspection — dry-run)')"
run kubectl -n "$NS" apply -f "$RENDERED"

# --- 6. wait + report -------------------------------------------------------------
if [[ $DRY -eq 0 ]]; then
  log "waiting for pod Ready (timeout 240s)…"
  kubectl -n "$NS" wait --for=condition=Ready pod -l "app=$NAME" --timeout=240s \
    || die "pod not Ready — inspect: kubectl -n $NS logs -l app=$NAME"
fi
cat <<EOF
[apply-nrp-e2e] E2E URL : https://$NAME.$DOMAIN
[apply-nrp-e2e] login   : abc  +  password = value of key '$PKEY' in secret '$PSECRET'
              (print: kubectl -n $NS get secret $PSECRET -o jsonpath='{.data.$PKEY}' | base64 -d)
[apply-nrp-e2e] verify  : GNOME desktop + SLU wallpaper, H.264 stream, dashboard
              'Install app' -> FileZilla (proot-apps, R1)
[apply-nrp-e2e] teardown: kubectl -n $NS delete -l app=$NAME
EOF
[[ $DRY -eq 1 ]] && log "dry-run complete — nothing was applied"
