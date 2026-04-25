#!/bin/bash
set -euo pipefail

# ============================================================
#  Kubuntu Post-Install Setup Script v3.3
#  Compatibile con: Kubuntu 24.04 LTS / 26.04 LTS
#  Modalità supportate:
#    bash kubuntu-post-install-v3.3.sh
#    bash kubuntu-post-install-v3.3.sh --dry-run
# ============================================================
# CHANGELOG
# v3.3 (2026-04-18)
#   - Rimosso EXTRA 4 (Docker via APT): Docker va installato con
#     il dedicato install_docker.sh dal repo ufficiale
#   - Fix EXTRA 15 (irqbalance): aggiunto || fail al blocco già-installato
#     per propagare correttamente gli errori al contatore FAILED
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

if [[ "${1:-}" == "--dry-run" ]]; then
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
    log_action "SUCCESS" "$*"
}

fail() {
    echo -e "${RED}  ✖ Errore durante l'esecuzione.${RESET}"
    ((FAILED++))
    log_action "FAILED" "$*"
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

pkg_available() {
    apt-cache show "$1" >/dev/null 2>&1
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

log_action() {
    local action="$1"
    local details="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $action: $details" | sudo tee -a /var/log/kubuntu-post-install.log > /dev/null 2>&1 || true
}

validate_input() {
    local input="$1"
    local name="$2"
    local pattern="^[a-zA-Z0-9_-]+$"
    if [[ ! "$input" =~ $pattern ]]; then
        echo -e "${RED}  ✖ Input '$name' non valido: $input${RESET}"
        return 1
    fi
    return 0
}

validate_device() {
    local dev="$1"
    if [[ ! -b "$dev" ]]; then
        echo -e "${RED}  ✖ Dispositivo non valido: $dev${RESET}"
        return 1
    fi
    return 0
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

# ── STEP 1 ───────────────────────────────────────────────────
if ask "STEP 1" "Correggi /etc/fstab per SSD (rimuovi 'discard')" \
"Su filesystem ext4, Kubuntu può usare l'opzione 'discard' in /etc/fstab,
ma in genere è preferibile usare il timer periodico fstrim.timer.
Questo step crea un backup di /etc/fstab e sostituisce 'discard' con
'defaults,noatime' per ridurre scritture inutili su SSD."; then
    if grep -E '^[^#]*[[:space:]]ext4[[:space:]]' /etc/fstab >/dev/null 2>&1; then
        if grep -E '^[^#]*[[:space:]]ext4[[:space:]]' /etc/fstab | grep -q discard; then
            run_cmd "sudo cp /etc/fstab /etc/fstab.orig" && \
            run_cmd "sudo sed -i '/[[:space:]]ext4[[:space:]]/ s/discard/defaults,noatime/' /etc/fstab" && {
                ok; mark_reboot;
            } || fail
        else
            echo -e "${YELLOW}  → Nessuna opzione 'discard' trovata sulle righe ext4. Niente da modificare.${RESET}"
            ((SKIPPED++))
        fi
    else
        echo -e "${YELLOW}  → Nessuna riga ext4 trovata in /etc/fstab. Saltato.${RESET}"
        ((SKIPPED++))
    fi
fi

# ── STEP 2 ───────────────────────────────────────────────────
if ask "STEP 2" "Riduci swappiness (da 60 a 10)" \
"Su desktop, ridurre la swappiness aiuta a usare la RAM più a lungo e
posticipa l'uso dello swap. Questo rende il sistema più reattivo."; then
    write_file "/etc/sysctl.d/99-sysswappiness.conf" "# Reduce swappiness for desktop installation (default = 60)\nvm.swappiness=10\n# Riduce la percentuale di cache sporca prima di scrivere su disco\nvm.dirty_ratio=10\nvm.dirty_background_ratio=5\n" && {
        ok; mark_reboot;
    } || fail
fi

# ── STEP 3 ───────────────────────────────────────────────────
if ask "STEP 3" "Riduci i timeout di systemd (da 90s a 15s)" \
"Riduce il tempo di attesa durante logout, spegnimento e riavvio se alcuni
servizi non si chiudono correttamente. Utile su desktop per evitare blocchi
lunghi e inutili."; then
    run_cmd "sudo mkdir -p /etc/systemd/system.conf.d /etc/systemd/user.conf.d" && \
    write_file "/etc/systemd/system.conf.d/99-systemtimeout.conf" "# Reduce timeout (default = 90s)\n\n[Manager]\nDefaultTimeoutStopSec=15s\n" && \
    write_file "/etc/systemd/user.conf.d/99-usertimeout.conf" "# Reduce timeout (default = 90s)\n\n[Manager]\nDefaultTimeoutStopSec=15s\n" && {
        ok; mark_reboot;
    } || fail
fi

# ── STEP 4 ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${YELLOW}${BOLD}[ STEP 4 ]${RESET} ${BOLD}Configura il menu GRUB${RESET}"
echo -e "${CYAN}Rende visibile il menu GRUB all'avvio per accedere più facilmente a
recovery mode o altri sistemi operativi in dual boot.${RESET}"
echo ""
echo -e "  ${BOLD}[1]${RESET} Single-boot → menu visibile per 1 secondo"
echo -e "  ${BOLD}[2]${RESET} Multi-boot  → menu visibile per 5 secondi + os-prober"
echo -e "  ${BOLD}[0]${RESET} Salta"
read -rp "$(echo -e "${BOLD}Scelta [1/2/0]: ${RESET}")" grub_choice
case "$grub_choice" in
    1)
        run_cmd "sudo cp /etc/default/grub /etc/default/grub.orig" && \
        run_cmd "sudo sed -i 's/^GRUB_TIMEOUT_STYLE=hidden/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub" && \
        run_cmd "sudo sed -i 's/^GRUB_TIMEOUT=0/GRUB_TIMEOUT=1/' /etc/default/grub" && \
        run_cmd "sudo update-grub 2>/dev/null" && { ok; mark_reboot; } || fail
        ;;
    2)
        run_cmd "sudo cp /etc/default/grub /etc/default/grub.orig" && \
        run_cmd "sudo sed -i 's/^GRUB_TIMEOUT_STYLE=hidden/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub" && \
        run_cmd "sudo sed -i 's/^GRUB_TIMEOUT=0/GRUB_TIMEOUT=5/' /etc/default/grub" && \
        run_cmd "sudo sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub" && \
        run_cmd "sudo update-grub 2>/dev/null" && { ok; mark_reboot; } || fail
        ;;
    *)
        echo -e "${RED}  → Saltato.${RESET}"; ((SKIPPED++)) ;;
esac

# ── STEP 5 ───────────────────────────────────────────────────
if ask "STEP 5" "Aggiorna il sistema" \
"Aggiorna pacchetti Snap e APT, poi rimuove pacchetti orfani e pulisce la cache."; then
    if command -v snap >/dev/null 2>&1; then
        run_cmd "sudo snap refresh" || true
    fi
    run_cmd "sudo systemctl daemon-reload" && \
    run_cmd "sudo apt update && sudo apt full-upgrade -y" && \
    run_cmd "sudo apt autopurge -y && sudo apt autoclean" && ok || fail
fi

# ── STEP 6 ───────────────────────────────────────────────────
if ask "STEP 6" "Installa codec, font Microsoft compatibili e supporto exFAT" \
"Installa componenti fondamentali spesso mancanti in una fresh install:
codec multimediali, font compatibili con documenti Office, supporto RAR,
accelerazione video e strumenti per chiavette/dischi exFAT."; then
    if all_pkgs_installed kubuntu-restricted-extras gstreamer1.0-vaapi libvdpau-va-gl1 rar fonts-crosextra-carlito fonts-crosextra-caladea exfatprogs; then
        echo -e "${YELLOW}  → Pacchetti già installati. Saltato.${RESET}"
        ((SKIPPED++))
    else
        run_cmd "sudo apt update && sudo apt install -y kubuntu-restricted-extras gstreamer1.0-vaapi libvdpau-va-gl1 rar fonts-crosextra-carlito fonts-crosextra-caladea exfatprogs" && ok || fail
    fi
fi

# ── STEP 7 ───────────────────────────────────────────────────
if ask "STEP 7" "Installa supporto DVD/Blu-ray (opzionale)" \
"Installa libdvd-pkg per abilitare la riproduzione dei DVD commerciali.
Da fare solo se hai un lettore ottico fisico."; then
    if all_pkgs_installed libdvd-pkg; then
        echo -e "${YELLOW}  → libdvd-pkg già installato.${RESET}"
        ((SKIPPED++))
    else
        run_cmd "sudo apt update && sudo apt install -y libdvd-pkg" && \
        run_cmd "sudo dpkg-reconfigure libdvd-pkg" && ok || fail
    fi
fi

# ── BONUS A ──────────────────────────────────────────────────
if ask "BONUS A" "Rimuovi Snap dal sistema" \
"Rimuove snapd e blocca la sua reinstallazione automatica. Utile se vuoi
usare solo pacchetti APT/Flatpak. Attenzione: app snap come Firefox e
Thunderbird andranno reinstallate in altro formato."; then
    run_cmd "sudo snap remove --purge \\$(snap list 2>/dev/null | awk 'NR>1 {print \\$1}') 2>/dev/null || true" && \
    run_cmd "sudo apt purge -y snapd" && \
    run_cmd "sudo apt-mark hold snapd" && \
    run_cmd "sudo rm -rf ~/snap /snap /var/snap /var/lib/snapd" && \
    write_file "/etc/apt/preferences.d/nosnap.pref" "Package: snapd\nPin: release a=*\nPin-Priority: -10\n" && ok || fail
fi

# ── BONUS B ──────────────────────────────────────────────────
if ask "BONUS B" "Abilita Flatpak + Flathub" \
"Installa Flatpak e l'integrazione con Discover, aggiungendo anche Flathub
come repository principale di app desktop."; then
    if all_pkgs_installed flatpak plasma-discover-backend-flatpak; then
        echo -e "${YELLOW}  → Flatpak e backend Discover già installati.${RESET}"
        ((SKIPPED++))
    else
        run_cmd "sudo apt install -y flatpak plasma-discover-backend-flatpak" && \
        run_cmd "flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo" && ok || fail
    fi
fi

# ── BONUS C ──────────────────────────────────────────────────
if ask "BONUS C" "Mostra asterischi durante l'inserimento password sudo" \
"Abilita pwfeedback in sudo per mostrare un feedback visivo durante la
digitazione della password in terminale."; then
    write_file "/etc/sudoers.d/pwfeedback" "# Enable password feedback\nDefaults pwfeedback\n" && \
    run_cmd "sudo chmod 0440 /etc/sudoers.d/pwfeedback" && ok || fail
fi

# ── BONUS D ──────────────────────────────────────────────────
if ask "BONUS D" "Disabilita il cambio utente rapido" \
"Blocca il fast user switching in KDE. Utile in ambienti condivisi o per
ridurre l'apertura di sessioni parallele."; then
    # Path system-wide standard valido sia per Plasma 5 (KF5) sia per Plasma 6 (KF6)
    KDEGLOBALS_TARGET="/etc/xdg/kdeglobals"
    run_cmd "sudo mkdir -p /etc/xdg" && \
    append_file "$KDEGLOBALS_TARGET" "\n[KDE Action Restrictions][\$i]\naction/switch_user=false\naction/start_new_session=false\n" && {
        ok; mark_reboot;
    } || fail
fi

# ── EXTRA 1 ──────────────────────────────────────────────────
if ask "EXTRA 1" "Installa driver GPU proprietari" \
"Installa automaticamente i driver raccomandati per GPU supportate,
in particolare NVIDIA. Utile per accelerazione video e migliori performance."; then
    if ! command -v ubuntu-drivers >/dev/null 2>&1; then
        run_cmd "sudo apt install -y ubuntu-drivers-common" || fail
    fi
    run_cmd "sudo ubuntu-drivers install" && {
        ok; mark_reboot;
    } || fail
fi

# ── EXTRA 2 ──────────────────────────────────────────────────
if ask "EXTRA 2" "Abilita firewall UFW" \
"Configura UFW in modo basilare: blocca connessioni in entrata non richieste
e consente quelle in uscita. Ideale per un desktop."; then
    if ! pkg_installed ufw; then
        run_cmd "sudo apt install -y ufw" || { fail; }
    fi
    run_cmd "sudo ufw default deny incoming" && \
    run_cmd "sudo ufw default allow outgoing" && \
    run_cmd "sudo ufw --force enable" && ok || fail
fi

# ── EXTRA 3 ──────────────────────────────────────────────────
if ask "EXTRA 3" "Installa Timeshift" \
"Installa Timeshift per creare snapshot di sistema e facilitare il recovery
dopo aggiornamenti o modifiche problematiche."; then
    if pkg_installed timeshift; then
        echo -e "${YELLOW}  → Timeshift già installato.${RESET}"
        ((SKIPPED++))
    else
        run_cmd "sudo apt install -y timeshift" && ok || fail
    fi
fi

# ── EXTRA 5 ──────────────────────────────────────────────────
if ask "EXTRA 5" "Installa strumenti sviluppo base" \
"Installa git, curl, wget, build-essential e python3-pip: strumenti di base
per sviluppo, build e automazione."; then
    if all_pkgs_installed git curl wget build-essential python3-pip; then
        echo -e "${YELLOW}  → Strumenti base già installati.${RESET}"
        ((SKIPPED++))
    else
        run_cmd "sudo apt install -y git curl wget build-essential python3-pip" && ok || fail
    fi
fi

# ── EXTRA 6 ──────────────────────────────────────────────────
if ask "EXTRA 6" "Installa KVM/QEMU" \
"Installa lo stack base per virtualizzazione con KVM/QEMU, libvirt e
virt-manager. Aggiunge anche il tuo utente ai gruppi kvm e libvirt."; then
    cpu_support=$(grep -Ec '(vmx|svm)' /proc/cpuinfo 2>/dev/null || echo "0")
    if [[ "$cpu_support" -eq 0 ]]; then
        echo -e "${YELLOW}  ⚠ Virtualizzazione hardware non rilevata o disabilitata nel BIOS/UEFI.${RESET}"
        read -rp "$(echo -e "${BOLD}  Vuoi continuare comunque? [s/N]: ${RESET}")" force_kvm
        [[ "$force_kvm" =~ ^[sS]([iI])?$ ]] || { echo -e "${RED}  → Saltato.${RESET}"; ((SKIPPED++)); false; }
    fi
    if all_pkgs_installed qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager cpu-checker; then
        echo -e "${YELLOW}  → Stack KVM/QEMU già installato.${RESET}"
        ((SKIPPED++))
    else
        run_cmd "sudo apt update && sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager cpu-checker" && \
        run_cmd "sudo systemctl enable --now libvirtd" && \
        run_cmd "sudo usermod -aG kvm \"$USER\"" && \
        run_cmd "sudo usermod -aG libvirt \"$USER\"" && {
            ok; mark_reboot;
            echo -e "${YELLOW}  ⚠ Fai logout e login per applicare i gruppi 'kvm' e 'libvirt'.${RESET}"
            if [[ "$DRY_RUN" -eq 0 ]]; then
                kvm-ok 2>/dev/null || true
            fi
        } || fail
    fi
fi

# ── EXTRA 7 ──────────────────────────────────────────────────
if ask "EXTRA 7" "Installa OVMF/UEFI per VM moderne" \
"Installa il firmware UEFI per VM, utile per Windows 11, GPT, Secure Boot
e scenari di passthrough o VM moderne."; then
    if pkg_installed ovmf; then
        echo -e "${YELLOW}  → OVMF già installato.${RESET}"
        ((SKIPPED++))
    else
        run_cmd "sudo apt install -y ovmf" && ok || fail
    fi
fi

# ── EXTRA 8 ──────────────────────────────────────────────────
if ask "EXTRA 8" "Installa supporto SPICE" \
"Aggiunge strumenti SPICE per una migliore esperienza grafica nelle VM:
clipboard condivisa, resize automatico, migliore integrazione host/guest."; then
    if all_pkgs_installed virt-viewer spice-client-gtk qemu-utils; then
        echo -e "${YELLOW}  → Supporto SPICE già installato.${RESET}"
        ((SKIPPED++))
    else
        run_cmd "sudo apt install -y virt-viewer spice-client-gtk qemu-utils" && {
            ok
            echo -e "${CYAN}  → Dentro la VM installa 'spice-vdagent' per clipboard e resize.${RESET}"
        } || fail
    fi
fi

# ── EXTRA 9 ──────────────────────────────────────────────────
if ask "EXTRA 9" "Configura bridge di rete per VM" \
"Configura un bridge br0 via Netplan per dare alle VM un IP diretto sulla
LAN. Utile per server, test di rete o accesso diretto da altri dispositivi.
Non eseguire questo step in SSH remoto."; then
    echo -e "${CYAN}  → Interfacce di rete disponibili:${RESET}"
    ip -o link show | awk -F': ' '{print "    " $2}' | grep -v lo
    read -rp "$(echo -e "${BOLD}  Inserisci il nome dell'interfaccia fisica: ${RESET}")" NET_IFACE
    if [[ -z "$NET_IFACE" ]]; then
        echo -e "${RED}  → Nessuna interfaccia inserita. Saltato.${RESET}"
        ((SKIPPED++))
    elif ! validate_input "$NET_IFACE" "interfaccia"; then
        ((SKIPPED++))
    else
        if ! pkg_installed bridge-utils; then
            run_cmd "sudo apt install -y bridge-utils" || fail
        fi
        NETPLAN_CONTENT="network:\n  version: 2\n  renderer: networkd\n  ethernets:\n    ${NET_IFACE}:\n      dhcp4: false\n  bridges:\n    br0:\n      interfaces: [${NET_IFACE}]\n      dhcp4: true\n      parameters:\n        stp: false\n        forward-delay: 0\n"
        write_file "/etc/netplan/99-kvm-bridge.yaml" "$NETPLAN_CONTENT" && \
        run_cmd "sudo chmod 600 /etc/netplan/99-kvm-bridge.yaml" || fail
        echo -e "${YELLOW}  ⚠ Verifica /etc/netplan/99-kvm-bridge.yaml prima di applicare.${RESET}"
        read -rp "$(echo -e "${BOLD}  Applicare subito con netplan apply? [s/N]: ${RESET}")" apply_netplan
        if [[ "$apply_netplan" =~ ^[sS]([iI])?$ ]]; then
            run_cmd "sudo netplan apply" && {
                ok; mark_reboot;
                echo -e "${CYAN}  → In virt-manager seleziona il bridge 'br0'.${RESET}"
            } || fail
        else
            echo -e "${YELLOW}  → File scritto ma non applicato. Applica manualmente con: sudo netplan apply${RESET}"
            ((DONE++))
        fi
    fi
fi

# ── EXTRA 10 ─────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${YELLOW}${BOLD}[ EXTRA 10 ]${RESET} ${BOLD}Preset KVM aggiuntivi${RESET}"
echo -e "${CYAN}[1] Desktop  → pacchetti desktop-oriented per integrazione migliore
[2] Developer → cloud image, guestfs, tooling per VM veloci e immagini qcow2
[3] Server    → Cockpit + cockpit-machines per gestione VM via browser
[0] Salta${RESET}"
read -rp "$(echo -e "${BOLD}Scelta [1/2/3/0]: ${RESET}")" preset_choice
case "$preset_choice" in
    1)
        if all_pkgs_installed adwaita-qt adwaita-icon-theme-full; then
            echo -e "${YELLOW}  → Preset Desktop già presente.${RESET}"
            ((SKIPPED++))
        else
            run_cmd "sudo apt install -y adwaita-qt adwaita-icon-theme-full" && ok || fail
        fi
        ;;
    2)
        if all_pkgs_installed cloud-image-utils libguestfs-tools guestfs-tools; then
            echo -e "${YELLOW}  → Preset Developer già presente.${RESET}"
            ((SKIPPED++))
        else
            run_cmd "sudo apt install -y cloud-image-utils libguestfs-tools guestfs-tools" && ok || fail
        fi
        ;;
    3)
        if all_pkgs_installed cockpit cockpit-machines; then
            echo -e "${YELLOW}  → Preset Server già presente.${RESET}"
            ((SKIPPED++))
        else
            run_cmd "sudo apt install -y cockpit cockpit-machines" && \
            run_cmd "sudo systemctl enable --now cockpit.socket" && ok || fail
        fi
        ;;
    *)
        echo -e "${RED}  → Saltato.${RESET}"
        ((SKIPPED++))
        ;;
esac


# ── EXTRA 11: TLP (ottimizzazione batteria laptop) ───────────

if ask "EXTRA 11" "Installa TLP per ottimizzare la batteria (solo laptop)" \
"TLP è il tool di power management più diffuso su Linux. Funziona in modo
automatico: rileva se il laptop è su corrente o batteria e applica profili
diversi senza intervento manuale. Cosa ottimizza:
  • Frequenza CPU in modalità batteria
  • Risparmio energetico Wi-Fi, USB e PCI Express
  • Accesso a disco/SSD
  • Soglie di ricarica personalizzabili (es. ricarica tra 70-90%)
Stima: 30-40% di autonomia in più rispetto al default.
Viene installato anche tlp-rdw (radio device wizard: gestisce Wi-Fi/BT
automaticamente in sospensione) e tlpui (GUI grafica opzionale).
Da installare SOLO su laptop. Su desktop è inutile."; then

    run_cmd "sudo apt install -y tlp tlp-rdw" && \
    run_cmd "sudo systemctl enable --now tlp" && {
        ok
        echo -e "${CYAN}  → TLP attivo. Configurazione in /etc/tlp.conf${RESET}"
        echo -e "${CYAN}  → Stato: sudo tlp-stat -s${RESET}"
        echo -e "${CYAN}  → GUI (opzionale): sudo apt install tlpui${RESET}"
        echo ""
        read -rp "$(echo -e "${BOLD}  Installare anche tlpui (interfaccia grafica)? [s/N]: ${RESET}")" install_tlpui
        if [[ "$install_tlpui" =~ ^[sS]([iI])?$ ]]; then
            run_cmd "sudo apt install -y tlpui" && echo -e "${GREEN}  ✔ tlpui installato.${RESET}"
        fi
    } || fail
fi

# ── EXTRA 12: powertop (analisi consumi hardware) ────────────

if ask "EXTRA 12" "Installa powertop (diagnosi consumi energetici)" \
"powertop è un tool Intel che analizza in tempo reale i consumi hardware
del sistema e suggerisce ottimizzazioni. Complementare a TLP.
  • Mostra quali processi/dispositivi consumano di più
  • Suggerisce parametri di risparmio energetico
  • Può applicare automaticamente le ottimizzazioni con --auto-tune
Utile principalmente su laptop ma informativo anche su desktop."; then

    if pkg_installed powertop; then
        echo -e "${YELLOW}  → powertop già installato.${RESET}"; ((SKIPPED++))
    else
        run_cmd "sudo apt install -y powertop" && {
            ok
            echo -e "${CYAN}  → Avvia analisi: sudo powertop${RESET}"
            echo -e "${CYAN}  → Applica ottimizzazioni: sudo powertop --auto-tune${RESET}"
        } || fail
    fi
fi

# ── EXTRA 13: thermald (gestione termica Intel) ──────────────

if ask "EXTRA 13" "Installa thermald (gestione termica CPU Intel)" \
"thermald è un daemon sviluppato da Intel che monitora la temperatura
della CPU e applica throttling software prima che l'hardware lo forzi.
  • Riduce surriscaldamento su CPU Intel
  • Funziona in background senza configurazione
  • Compatibile con DPTF (Dynamic Platform and Thermal Framework)
Consigliato su laptop Intel. Su AMD o desktop il beneficio è marginale."; then

    if pkg_installed thermald; then
        echo -e "${YELLOW}  → thermald già installato.${RESET}"; ((SKIPPED++))
    else
        run_cmd "sudo apt install -y thermald" && \
        run_cmd "sudo systemctl enable --now thermald" && ok || fail
    fi
fi

# ── EXTRA 14: earlyoom (protezione OOM proattiva) ────────────

if ask "EXTRA 14" "Installa earlyoom (protezione da esaurimento RAM)" \
"Il kernel Linux ha un OOM killer integrato, ma interviene troppo tardi:
il sistema si blocca completamente per secondi/minuti prima di agire.
earlyoom monitora l'uso di RAM e swap e termina i processi più 'pesanti'
in modo proattivo, prima che il sistema si congeli.
  • Utile se esegui VM, browser con tante tab o build pesanti
  • Il sistema rimane sempre responsivo
  • Configurabile: soglie, priorità, processi esclusi"; then

    if pkg_installed earlyoom; then
        echo -e "${YELLOW}  → earlyoom già installato.${RESET}"; ((SKIPPED++))
    else
        run_cmd "sudo apt install -y earlyoom" && \
        run_cmd "sudo systemctl enable --now earlyoom" && {
            ok
            echo -e "${CYAN}  → Stato: systemctl status earlyoom${RESET}"
            echo -e "${CYAN}  → Configurazione: /etc/default/earlyoom${RESET}"
        } || fail
    fi
fi

# ── EXTRA 15: irqbalance (distribuzione interrupt su multi-core)

if ask "EXTRA 15" "Installa irqbalance (ottimizzazione interrupt CPU)" \
"irqbalance distribuisce automaticamente gli interrupt hardware (I/O, rete,
disco) tra tutti i core disponibili della CPU. Senza di esso, tutti gli
interrupt finiscono sul core 0, creando un collo di bottiglia.
  • Migliora le performance su CPU multi-core
  • Riduce latenza I/O e di rete
  • Già incluso in alcune distro ma non sempre attivo"; then

    if pkg_installed irqbalance; then
        run_cmd "sudo systemctl enable --now irqbalance" && {
            echo -e "${YELLOW}  → irqbalance già installato, servizio abilitato.${RESET}"
            ((DONE++))
        } || fail
    else
        run_cmd "sudo apt install -y irqbalance" && \
        run_cmd "sudo systemctl enable --now irqbalance" && ok || fail
    fi
fi

# ── EXTRA 16: haveged (entropia di sistema) ──────────────────

if ask "EXTRA 16" "Installa haveged (generatore di entropia)" \
"Il kernel mantiene un pool di entropia usato per operazioni crittografiche
(generazione chiavi, SSL, SSH, LUKS, ecc.). Su sistemi desktop con poco
I/O il pool può svuotarsi, causando blocchi o rallentamenti al boot.
haveged risolve il problema generando entropia continuamente.
  • Accelera operazioni crittografiche
  • Riduce i tempi di boot su alcuni sistemi
  • Molto utile se usi Docker, SSH, GPG o LUKS"; then

    if pkg_installed haveged; then
        echo -e "${YELLOW}  → haveged già installato.${RESET}"; ((SKIPPED++))
    else
        run_cmd "sudo apt install -y haveged" && \
        run_cmd "sudo systemctl enable --now haveged" && ok || fail
    fi
fi



# ── EXTRA 17: zRAM ───────────────────────────────────────────

if ask "EXTRA 17" "Installa zRAM (swap compresso in RAM)" \
"zRAM crea un dispositivo di swap compresso direttamente in RAM invece
di usare il disco. Quando la RAM si riempie, i dati vengono compressi
e tenuti in memoria invece di essere scritti su disco/SSD.
  • Riduce drasticamente la latenza rispetto allo swap su disco
  • Compressione tipica: 2:1 → 4 GB RAM extra da 2 GB fisici
  • Ideale con VM e Docker attivi contemporaneamente
  • Consuma qualche ciclo CPU per la compressione (trascurabile)
Il pacchetto 'zram-config' configura zRAM automaticamente all'avvio."; then

    if pkg_installed zram-config || pkg_installed zram-tools; then
        echo -e "${YELLOW}  → zRAM già installato.${RESET}"; ((SKIPPED++))
    else
        # Su 26.04 zram-config potrebbe non essere disponibile: fallback su zram-tools
        if pkg_available zram-config; then
            ZRAM_PKG="zram-config"
        elif pkg_available zram-tools; then
            ZRAM_PKG="zram-tools"
        else
            echo -e "${RED}  ✖ Nessun pacchetto zRAM disponibile nei repository.${RESET}"
            fail
            ZRAM_PKG=""
        fi
        if [[ -n "$ZRAM_PKG" ]]; then
            run_cmd "sudo apt install -y $ZRAM_PKG" && {
                ok; mark_reboot;
                echo -e "${CYAN}  → Pacchetto installato: $ZRAM_PKG${RESET}"
                echo -e "${CYAN}  → Verifica dopo riavvio: zramctl${RESET}"
                if [[ "$ZRAM_PKG" == "zram-tools" ]]; then
                    echo -e "${CYAN}  → Configurazione: /etc/default/zramswap${RESET}"
                fi
            } || fail
        fi
    fi
fi

# ── EXTRA 18: Preload ─────────────────────────────────────────

if ask "EXTRA 18" "Installa preload (avvio app più veloce)" \
"preload analizza le app che usi più frequentemente e le precarica in RAM
in anticipo, riducendo i tempi di avvio.
  • Apprende le tue abitudini d'uso nel tempo
  • Efficace principalmente su macchine con 8+ GB di RAM
  • Funziona in background senza configurazione manuale"; then

    if pkg_installed preload; then
        echo -e "${YELLOW}  → preload già installato.${RESET}"; ((SKIPPED++))
    elif ! pkg_available preload; then
        echo -e "${YELLOW}  → 'preload' non è disponibile nei repository di questa release.${RESET}"
        echo -e "${YELLOW}    Pacchetto non più mantenuto: su kernel recenti il guadagno è trascurabile. Saltato.${RESET}"
        ((SKIPPED++))
    else
        run_cmd "sudo apt install -y preload" && \
        run_cmd "sudo systemctl enable --now preload" && ok || fail
    fi
fi

# ── EXTRA 19: TCP BBR ─────────────────────────────────────────

if ask "EXTRA 19" "Abilita TCP BBR (ottimizzazione algoritmo rete)" \
"BBR (Bottleneck Bandwidth and RTT) è l'algoritmo di controllo della
congestione TCP sviluppato da Google. Sostituisce il default 'cubic'.
  • Migliora throughput e latenza su connessioni ad alta velocità
  • Particolarmente utile su connessioni con perdita di pacchetti
  • Ideale per sviluppo web, API, containerizzazione, trasferimenti
  • Abilitato tramite due parametri sysctl (nessun pacchetto aggiuntivo)
Verificabile dopo riavvio con: sysctl net.ipv4.tcp_congestion_control"; then

    write_file "/etc/sysctl.d/99-tcp-bbr.conf" \
"# Abilita TCP BBR come algoritmo di controllo congestione\nnet.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\n" && {
        ok; mark_reboot;
        echo -e "${CYAN}  → Verifica dopo riavvio: sysctl net.ipv4.tcp_congestion_control${RESET}"
    } || fail
fi

# ── EXTRA 20: inotify watches ─────────────────────────────────

if ask "EXTRA 20" "Aumenta fs.inotify.max_user_watches (sviluppo/Docker)" \
"Linux monitora le modifiche ai file tramite inotify. Il limite default
è spesso troppo basso per ambienti di sviluppo moderni.
Sintomi: errori 'inotify watch limit reached' in VSCode, Webpack,
         Docker, Jest, Nodemon, e altri file watcher.
  • Default: 8192 o 65536 watches
  • Valore consigliato per sviluppo: 524288
  • Non ha impatto pratico sulle performance"; then

    current=$(cat /proc/sys/fs/inotify/max_user_watches 2>/dev/null || echo "N/A")
    echo -e "${CYAN}  → Valore attuale: $current${RESET}"
    write_file "/etc/sysctl.d/99-inotify.conf" \
"# Aumenta limite inotify watches per sviluppo e Docker\nfs.inotify.max_user_watches=524288\nfs.inotify.max_user_instances=512\n" && {
        ok
        echo -e "${CYAN}  → Applica subito (senza riavvio): sudo sysctl --system${RESET}"
    } || fail
fi

# ── EXTRA 21: DNS veloce via systemd-resolved ────────────────

if ask "EXTRA 21" "Imposta DNS veloce (Cloudflare 1.1.1.1 / Quad9 9.9.9.9)" \
"Il DNS di sistema determina quanto velocemente vengono risolti i nomi
di dominio. I DNS di default dell'ISP sono spesso lenti o poco affidabili.
  • 1.1.1.1 (Cloudflare) → il DNS più veloce al mondo, privacy-focused
  • 9.9.9.9 (Quad9)      → DNS sicuro con blocco malware
  • La configurazione viene scritta in /etc/systemd/resolved.conf.d/
  • Non sovrascrive la configurazione di NetworkManager/wifi
Verifica dopo applicazione: resolvectl status"; then

    nm_dns=$(nmcli -t -f NAME,IP4.DNS connection show 2>/dev/null | grep -v '^::' | wc -l)
    if [[ "$nm_dns" -gt 0 ]]; then
        echo -e "${YELLOW}  ⚠ Rilevati DNS in NetworkManager. Verifica che non ci sia un override VPN.${RESET}"
    fi

    run_cmd "sudo mkdir -p /etc/systemd/resolved.conf.d" && \
    write_file "/etc/systemd/resolved.conf.d/99-dns.conf" \
"[Resolve]\nDNS=1.1.1.1 9.9.9.9\nFallbackDNS=1.0.0.1 149.112.112.112\nDNSOverTLS=opportunistic\n" && \
    run_cmd "sudo systemctl restart systemd-resolved" && {
        ok
        echo -e "${CYAN}  → Verifica: resolvectl status${RESET}"
    } || fail
fi

# ── EXTRA 22: fail2ban ────────────────────────────────────────

if ask "EXTRA 22" "Installa fail2ban (protezione brute-force SSH)" \
"fail2ban monitora i log di sistema e blocca automaticamente gli IP
che tentano attacchi brute-force (SSH, FTP, web, ecc.).
  • Configurazione base: protegge SSH dopo 5 tentativi falliti
  • Banna l'IP per 10 minuti di default (configurabile)
  • Essenziale se esponi SSH verso internet o LAN
  • File di configurazione: /etc/fail2ban/jail.local
Verrà creata una configurazione base per SSH automaticamente."; then

    if pkg_installed fail2ban; then
        echo -e "${YELLOW}  → fail2ban già installato.${RESET}"; ((SKIPPED++))
    else
        run_cmd "sudo apt install -y fail2ban" && {
            # Configurazione base SSH
            write_file "/etc/fail2ban/jail.local" \
"[DEFAULT]\nbantime  = 10m\nfindtime = 10m\nmaxretry = 5\n\n[sshd]\nenabled = true\nport    = ssh\nlogpath = %(sshd_log)s\nbackend = %(sshd_backend)s\n"
            run_cmd "sudo systemctl enable --now fail2ban" && {
                ok
                echo -e "${CYAN}  → Stato: sudo fail2ban-client status sshd${RESET}"
                echo -e "${CYAN}  → Configurazione: /etc/fail2ban/jail.local${RESET}"
            } || fail
        } || fail
    fi
fi

# ── EXTRA 23: fstrim.timer ────────────────────────────────────

if ask "EXTRA 23" "Verifica e abilita fstrim.timer (TRIM settimanale SSD)" \
"fstrim.timer è il timer systemd che esegue il TRIM sull'SSD una volta a
settimana in modo sicuro e controllato. È complementare allo Step 1 dove
abbiamo rimosso il TRIM continuo da fstab.
  • Verifica che il timer sia attivo
  • Se non fosse attivo lo abilita
  • Esegue anche un fstrim manuale immediato"; then

    timer_status=$(systemctl is-enabled fstrim.timer 2>/dev/null || echo "disabled")
    echo -e "${CYAN}  → Stato attuale fstrim.timer: $timer_status${RESET}"
    run_cmd "sudo systemctl enable --now fstrim.timer" && {
        run_cmd "sudo fstrim -av" && ok || fail
    } || fail
fi

# ── EXTRA 24: Automount partizioni extra ─────────────────────

if ask "EXTRA 24" "Configura automount partizioni extra al boot" \
"Se hai un disco dati o una partizione secondaria, puoi configurarla
per essere montata automaticamente all'avvio come in Windows (D:, E:).
  • Mostra le partizioni disponibili non ancora in /etc/fstab
  • Crea il mount point e aggiunge la riga in /etc/fstab
  • Supporta ext4, NTFS (ntfs-3g), exFAT
NOTA: La partizione di sistema e quella di swap vengono ignorate.
Verrà creato un backup di /etc/fstab prima di qualsiasi modifica."; then

    echo ""
    echo -e "${CYAN}  → Partizioni rilevate (escluse sistema e swap):${RESET}"
    echo ""

    # Mostra partizioni non montate e non di sistema
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL | grep -v "swap\|/boot\| / " | grep -E "ext4|ntfs|exfat|vfat|btrfs|xfs"
    echo ""
    read -rp "$(echo -e "${BOLD}  Inserisci il dispositivo da montare (es. /dev/sdb1, lascia vuoto per saltare): ${RESET}")" PART_DEV

    if [[ -z "$PART_DEV" ]]; then
        echo -e "${YELLOW}  → Nessun dispositivo inserito. Saltato.${RESET}"; ((SKIPPED++))
    elif ! validate_input "$PART_DEV" "device"; then
        ((SKIPPED++))
    elif ! validate_device "$PART_DEV"; then
        ((SKIPPED++))
    else
        PART_UUID=$(blkid -s UUID -o value "$PART_DEV" 2>/dev/null)
        PART_FS=$(blkid -s TYPE -o value "$PART_DEV" 2>/dev/null)

        if [[ -z "$PART_UUID" ]]; then
            echo -e "${RED}  → UUID non trovato per $PART_DEV. Verifica il dispositivo.${RESET}"; fail
        else
            echo -e "${CYAN}  → UUID: $PART_UUID  |  Filesystem: $PART_FS${RESET}"
            read -rp "$(echo -e "${BOLD}  Nome cartella mount point in /mnt/ (es. dati, backup): ${RESET}")" MOUNT_NAME
            MOUNT_NAME="${MOUNT_NAME:-dati}"
            MOUNT_POINT="/mnt/$MOUNT_NAME"

            run_cmd "sudo mkdir -p $MOUNT_POINT"

            # Opzioni fstab in base al filesystem
            case "$PART_FS" in
                ntfs*) FSTAB_OPT="uid=$(id -u),gid=$(id -g),umask=0022,defaults,nofail" ;;
                exfat) FSTAB_OPT="uid=$(id -u),gid=$(id -g),umask=0022,defaults,nofail" ;;
                *)     FSTAB_OPT="defaults,noatime,nofail" ;;
            esac

            run_cmd "sudo cp /etc/fstab /etc/fstab.bak-automount"
            FSTAB_LINE="UUID=$PART_UUID $MOUNT_POINT $PART_FS $FSTAB_OPT 0 2"
            echo -e "${CYAN}  → Riga fstab da aggiungere:${RESET}"
            echo -e "    $FSTAB_LINE"
            read -rp "$(echo -e "${BOLD}  Confermi? [s/N]: ${RESET}")" confirm_fstab
            if [[ "$confirm_fstab" =~ ^[sS]([iI])?$ ]]; then
                if [[ "$DRY_RUN" -eq 0 ]]; then
                    echo "$FSTAB_LINE" | sudo tee -a /etc/fstab > /dev/null
                    sudo mount "$MOUNT_POINT" 2>/dev/null && echo -e "${GREEN}  ✔ Partizione montata in $MOUNT_POINT${RESET}" || \
                        echo -e "${YELLOW}  ⚠ Mount manuale fallito, riprova dopo riavvio.${RESET}"
                else
                    echo -e "${YELLOW}  [dry-run] aggiunta riga a /etc/fstab: $FSTAB_LINE${RESET}"
                fi
                ok; mark_reboot;
            else
                echo -e "${YELLOW}  → Annullato. Backup fstab rimosso.${RESET}"
                run_cmd "sudo rm -f /etc/fstab.bak-automount"
                ((SKIPPED++))
            fi
        fi
    fi
fi


# ── RIEPILOGO ────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}${BOLD}║                    RIEPILOGO FINALE                      ║${RESET}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${GREEN}✔ Step eseguiti: ${BOLD}$DONE${RESET}"
echo -e "  ${RED}✗ Step falliti:  ${BOLD}$FAILED${RESET}"
echo -e "  ${YELLOW}↷ Step saltati: ${BOLD}$SKIPPED${RESET}"
echo ""
if [[ "$DRY_RUN" -eq 1 ]]; then
    echo -e "${YELLOW}${BOLD}Modalità dry-run: nessuna modifica è stata applicata.${RESET}"
else
    if [[ "$REBOOT_RECOMMENDED" -eq 1 ]]; then
        echo -e "${YELLOW}${BOLD}Alcune modifiche richiedono riavvio o logout/login per essere applicate.${RESET}"
        read -rp "$(echo -e "${BOLD}Vuoi riavviare adesso? [s/N]: ${RESET}")" reboot_answer
        if [[ "$reboot_answer" =~ ^[sS]([iI])?$ ]]; then
            echo -e "${GREEN}Riavvio in corso...${RESET}"
            sudo reboot
        else
            echo -e "${CYAN}Riavvia manualmente quando preferisci.${RESET}"
        fi
    else
        echo -e "${CYAN}Nessun riavvio necessario per gli step eseguiti.${RESET}"
    fi
fi
