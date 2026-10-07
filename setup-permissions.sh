#!/usr/bin/env bash
#
# setup-permissions.sh - Configura permissões de acesso aos snapshots do Snapper
#
# Este script busca o nome da configuração do Snapper e concede autorização
# ao usuário utilizando o comando:
#   sudo snapper -c <config_name> set-config "ALLOW_USERS=<username>" "SYNC_ACL=yes"
#

set -euo pipefail

# Cores para formatação no terminal
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

show_help() {
    cat <<EOF
Uso: $0 [OPÇÕES] [NOME_DA_CONFIGURAÇÃO] [NOME_DO_USUÁRIO]

Script para conceder permissão de acesso aos snapshots do Snapper para usuários sem privilégios de root.

Opções:
  -n, --dry-run          Modo de teste: apenas exibe o que seria feito, sem aplicar alterações
  -h, --help             Exibe esta mensagem de ajuda

Parâmetros (opcionais):
  NOME_DA_CONFIGURAÇÃO   Nome da configuração do Snapper (ex: Snapshots, home, root)
  NOME_DO_USUÁRIO        Nome do usuário a autorizar (padrão: usuário atual)

Exemplos:
  $0
  $0 Snapshots
  $0 Snapshots rafael
  $0 --dry-run Snapshots

EOF
}

DRY_RUN=false
CHOSEN_CONFIG=""
TARGET_USER=""

for arg in "$@"; do
    case "$arg" in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--dry-run)
            DRY_RUN=true
            ;;
        *)
            if [[ -z "$CHOSEN_CONFIG" ]]; then
                CHOSEN_CONFIG="$arg"
            elif [[ -z "$TARGET_USER" ]]; then
                TARGET_USER="$arg"
            fi
            ;;
    esac
done

# 1. Verifica se o comando snapper está instalado
if ! command -v snapper &>/dev/null; then
    error "O utilitário 'snapper' não foi encontrado no sistema."
    echo "Certifique-se de que o Snapper esteja instalado (ex: dnf install snapper, zypper in snapper, etc.)."
    exit 1
fi

# 2. Identifica o usuário alvo
if [[ -z "$TARGET_USER" ]]; then
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        TARGET_USER="$SUDO_USER"
    else
        TARGET_USER="${USER:-$(id -un)}"
    fi
fi

if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
    read -r -p "Informe o nome de usuário (não-root) a autorizar: " TARGET_USER
    if [[ -z "$TARGET_USER" ]]; then
        error "Nome de usuário inválido."
        exit 1
    fi
fi

# Valida se o usuário existe no sistema
if ! id "$TARGET_USER" &>/dev/null; then
    error "O usuário '$TARGET_USER' não foi encontrado no sistema."
    exit 1
fi

info "Usuário alvo: ${BOLD}$TARGET_USER${NC}"

# 3. Descobre as configurações do Snapper disponíveis
CONFIG_NAMES=()
SUBVOLUMES=()

if snapper_configs=$(snapper --csv list-configs 2>/dev/null); then
    while IFS=, read -r cfg subv; do
        [[ "$cfg" == "config" ]] && continue
        [[ -z "$cfg" ]] && continue
        CONFIG_NAMES+=("$cfg")
        SUBVOLUMES+=("${subv:-desconhecido}")
    done <<< "$snapper_configs"
fi

# Fallback: ler do diretório /etc/snapper/configs caso snapper --csv não retorne
if [[ ${#CONFIG_NAMES[@]} -eq 0 ]] && [[ -d /etc/snapper/configs ]]; then
    for cfg_file in /etc/snapper/configs/*; do
        if [[ -f "$cfg_file" ]]; then
            cfg_name=$(basename "$cfg_file")
            subv_val=$(grep -E '^[[:space:]]*SUBVOLUME=' "$cfg_file" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "desconhecido")
            CONFIG_NAMES+=("$cfg_name")
            SUBVOLUMES+=("${subv_val:-desconhecido}")
        fi
    done
fi

if [[ ${#CONFIG_NAMES[@]} -eq 0 ]]; then
    error "Nenhuma configuração do Snapper encontrada."
    echo "Crie uma configuração primeiro com: sudo snapper -c <nome> create-config <subvolume>"
    exit 1
fi

# 4. Seleção da configuração
if [[ -n "$CHOSEN_CONFIG" ]]; then
    info "Configuração especificada: ${BOLD}$CHOSEN_CONFIG${NC}"
elif [[ ${#CONFIG_NAMES[@]} -eq 1 ]]; then
    CHOSEN_CONFIG="${CONFIG_NAMES[0]}"
    info "Configuração detectada automaticamente: ${BOLD}$CHOSEN_CONFIG${NC} (Subvolume: ${SUBVOLUMES[0]})"
else
    echo ""
    echo -e "${BOLD}Múltiplas configurações do Snapper encontradas:${NC}"
    for i in "${!CONFIG_NAMES[@]}"; do
        echo "  $((i+1))) ${CONFIG_NAMES[$i]} (Subvolume: ${SUBVOLUMES[$i]})"
    done
    echo ""
    read -r -p "Escolha o número da configuração desejada [1-${#CONFIG_NAMES[@]}]: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#CONFIG_NAMES[@]} )); then
        error "Opção inválida."
        exit 1
    fi
    CHOSEN_CONFIG="${CONFIG_NAMES[$((choice-1))]}"
fi

# 5. Obtém ALLOW_USERS e SYNC_ACL atuais
CURRENT_USERS=""
SYNC_ACL_VAL=""

if config_data=$(snapper -c "$CHOSEN_CONFIG" --csv get-config 2>/dev/null); then
    CURRENT_USERS=$(awk -F',' '$1=="ALLOW_USERS"{print $2}' <<< "$config_data")
    SYNC_ACL_VAL=$(awk -F',' '$1=="SYNC_ACL"{print $2}' <<< "$config_data")
elif [[ -f "/etc/snapper/configs/$CHOSEN_CONFIG" ]] && [[ -r "/etc/snapper/configs/$CHOSEN_CONFIG" ]]; then
    CURRENT_USERS=$(grep -E '^[[:space:]]*ALLOW_USERS=' "/etc/snapper/configs/$CHOSEN_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || true)
    SYNC_ACL_VAL=$(grep -E '^[[:space:]]*SYNC_ACL=' "/etc/snapper/configs/$CHOSEN_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || true)
fi

# Verifica se o usuário já está presente na lista
ALREADY_ALLOWED=false
for u in $CURRENT_USERS; do
    if [[ "$u" == "$TARGET_USER" ]]; then
        ALREADY_ALLOWED=true
        break
    fi
done

if $ALREADY_ALLOWED; then
    NEW_USERS="$CURRENT_USERS"
    info "O usuário '$TARGET_USER' já consta em ALLOW_USERS na configuração '$CHOSEN_CONFIG'."
else
    if [[ -n "$CURRENT_USERS" ]]; then
        NEW_USERS="$CURRENT_USERS $TARGET_USER"
    else
        NEW_USERS="$TARGET_USER"
    fi
fi

# 6. Preparação e execução do comando
CMD_PREFIX=""
if [[ $EUID -ne 0 ]]; then
    CMD_PREFIX="sudo "
fi

CMD="${CMD_PREFIX}snapper -c \"$CHOSEN_CONFIG\" set-config \"ALLOW_USERS=$NEW_USERS\" \"SYNC_ACL=yes\""

echo ""
info "Comando a ser executado:"
echo -e "  ${BOLD}$CMD${NC}"
echo ""

if $DRY_RUN; then
    info "Modo de simulação (--dry-run) ativo. Nenhuma alteração foi realizada."
    exit 0
fi

# Executa o comando
eval "$CMD"

success "Configuração '$CHOSEN_CONFIG' atualizada com sucesso!"
echo -e "  - ALLOW_USERS: ${BOLD}$NEW_USERS${NC}"
echo -e "  - SYNC_ACL:    ${BOLD}yes${NC}"
echo ""

# 7. Verificação
echo -e "${BOLD}Verificando permissões...${NC}"
if snapper -c "$CHOSEN_CONFIG" list &>/dev/null; then
    success "Acesso verificado! O usuário '$TARGET_USER' pode listar snapshots sem root."
else
    warn "Não foi possível verificar acesso direto sem root no momento."
    warn "Dica: Pode ser necessário recarregar a sessão ou verificar as ACLs de montagem do subvolume."
fi

echo ""
success "Permissões configuradas com sucesso para o snapper-view!"
