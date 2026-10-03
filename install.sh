#!/usr/bin/env bash
# Devil May Cry 5 — Ultrawide fix (21:9 / 32:9) installer
# Drops REFramework + a ready-made config + a HUD script next to DevilMayCry5.exe
# and (on Steam/Linux) sets the launch option that lets Proton load it.
# https://github.com/sidnei-almeida/dmc5-ultrawide-fix
set -euo pipefail

EXE="DevilMayCry5.exe"
APPID="601150"
REPO="sidnei-almeida/dmc5-ultrawide-fix"
DLL_OVERRIDE='WINEDLLOVERRIDES="dinput8=n,b"'

DRY_RUN=0
UNINSTALL=0
NO_LAUNCH_OPTIONS=0
declare -a PATHS=()

usage() {
  cat <<USAGE
Usage: $0 [--path <game dir>]... [--uninstall] [--dry-run] [--no-launch-options]

  --path DIR            Game folder containing $EXE (can be given more than once).
                        Without it, Steam libraries and common launcher paths are searched.
  --uninstall           Remove the fix (REFramework files, config and scripts).
  --dry-run             Show what would be done without changing anything.
  --no-launch-options   Do not touch Steam's launch options for the game.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path) shift; [[ $# -gt 0 ]] || { usage; exit 2; }; PATHS+=("$1") ;;
    --uninstall) UNINSTALL=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --no-launch-options) NO_LAUNCH_OPTIONS=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

log()  { printf '  %s\n' "$*"; }
ok()   { printf '\033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*"; }
err()  { printf '\033[31m✘\033[0m %s\n' "$*" >&2; }

# --- payload (works from a clone or from `curl | bash`) --------------------

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
PAYLOAD=""
TMP=""
if [[ -n "$HERE" && -f "$HERE/payload/dinput8.dll" ]]; then
  PAYLOAD="$HERE/payload"
elif [[ $UNINSTALL -eq 0 ]]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  log "Downloading payload from GitHub ($REPO)…"
  curl -fsSL "https://github.com/$REPO/archive/refs/heads/main.tar.gz" | tar -xz -C "$TMP"
  PAYLOAD="$(find "$TMP" -maxdepth 2 -type d -name payload | head -1)"
  [[ -n "$PAYLOAD" && -f "$PAYLOAD/dinput8.dll" ]] || { err "Download failed."; exit 1; }
fi

# --- locate the game -------------------------------------------------------

steam_roots() {
  local r
  for r in \
    "$HOME/.local/share/Steam" \
    "$HOME/.steam/root" \
    "$HOME/.steam/steam" \
    "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam" \
    "$HOME/snap/steam/common/.local/share/Steam"; do
    [[ -d "$r/steamapps" ]] && readlink -f "$r"
  done | sort -u
}

steam_libraries() {
  local root vdf
  for root in $(steam_roots); do
    echo "$root"
    vdf="$root/steamapps/libraryfolders.vdf"
    [[ -f "$vdf" ]] || continue
    sed -nE 's/^[[:space:]]*"path"[[:space:]]+"([^"]+)".*$/\1/p' "$vdf" | sed 's#\\\\#/#g'
  done | sort -u
}

find_game() {
  local lib d
  for lib in $(steam_libraries); do
    d="$lib/steamapps/common/Devil May Cry 5"
    [[ -f "$d/$EXE" ]] && echo "$d"
  done
  # Heroic / Lutris / Bottles / manual installs: shallow search in common roots
  local root
  for root in "$HOME/Games" "$HOME/.local/share/lutris" "$HOME/.var/app/com.heroicgameslauncher.hgl" \
              "$HOME/.var/app/net.lutris.Lutris" "$HOME/.local/share/bottles" "$HOME/.var/app/com.usebottles.bottles"; do
    [[ -d "$root" ]] || continue
    find -L "$root" -maxdepth 6 -type f -name "$EXE" -printf '%h\n' 2>/dev/null || true
  done
}

canon() { while IFS= read -r p; do readlink -f -- "$p"; done; }

if [[ ${#PATHS[@]} -eq 0 ]]; then
  mapfile -t PATHS < <(find_game | canon | sort -u)
fi

if [[ ${#PATHS[@]} -eq 0 ]]; then
  err "Could not find $EXE. Pass the game folder explicitly:"
  log "$0 --path \"/path/to/steamapps/common/Devil May Cry 5\""
  exit 1
fi

# --- install / remove ------------------------------------------------------

FILES=(dinput8.dll reframework_revision.txt
       reframework/autorun/dmc5_uw_hud.lua
       reframework/autorun/uiscale.lua
       reframework/autorun/LICENSE-uiscale.txt
       reframework/data/dmc5_uw_hud.json
       reframework/data/uiscale.json)

merge_config() {
  # keep whatever the user already has in re2_fw_config.txt, override only our keys
  local cfg="$1/re2_fw_config.txt" key val
  touch "$cfg"
  while IFS='=' read -r key val; do
    [[ -z "$key" ]] && continue
    if grep -q "^${key}=" "$cfg"; then
      sed -i "s|^${key}=.*|${key}=${val}|" "$cfg"
    else
      printf '%s=%s\n' "$key" "$val" >> "$cfg"
    fi
  done < "$PAYLOAD/re2_fw_config.txt"
}

apply_fix() {
  local dir="$1" f
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[dry-run] would copy REFramework + scripts into $dir and merge re2_fw_config.txt"
    return
  fi
  if [[ -f "$dir/dinput8.dll" ]] && ! cmp -s "$dir/dinput8.dll" "$PAYLOAD/dinput8.dll"; then
    cp -p "$dir/dinput8.dll" "$dir/dinput8.dll.bak"
    warn "Existing dinput8.dll backed up as dinput8.dll.bak"
  fi
  for f in "${FILES[@]}"; do
    mkdir -p "$dir/$(dirname "$f")"
    case "$f" in
      reframework/data/*)  # user-tunable settings: never overwrite
        [[ -f "$dir/$f" ]] || cp "$PAYLOAD/$f" "$dir/$f" ;;
      *) cp "$PAYLOAD/$f" "$dir/$f" ;;
    esac
  done
  merge_config "$dir"
  ok "Installed into $dir"
}

remove_fix() {
  local dir="$1" f
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[dry-run] would remove REFramework files, scripts and config from $dir"
    return
  fi
  for f in "${FILES[@]}"; do rm -f "$dir/$f"; done
  rm -f "$dir/re2_fw_config.txt" "$dir/re2_framework_log.txt" "$dir/ref_ui.ini" \
        "$dir/reframework_accessed_files.txt" "$dir/reframework_loose_files.txt"
  rmdir "$dir/reframework/autorun" "$dir/reframework/data" "$dir/reframework/plugins" \
        "$dir/reframework/fonts" "$dir/reframework" 2>/dev/null || true
  if [[ -f "$dir/dinput8.dll.bak" ]]; then
    mv "$dir/dinput8.dll.bak" "$dir/dinput8.dll"
    ok "Restored previous dinput8.dll"
  fi
  ok "Removed from $dir"
}

# --- Steam launch options (Linux/Proton needs the DLL override) -------------

localconfigs() {
  local root
  for root in $(steam_roots); do
    find "$root/userdata" -mindepth 3 -maxdepth 3 -name localconfig.vdf 2>/dev/null
  done
}

patch_launch_options() {
  # Adds WINEDLLOVERRIDES="dinput8=n,b" to the game's launch options in every
  # Steam profile on this machine. Steam must be closed, otherwise it will
  # overwrite the file on exit.
  local vdf="$1"
  python3 - "$vdf" "$APPID" "$DLL_OVERRIDE" "$DRY_RUN" "$UNINSTALL" <<'PY'
import re, shutil, sys
path, appid, override, dry, uninstall = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1", sys.argv[5] == "1"
s = open(path, encoding="utf-8", errors="surrogateescape").read()
# the app block that holds LaunchOptions/LastPlayed lives under "apps"
m = None
for cand in re.finditer(r'"%s"\s*\{' % appid, s):
    depth, i = 0, cand.end() - 1
    while i < len(s):
        if s[i] == "{": depth += 1
        elif s[i] == "}":
            depth -= 1
            if depth == 0: break
        i += 1
    block = s[cand.start():i + 1]
    if "LaunchOptions" in block or "LastPlayed" in block or "Playtime" in block:
        m = (cand.start(), i + 1, block); break
if m is None:
    print("  app %s not found in %s (launch the game once from Steam first)" % (appid, path)); sys.exit(3)
start, end, block = m
lo = re.search(r'"LaunchOptions"\s*"((?:[^"\\]|\\.)*)"', block)
current = lo.group(1).replace('\\"', '"') if lo else ""
if uninstall:
    new = re.sub(r'\s*WINEDLLOVERRIDES="[^"]*dinput8[^"]*"', "", current).strip()
else:
    if re.search(r'WINEDLLOVERRIDES="[^"]*dinput8[^"]*"', current):
        print("  launch options already contain a dinput8 override: %s" % current); sys.exit(0)
    new = (override + " " + (current if "%command%" in current else (current + " %command%").strip())).strip()
if new == current:
    print("  nothing to change"); sys.exit(0)
if dry:
    print("  [dry-run] would set LaunchOptions to: %s" % new); sys.exit(0)
esc = new.replace('"', '\\"')
if lo:
    nb = block[:lo.start()] + '"LaunchOptions"\t\t"%s"' % esc + block[lo.end():]
else:
    indent = re.search(r'\n([ \t]*)"', block).group(1) if re.search(r'\n([ \t]*)"', block) else "\t"
    nb = block[:-1].rstrip() + '\n%s"LaunchOptions"\t\t"%s"\n%s}' % (indent, esc, indent[:-1])
shutil.copy2(path, path + ".dmc5uw.bak")
open(path, "w", encoding="utf-8", errors="surrogateescape").write(s[:start] + nb + s[end:])
print("  LaunchOptions set to: %s" % new)
PY
}

for dir in "${PATHS[@]}"; do
  if [[ ! -f "$dir/$EXE" ]]; then
    err "$EXE not found in: $dir"
    continue
  fi
  echo "Game found: $dir"
  if [[ $UNINSTALL -eq 1 ]]; then remove_fix "$dir"; else apply_fix "$dir"; fi
done

if [[ $NO_LAUNCH_OPTIONS -eq 0 ]]; then
  echo
  mapfile -t CFGS < <(localconfigs)
  if [[ ${#CFGS[@]} -eq 0 ]]; then
    warn "No Steam profile found; set the launch option by hand (see below)."
  elif pgrep -x steam >/dev/null 2>&1; then
    warn "Steam is running, so its config can't be edited safely."
    log "Either close Steam and run this script again, or set it by hand:"
    log "Steam > Devil May Cry 5 > Properties > Launch options:"
    log "    $DLL_OVERRIDE %command%"
  else
    for vdf in "${CFGS[@]}"; do
      log "Steam profile: $vdf"
      patch_launch_options "$vdf" || true
    done
  fi
fi

if [[ $UNINSTALL -eq 0 && $DRY_RUN -eq 0 ]]; then
  echo
  ok "Done. Start the game; re2_framework_log.txt appears in the game folder when REFramework loads."
  log "In game: Insert opens the REFramework menu (Graphics > Ultrawide/FOV Options)."
fi
