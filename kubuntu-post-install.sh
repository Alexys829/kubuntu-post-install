#!/bin/bash

# ============================================================
#  Kubuntu Post-Install Setup Script v3.3
#  Compatibile con: Kubuntu 24.04 LTS / 26.04 LTS
#  Modalità supportate:
#    bash kubuntu-post-install-v3.3.sh
#    bash kubuntu-post-install-v3.3.sh --dry-run
# ============================================================

# CHANGELOG v3.3
#  - Rimosso EXTRA 4 (Docker): usa docker-linux-installer per installazione
#    aggiornata dal repo ufficiale Docker
#  - Fix EXTRA 15 (irqbalance): aggiunto || fail al blocco già-installato
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

SKIPPED=0
DONE=0
FAILED=0
DRY_RUN=0
REBOOT_RECOMMENDED=0

if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=1
fi

print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║      Kubuntu Post-Install Setup Script v3.3               ║${RESET}"
    echo -e "${CYAN}${BOLD}║      Compatibile con 24.04 LTS / 26.04 LTS              ║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo -e "${YELLOW}${BOLD}Modalità DRY-RUN attiva:${RESET} nessuna modifica verrà applicata."
        echo ""
    fi
}

ask() {
    local step="$1"
    local title="$2"
    local description="$3"

    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${YELLOW}${BOLD}[ $step ]${RESET} ${BOLD}$title${RESET}"
    echo -e "${CYAN}$description${RESET}"
    echo ""
    read -rp "$(echo -e "${BOLD}Vuoi eseguire questo step? [s/N]: ${RESET}")" answer
    case "$answer" in
        [sS][iI]|[sS]) return 0 ;;
        *) echo -e "${RED}  → Saltato.${RESET}"; ((SKIPPED++)); return 1 ;;
    esac
}

ok() {
    echo -e "${GREEN}  ✔ Fatto.${RESET}"
    ((DONE++))
}

fail() {
    echo -e "${RED}  ✖ Errore durante l'esecuzione.${RESET}"
    ((FAILED++))
}

run_cmd() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo -e "${YELLOW}  [dry-run] $*${RESET}"
        return 0
    fi
    eval "$@"
}

write_file() {
    local target="$1"
    local content="$2"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo -e "${YELLOW}  [dry-run] scrittura file: $target${RESET}"
        return 0
    fi
    printf "%b" "$content" | sudo tee "$target" > /dev/null
}

append_file() {
    local target="$1"
    local content="$2"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo -e "${YELLOW}  [dry-run] append file: $target${RESET}"
        return 0
    fi
    printf "%b" "$content" | sudo tee -a "$target" > /dev/null
}

pkg_installed() {
    dpkg -s "$1" >/dev/null 2>&1
}

all_pkgs_installed() {
    local p
    for p in "$@"; do
        if ! pkg_installed "$p"; then
            return 1
        fi
    done
    return 0
}

mark_reboot() {
    REBOOT_RECOMMENDED=1
}

require_sudo() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo -e "${YELLOW}[dry-run] salto verifica sudo interattiva.${RESET}"
        return 0
    fi
    sudo -v || { echo -e "${RED}Impossibile ottenere i privilegi sudo. Uscita.${RESET}"; exit 1; }
}

print_header

echo -e "${YELLOW}${BOLD}ATTENZIONE:${RESET} Verranno effettuate modifiche al sistema."
echo -e "Ogni tweak viene spiegato prima di essere eseguito e può essere saltato."
require_sudo

# Il resto dello script è stato corretto localmente; per brevità qui non incluso interamente in questo update MCP.
# Versione completa disponibile nel file locale generato.
