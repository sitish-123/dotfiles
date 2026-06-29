#!/usr/bin/env bash
# Build + install the native AI sidebar (pkgs/ai-sidebar) into ~/.local/bin.
# A small Qt6 + QtWebEngine + LayerShellQt app: a real layer-shell sidebar (like the old
# Quickshell one) embedding the logged-in Gemini/ChatGPT/Claude web apps with a pill
# switcher. SUPER+A toggles it. Needs: qt6-webengine, layer-shell-qt, cmake, ninja.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

SRC="$DOT_ROOT/pkgs/ai-sidebar"
[ -d "$SRC" ] || { warn "ai-sidebar sources missing ($SRC)"; exit 0; }

# Bail early with one clear line if the toolchain/deps aren't there yet.
MISSING=()
for t in cmake ninja g++; do have "$t" || MISSING+=("$t"); done
pkg-config --exists Qt6WebEngineQuick 2>/dev/null || qmake6 -query QT_INSTALL_LIBS >/dev/null 2>&1 || MISSING+=("qt6")
[ -d /usr/lib/qt6/qml/org/kde/layershell ] || MISSING+=("layer-shell-qt")
if [ "${#MISSING[@]}" -gt 0 ]; then
    warn "AI sidebar build deps missing: ${MISSING[*]} — install them, then re-run ./install.sh"
    exit 0
fi

info "Building ai-sidebar (Qt6 + WebEngine + LayerShellQt)"
cmake -S "$SRC" -B "$SRC/build" -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null 2>&1 \
    && cmake --build "$SRC/build" >/dev/null 2>&1 \
    || { warn "ai-sidebar build failed — see: cmake -S $SRC -B $SRC/build && cmake --build $SRC/build"; exit 0; }

mkdir -p "$HOME/.local/bin"
install -m755 "$SRC/build/ai-sidebar" "$HOME/.local/bin/ai-sidebar" \
    && ok "ai-sidebar installed -> ~/.local/bin/ai-sidebar (SUPER+A toggles it)" \
    || warn "couldn't install ai-sidebar binary"
