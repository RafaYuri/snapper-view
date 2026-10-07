#!/usr/bin/env bash
#
# uninstall.sh - Desinstala o snapper-view do sistema do usuário
#

set -euo pipefail

# Cores
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    RED='\033[0;31m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN=''
    BLUE=''
    RED=''
    BOLD=''
    NC=''
fi

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }

BIN_TARGET="$HOME/.local/bin/snapper-view"
DESKTOP_TARGET="$HOME/.local/share/kio/servicemenus/snapper-history.desktop"

echo -e "${BOLD}=== Desinstalação do snapper-view ===${NC}\n"

if [[ -f "$BIN_TARGET" ]]; then
    rm -f "$BIN_TARGET"
    success "Removido: $BIN_TARGET"
else
    info "Não encontrado: $BIN_TARGET"
fi

if [[ -f "$DESKTOP_TARGET" ]]; then
    rm -f "$DESKTOP_TARGET"
    success "Removido: $DESKTOP_TARGET"
else
    info "Não encontrado: $DESKTOP_TARGET"
fi

echo ""
success "Desinstalação concluída!"
