#!/usr/bin/env bash
# Remove o fix. Uso: ./uninstall.sh [/caminho/para/Devil May Cry 5]
set -euo pipefail
GAME_DIR="${1:-$HOME/.local/share/Steam/steamapps/common/Devil May Cry 5}"
[ -f "$GAME_DIR/DevilMayCry5.exe" ] || { echo "Pasta do jogo invalida: $GAME_DIR"; exit 1; }
rm -f "$GAME_DIR/dinput8.dll" "$GAME_DIR/reframework_revision.txt" "$GAME_DIR/re2_fw_config.txt" "$GAME_DIR/re2_framework_log.txt"
rm -rf "$GAME_DIR/reframework"
[ -f "$GAME_DIR/dinput8.dll.bak" ] && mv "$GAME_DIR/dinput8.dll.bak" "$GAME_DIR/dinput8.dll"
echo "Removido."
