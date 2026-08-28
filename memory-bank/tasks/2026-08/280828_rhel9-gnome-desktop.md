# 280828_rhel9-gnome-desktop

## Objective
Make **standard RHEL GNOME (gnome-shell 40.10)** — "the standard GNOME WM RHEL ships with" — the default X11 desktop streamed by the RHEL9 image (user: "get a GUI desktop working locally, not just a shell"). openbox remains available as fallback (`DESKTOP=openbox`) with the full LSIO autostart/`RESTART_APP` contract intact. No auto-launched apps on the GNOME desktop (user decision at approval: remove st + nautilus from autostart).

## Outcome
- ✅ Build: `dgilli/baseimage-selkies:rhel9-p1-gnome` = `f54738a5b9d4` (5 cycles; c4/c5 were small cached rebuilds, extensions flagged)
- ✅ Autonomous smoke: services 13/13 up · gnome-shell + deterministic session bus (`/tmp/runtime-abc/bus`) · GLX `llvmpipe (LLVM 21.1.7)` GL 4.5 · web 200 w/ abc:baseimage123 on :3000/:3001 · selkies ws :8082 · **screenshot-verified GNOME desktop** (top bar Activities/clock/indicators, app grid; clean desktop after auto-app removal)
- ✅ Edge matrix 4/4: `DESKTOP=openbox` (openbox+st boot, no gnome-shell, dbus-launch path) · `SELKIES_MANUAL_WIDTH/HEIGHT=1280x720` (Xvfb `-screen 0 1280x720x24`, gnome up) · `RESTART_APP=true` (watchdog idles silently — no autostart target under GNOME, no log spam, service up) · `HARDEN_DESKTOP=true` (sudo/xdg-open/**gnome-terminal** → 0000, CORRUPT_FILE sudoers, gnome-shell still up)
- ✅ User approval 2026-08-28 (desktop verified; auto-apps removed per request)
- ✅ Provenance: `package_versions_rhel9.txt` regenerated (24 epel / 414 rhel9 / 220 ubi9-base + 40 python)

## Files Modified
- `Dockerfile.rhel9` — +12 GNOME packages (all AppStream): gnome-shell 40.10, mutter, gnome-session, gnome-session-xsession, gnome-settings-daemon, nautilus 40.2, gnome-terminal, gedit, gnome-calculator, gnome-screenshot, firefox 140 ESR, glx-utils (F42/F43/F46/F47)
- `root/defaults/startwm.sh` — 5th distro-aware no-op branch: direct gnome-shell launch (F44 pattern), explicit session bus (F51), per-boot XDG_RUNTIME_DIR (F48), no auto-apps
- `root/etc/s6-overlay/s6-rc.d/init-selkies-config/run` — +6 lines: normalize `/config/.cache` ownership (F49)
- `package_versions_rhel9.txt` — regenerated from final image
- `memory-bank/` — findings F42–F51, ADR, this doc

## Patterns Applied
- **Distro-aware shared-tree no-op branching** (phase-1 pattern, 5th instance) — Debian/Fedora path untouched; branch gated on `[ -x /usr/bin/gnome-shell ] && [ "$DESKTOP" != "openbox" ]`
- **NRP production recipe reuse** (F44) — direct gnome-shell launch, llvmpipe trio (already ENV), xsetroot cosmetic, GLX-ready wait
- **Provenance via vanilla-ubi9 baseline diff + GPG key** (F40) — regenerated for the new image

## Integration Points
- `svc-xorg/run` — **unchanged**: Xvfb already enables every extension gnome-shell's X11 backend needs (F45)
- `svc-watchdog` — **unchanged**: RESTART_APP contract intact under openbox; under GNOME it idles in its initial wait loop (no target; harmless, verified)
- `init-selkies-config/run` — `.cache` normalization added (F49); its `TERMINAL_NAMES` list already includes `gnome-terminal` → `DISABLE_TERMINALS` hardening works under GNOME without change
- nautilus/gnome-terminal remain **installed** (app grid); only their auto-launch was removed

## Architectural Decisions
- **Direct gnome-shell, not gnome-session**: bypasses gnome-initial-setup welcome flow (not even in gnome-shell's dep tree — F43), keyring prompts, logind dependency, blanking/lock — ideal for a streamed desktop; NRP-proven in production (ADR in `decisions.md`)
- **Explicit `dbus-daemon --session --address=unix:path=$XDG_RUNTIME_DIR/bus`**: EL9's dbus-run-session drops a random `/tmp` socket sibling apps cannot discover (F51)
- **Per-boot `XDG_RUNTIME_DIR=/tmp/runtime-abc`**: `/config/.XDG` sits on the persistent VOLUME; a stale `bus` socket would break the session after container restart (F48)
- **Clean desktop**: no auto-launched st/nautilus (user decision 2026-08-28); apps via GNOME app grid
- nautilus 40 has no `-d` flag (removed in nautilus 3.x); NRP's exact `--no-desktop` was the correct auto-launch form (F50, superseded by the clean-desktop decision)

## Build Cycle Log
| Cycle | Image | Outcome |
|---|---|---|
| 1 | `3c31e79a` | clean build; smoke found nautilus missing (Dockerfile edit omission) + dbus-run-session random /tmp socket |
| 2 | `5394646a` | F49 cache chown + dbus export attempt (still dbus-run-session) |
| 3 | `a1ac52a0` | +`nautilus` pkg; explicit `dbus-daemon --address` (F51) |
| 4 | `15f963f8` | `nautilus --no-desktop` (F50; 1-line cached rebuild, extension flagged) |
| 5 | `f54738a5` | **final** — user-directed: remove auto-apps (st/nautilus) from GNOME branch |

## Artifacts
- Commit: `11a8afd` on `rhel9`; revert tag: `pre-gnome-desktop` → `b4c199f`
- Image: `dgilli/baseimage-selkies:rhel9-p1-gnome` (`f54738a5b9d4`)
- Live container: `selkies-rhel9-p1-gnome` :3000/:3001/:8082 (abc/baseimage123)
- Evidence screenshots: /tmp/opencode/gnome-boot.png (w/ auto-apps), gnome-clean.png (final)
