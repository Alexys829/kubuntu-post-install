# 🛠️ kubuntu-post-install

> Stanco di configurare Kubuntu a mano dopo ogni installazione? Questo script automatizza tutto il necessario.

Uno script Bash interattivo per **Kubuntu 24.04 LTS** e **26.04 LTS** che:
- Ottimizza il sistema (SSD, swap, systemd, GRUB)
- Installa codec, font e supporto filesystem
- Configura virtualizzazione KVM/QEMU completa
- Migliora performance e sicurezza con step opzionali

Ogni step è documentato, spiegato e **saltabile**. Supporta modalità `--dry-run` per vedere cosa verrebbe eseguito senza toccare il sistema.

---

## 📋 Requirements

- Kubuntu 24.04 LTS o 26.04 LTS
- `bash` (pre-installato)
- Connessione internet attiva
- Permessi `sudo`

---

## 🚀 Installation

### One-liner

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Alexys829/kubuntu-post-install/main/kubuntu-post-install.sh)
```

### Manual (clone the repo)

```bash
git clone https://github.com/Alexys829/kubuntu-post-install.git
cd kubuntu-post-install
bash kubuntu-post-install.sh
```

> Verrai guidato interattivamente attraverso ogni step. Puoi saltarne uno qualsiasi premendo `n`.

---

## ⚙️ How it works

```
Avvio script
      │
      ▼
  Step proposto
      │
      ├─ Confermi (y)? → esegui → ✅ DONE
      │
      ├─ Salti (n)?    → ⏭️ SKIPPED
      │
      └─ Dry-run?      → mostra cosa farebbe → 🔍 PREVIEW
```

Alla fine, lo script mostra un riepilogo con i contatori **DONE / FAILED / SKIPPED** e chiede il riavvio solo se necessario.

---

## 🖥️ Usage

```bash
# Esecuzione normale (interattiva)
bash kubuntu-post-install.sh

# Modalità dry-run (nessuna modifica applicata)
bash kubuntu-post-install.sh --dry-run
```

---

## 📋 Steps

### 🔧 Step principali

| Step | Descrizione |
|------|-------------|
| STEP 1 | Correggi `/etc/fstab` per SSD (rimuovi `discard`) |
| STEP 2 | Riduci swappiness (da 60 a 10) |
| STEP 3 | Riduci timeout systemd (da 90s a 15s) |
| STEP 4 | Configura menu GRUB (single/dual boot) |
| STEP 5 | Aggiorna sistema (APT + Snap) |
| STEP 6 | Installa codec, font Microsoft, exFAT |
| STEP 7 | Supporto DVD/Blu-ray (opzionale) |

### 🎁 Bonus

| Step | Descrizione |
|------|-------------|
| BONUS A | Rimuovi Snap e blocca reinstallazione |
| BONUS B | Abilita Flatpak + Flathub |
| BONUS C | Asterischi durante inserimento password sudo |
| BONUS D | Disabilita cambio utente rapido (KDE) |

### 🖥️ Extra — Virtualizzazione

| Step | Descrizione |
|------|-------------|
| EXTRA 1 | Driver GPU proprietari (NVIDIA) |
| EXTRA 2 | Firewall UFW |
| EXTRA 3 | Timeshift (snapshot di sistema) |
| EXTRA 4 | Strumenti sviluppo base (git, curl, build-essential...) |
| EXTRA 5 | KVM/QEMU + virt-manager |
| EXTRA 6 | OVMF/UEFI per VM moderne |
| EXTRA 7 | Supporto SPICE per VM |
| EXTRA 8 | Bridge di rete br0 via Netplan |
| EXTRA 9 | Preset KVM (Desktop / Developer / Server+Cockpit) |

### ⚡ Extra — Performance & Sicurezza

| Step | Descrizione |
|------|-------------|
| EXTRA 10 | TLP — ottimizzazione batteria (solo laptop) |
| EXTRA 11 | powertop — diagnosi consumi energetici |
| EXTRA 12 | thermald — gestione termica CPU Intel |
| EXTRA 13 | earlyoom — protezione da esaurimento RAM |
| EXTRA 14 | irqbalance — distribuzione interrupt su CPU multi-core |
| EXTRA 15 | haveged — generatore di entropia |
| EXTRA 16 | zRAM — swap compresso in RAM |
| EXTRA 17 | preload — precaricamento app frequenti |
| EXTRA 18 | TCP BBR — ottimizzazione algoritmo di rete |
| EXTRA 19 | Aumenta `fs.inotify.max_user_watches` (sviluppo/Docker) |
| EXTRA 20 | DNS veloce — Cloudflare 1.1.1.1 / Quad9 9.9.9.9 |
| EXTRA 21 | fail2ban — protezione brute-force SSH |
| EXTRA 22 | fstrim.timer — TRIM settimanale SSD |
| EXTRA 23 | Automount partizioni extra al boot |

---

## ✨ Features

- ✅ **Interattivo** — ogni step chiede conferma prima di procedere
- ✅ **Dry-run** — anteprima senza modifiche con `--dry-run`
- ✅ **Idempotente** — controlla se il pacchetto è già installato prima di agire
- ✅ **Backup automatico** — crea backup di `/etc/fstab` e `/etc/default/grub` prima di modificarli
- ✅ **Riepilogo finale** — mostra contatori DONE / FAILED / SKIPPED
- ✅ **Riavvio intelligente** — chiede riavvio solo se almeno uno step lo richiede

---

## 📝 Notes

> **Docker** non è incluso in questo script. Per installare Docker dal repo ufficiale (versioni aggiornate) usa lo script dedicato [docker-linux-installer](https://github.com/Alexys829/docker-linux-installer).

> **TLP** (EXTRA 10) va installato **solo su laptop**. Su desktop è inutile.

> **EXTRA 8 (bridge di rete)** non va eseguito in sessione SSH remota — potrebbe interrompere la connessione.

---

## 📦 Changelog

### v3.3 (2026-04-18)
- Rimosso EXTRA 4 (Docker via APT): Docker va installato con il dedicato `install_docker.sh`
- Fix EXTRA 14 (irqbalance): aggiunto `|| fail` al blocco già-installato per propagare correttamente gli errori

### v3.2
- Versione iniziale pubblica

---

## 📄 License

MIT — fai quello che vuoi con questo script.
