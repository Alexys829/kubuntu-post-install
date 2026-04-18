#!/bin/bash

# ============================================================
#  Kubuntu Post-Install Setup Script v3.3
#  Compatibile con: Kubuntu 24.04 LTS / 26.04 LTS
#  Modalità supportate:
#    bash kubuntu-post-install.sh
#    bash kubuntu-post-install.sh --dry-run
# ============================================================

# CHANGELOG v3.3
#  - Rimosso EXTRA 4 (Docker): usa docker-linux-installer per installazione
#    aggiornata dal repo ufficiale Docker
#  - Fix EXTRA 15 (irqbalance): aggiunto || fail al blocco già-installato
# ============================================================
