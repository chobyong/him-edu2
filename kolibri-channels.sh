#!/usr/bin/env bash
# =============================================================================
# Kolibri Channel Install Script
# Imports all English and Spanish channels from the HimEdu channel list.
# Safe to re-run — skips channels already installed.
# Run as root: sudo bash kolibri-channels.sh
# =============================================================================
set -euo pipefail

KOLIBRI_USER="${SUDO_USER:-him}"
KOLIBRI_VENV="/opt/kolibri-venv"
KOLIBRI_HOME="/opt/kolibri-data"

if [[ $EUID -ne 0 ]]; then
  echo "Please run with sudo: sudo bash $0"
  exit 1
fi

if [[ ! -x "$KOLIBRI_VENV/bin/kolibri" ]]; then
  echo "ERROR: Kolibri not found at $KOLIBRI_VENV — run setup.sh first."
  exit 1
fi

info()    { echo -e "\n\033[1;34m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[OK]\033[0m $*"; }

# =============================================================================
# ENGLISH CHANNELS
# =============================================================================
CHANNELS_EN=(
  "c9d7f950ab6b5a1199e3d6c10d7f0103|Khan Academy (English - US curriculum)"
  "1d8f6d84618153c18c695d85074952a7|CK-12"
  "197934f144305350b5820c7c4dd8e194|PhET Interactive Simulations"
  "1e378725d3924b47aa5e1260628820b5|TED-Ed Lessons"
  "913efe9f14c65cb1b23402f21f056e99|MIT Blossoms"
  "fc47aee82e0153e2a30197d3fdee1128|Open Stax"
  "0e173fca6e9052f8a474a2fb84055faf|Global Digital Library - Book Catalog"
  "3e464ee12f6a50a781cddf59147b48b1|Sikana (English)"
  "2d7b056d668a58ee9244ccf76108cbdb|Book Dash"
  "131e543dbecf5776bb13cfcfddf05605|Pratham Books StoryWeaver"
  "b8bd7770063d40a8bd9b30d4703927b5|PBS SoCal: Family Math"
  "63e8e65976f258cf9b1a5bb85e486aa8|Digital Discovery (English)"
  "8b28761bac075deeb66adc6c80ef119c|Osmosis.org"
  "e409b964366a59219c148f2aaa741f43|Blockly Games"
  "6616efc8aa604a308c8f5d18b00a1ce3|Khan Academy - Standardized Test Preparation"
  "922e9c576c2f59e59389142b136308ff|Career Girls"
  "d6e3b856125f5e6aa5fb40c8b112d5e9|EngageNY (English)"
  "74f36493bb475b62935fa8705ed59fed|Thoughtful Learning"
  "7ec3b2ad48925d639592954e2298618f|HP LIFE - Courses (English)"
  "0418cc231e9c5513af0fff9f227f7172|Free English with Hello Channel"
  "61b75af2bb2c4c0ea850d85dcf88d0fd|Espresso English"
  "8a2d480dbc9b53408c688e8188326b16|Aflatoun Academy (English)"
  "12cee68c112452a1be3f73e730ec2114|Stanford Digital MEdIC Coronavirus Toolkit"
  "000409f81dbe5d1ba67101cb9fed4530|Touchable Earth"
  "5d53b37cc90e50128a40e293d9fadb27|Global Youth Communities"
  "3c77d9dd717341bb8fff8da6ab980df3|Mother Goose Club Video Lessons"
  "8db463b116d24a6c8f56c4df4fa88041|Tackling Violence Film Series"
  "9b3463eaa85354eeb26a184fe1d9a04b|Digital Awareness (English)"
  "a9b25ac9814742c883ce1b0579448337|TESSA - Teacher Resources"
  "b62c5c2139a65fb2aaf68987a25b28a1|Goalkicker Tech Books"
  "bbb4ea407a3c450cb18cbaa76f2d75cd|CSpathshala (English)"
  "c51a0f842fed427c95acff9bb4a21e3c|EENET Inclusive Education Training Materials"
  "cf4fee6d062a49fc88131f8a4ea2192e|Colors of Kindness"
  "d35a806594a843f2864457eac34ee12e|Childhood Education International"
  "f189d7c505644311a4e62d9f3259e31b|Sciensation"
  "f758ac6ad39c452f956658da6ad7d3cc|Project Based Learning with Kolibri"
  "b06dd546e8ba4b44bf921862c9948ffe|WiiXii"
)

# =============================================================================
# SPANISH CHANNELS
# =============================================================================
CHANNELS_ES=(
  "c1f2b7e6ac9f56a2bb44fa7a48b66dce|Khan Academy (Español)"
  "8fa678af1dd05329bf3218c549b84996|Simulaciones interactivas PhET"
  "30c71c99c42c57d181e8aeafd2e15e5f|Sikana (Español)"
  "e0bba57cf3475efbbafc3623c4ea6332|CommonLit (Español)"
  "da53f90b1be25752a04682bbc353659f|Ciencia NASA"
  "f6cb302ef6594db4b4a04b4991a595c2|Plan Educativo TIC Basico"
  "fed29d60e4d84a1e8dcfc781d920b40e|Biblioteca Elejandria"
  "f446655247a95c0aa94ca9fa4d66783b|Proyecto Biosfera"
  "0a3446937e3340fa86e6010ba80e16e1|Guía de Alfabetización Digital Crítica"
  "07cd1633691b4473b6fda08caf826253|Ciensación"
  "7e68bc59d4304e718a0750b1b87125ad|Cultura Emprendedora"
  "c4ad70f67dff57738591086e466f9afc|Proyecto Descartes"
  "d0cb2b465843584e9c72969ea5ea5519|HP LIFE - Cursos (Español)"
  "1c98e92b8c2f536796960bed8d137a25|Ceibal"
  "604ad3b85d844dd89ee70fa12a9a5a6e|CREE+"
)

# =============================================================================
# IMPORT FUNCTION
# =============================================================================
import_channel() {
  local channel_id="$1"
  local channel_name="$2"

  info "[$channel_name] Checking..."

  # Check if already installed
  local already
  already=$(sudo -u "$KOLIBRI_USER" KOLIBRI_HOME="$KOLIBRI_HOME" \
    "$KOLIBRI_VENV/bin/kolibri" manage listchannels 2>/dev/null \
    | grep -c "$channel_id" || true)

  if [[ "$already" -gt 0 ]]; then
    success "[$channel_name] Already installed, skipping."
    return
  fi

  info "[$channel_name] Importing channel metadata..."
  sudo -u "$KOLIBRI_USER" KOLIBRI_HOME="$KOLIBRI_HOME" \
    "$KOLIBRI_VENV/bin/kolibri" manage importchannel network "$channel_id" \
    2>&1 | grep -v "^\[.*INFO\|override\|DEBUG" || true

  info "[$channel_name] Downloading content..."
  sudo -u "$KOLIBRI_USER" KOLIBRI_HOME="$KOLIBRI_HOME" \
    "$KOLIBRI_VENV/bin/kolibri" manage importcontent network "$channel_id" \
    2>&1 | grep -v "^\[.*INFO\|override\|DEBUG" || true

  success "[$channel_name] Done."
}

# =============================================================================
# MAIN
# =============================================================================
echo "============================================================"
echo "  Kolibri Channel Installer"
echo "  English: ${#CHANNELS_EN[@]} channels"
echo "  Spanish: ${#CHANNELS_ES[@]} channels"
echo "  Total  : $(( ${#CHANNELS_EN[@]} + ${#CHANNELS_ES[@]} )) channels"
echo "============================================================"
echo ""
echo "NOTE: Large channels (Khan Academy) can take hours to download."
echo "      Safe to Ctrl+C and re-run — already installed channels are skipped."
echo ""

info "=== Installing English Channels ==="
for entry in "${CHANNELS_EN[@]}"; do
  channel_id="${entry%%|*}"
  channel_name="${entry##*|}"
  import_channel "$channel_id" "$channel_name"
done

info "=== Installing Spanish Channels ==="
for entry in "${CHANNELS_ES[@]}"; do
  channel_id="${entry%%|*}"
  channel_name="${entry##*|}"
  import_channel "$channel_id" "$channel_name"
done

echo ""
echo "============================================================"
echo "  All channels installed."
echo "  Access Kolibri at http://$(hostname -I | awk '{print $1}'):8080"
echo "============================================================"
