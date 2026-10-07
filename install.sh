#!/usr/bin/env bash
#
# install.sh - Instala o snapper-view e o menu de serviço do KDE Dolphin
#

set -euo pipefail

# Cores para formatação
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN=''
    BLUE=''
    YELLOW=''
    RED=''
    BOLD=''
    NC=''
fi

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[AVISO]${NC} $*"; }
error() { echo -e "${RED}[ERRO]${NC} $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
MENU_DIR="$HOME/.local/share/kio/servicemenus"

echo -e "${BOLD}=== Instalação do snapper-view para KDE Dolphin ===${NC}\n"

# 1. Verifica dependências essenciais
MISSING_DEPS=()
for dep in kdialog dolphin snapper; do
    if ! command -v "$dep" &>/dev/null; then
        MISSING_DEPS+=("$dep")
    fi
done

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    warn "As seguintes ferramentas recomendadas não foram encontradas no sistema: ${MISSING_DEPS[*]}"
    warn "Certifique-se de instalá-las para o pleno funcionamento do Dolphin e do snapper-view."
    echo ""
fi

# 2. Cria diretórios de destino
info "Criando diretórios de destino (se não existirem)..."
mkdir -p "$BIN_DIR"
mkdir -p "$MENU_DIR"

# 3. Copia o executável snapper-view
info "Instalando 'snapper-view' em '$BIN_DIR'..."
if [[ -f "$SCRIPT_DIR/snapper-view" ]]; then
    cp -f "$SCRIPT_DIR/snapper-view" "$BIN_DIR/snapper-view"
    chmod +x "$BIN_DIR/snapper-view"
    success "Arquivo '$BIN_DIR/snapper-view' instalado com permissão de execução."
else
    error "Arquivo fonte '$SCRIPT_DIR/snapper-view' não encontrado."
    exit 1
fi

# 4. Copia o arquivo .desktop do Service Menu
info "Instalando 'snapper-history.desktop' em '$MENU_DIR'..."
if [[ -f "$SCRIPT_DIR/snapper-history.desktop" ]]; then
    cp -f "$SCRIPT_DIR/snapper-history.desktop" "$MENU_DIR/snapper-history.desktop"
    success "Arquivo '$MENU_DIR/snapper-history.desktop' instalado."
else
    error "Arquivo fonte '$SCRIPT_DIR/snapper-history.desktop' não encontrado."
    exit 1
fi

echo ""
success "Arquivos instalados com sucesso!"
echo ""

# 5. Oferece configurar permissões do Snapper
if [[ -f "$SCRIPT_DIR/setup-permissions.sh" ]]; then
    echo -e "${BOLD}Permissões do Snapper:${NC}"
    echo "Para que o usuário comum possa ler os snapshots na pasta .snapshots,"
    echo "é necessário configurar o Snapper (ALLOW_USERS e SYNC_ACL)."
    echo ""
    read -r -p "Deseja executar o assistente de permissões agora? [S/n] " answer
    answer="${answer:-s}"
    if [[ "$answer" =~ ^[sSyY]$ ]]; then
        echo ""
        bash "$SCRIPT_DIR/setup-permissions.sh"
    else
        info "Você pode configurar as permissões mais tarde executando:"
        echo -e "  ${BOLD}./setup-permissions.sh${NC}"
    fi
fi

echo ""
echo -e "${GREEN}${BOLD}Pronto!${NC} No Dolphin, clique com o botão direito em um arquivo ou pasta e selecione:"
echo -e "  ${BOLD}\"Ver versões nos Snapshots...\"${NC}"
