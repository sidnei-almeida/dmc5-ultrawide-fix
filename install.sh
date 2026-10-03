#!/usr/bin/env bash
# Instala o fix ultrawide (REFramework + config) na pasta do Devil May Cry 5.
# Uso: ./install.sh [/caminho/para/Devil May Cry 5]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD="$HERE/payload"

find_game_dir() {
    local candidates=(
        "$HOME/.local/share/Steam/steamapps/common/Devil May Cry 5"
        "$HOME/.steam/steam/steamapps/common/Devil May Cry 5"
        "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/Devil May Cry 5"
    )
    local libs
    if [ -f "$HOME/.local/share/Steam/steamapps/libraryfolders.vdf" ]; then
        libs=$(grep -oP '"path"\s+"\K[^"]+' "$HOME/.local/share/Steam/steamapps/libraryfolders.vdf" || true)
        for l in $libs; do candidates+=("$l/steamapps/common/Devil May Cry 5"); done
    fi
    for c in "${candidates[@]}"; do
        if [ -f "$c/DevilMayCry5.exe" ]; then echo "$c"; return 0; fi
    done
    return 1
}

GAME_DIR="${1:-}"
if [ -z "$GAME_DIR" ]; then
    GAME_DIR="$(find_game_dir)" || { echo "Nao achei a pasta do jogo. Passe o caminho como argumento."; exit 1; }
fi
[ -f "$GAME_DIR/DevilMayCry5.exe" ] || { echo "DevilMayCry5.exe nao encontrado em: $GAME_DIR"; exit 1; }

echo "Pasta do jogo: $GAME_DIR"

if [ -f "$GAME_DIR/dinput8.dll" ]; then
    cp -f "$GAME_DIR/dinput8.dll" "$GAME_DIR/dinput8.dll.bak"
    echo "Backup do dinput8.dll existente -> dinput8.dll.bak"
fi

cp -f "$PAYLOAD/dinput8.dll" "$GAME_DIR/"
cp -f "$PAYLOAD/reframework_revision.txt" "$GAME_DIR/"
mkdir -p "$GAME_DIR/reframework/autorun"
cp -f "$PAYLOAD/reframework/autorun/uiscale.lua" "$GAME_DIR/reframework/autorun/"
cp -f "$PAYLOAD/reframework/autorun/LICENSE-uiscale.txt" "$GAME_DIR/reframework/autorun/"
if [ -f "$PAYLOAD/reframework/data/uiscale.json" ]; then
    mkdir -p "$GAME_DIR/reframework/data"
    cp -n "$PAYLOAD/reframework/data/uiscale.json" "$GAME_DIR/reframework/data/" 2>/dev/null || true
fi

# Mescla a config: mantem o que ja existe e sobrescreve so as chaves do fix.
CFG="$GAME_DIR/re2_fw_config.txt"
touch "$CFG"
while IFS='=' read -r key val; do
    [ -z "$key" ] && continue
    if grep -q "^${key}=" "$CFG"; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$CFG"
    else
        echo "${key}=${val}" >> "$CFG"
    fi
done < "$PAYLOAD/re2_fw_config.txt"

echo
echo "Instalado. Agora, no Steam:"
echo "  Devil May Cry 5 > Propriedades > Opcoes de inicializacao:"
echo '  WINEDLLOVERRIDES="dinput8=n,b" %command%'
echo
echo "No Windows nao precisa de nada alem de copiar os arquivos."
