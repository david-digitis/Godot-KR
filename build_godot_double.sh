#!/usr/bin/env bash
# Compile Godot en double precision (grandes cartes, KNIFE-936) : l'editeur
# Windows, les modeles d'export Windows et le modele d'export Linux du serveur,
# depuis les sources officielles, sur une machine Ubuntu (WSL ou GitHub Actions).
#
# Usage :
#   ./build_godot_double.sh <etiquette-ou-commit> [dossier-de-sortie]
#   ./build_godot_double.sh 4.7.2-stable out/4.7.2-stable
#
# Ecrit pour tourner tel quel sur une Ubuntu neuve : aucun chemin propre a un
# poste, les paquets sont installes par le script (sudo sans mot de passe).
# Une seule chaine pour tout : Linux en natif, Windows en compilation croisee
# avec mingw-w64 (posix), comme le fait le depot de Godot.
#
# Reglages par variables d'environnement :
#   TARGETS    cibles a construire, separees par des espaces. Defaut :
#              "win-editor win-release win-debug linux-release".
#              Aussi : linux-debug, linux-editor.
#   PRECISION  double (defaut) ou single (un temoin : meme chaine, meme options).
#   LTO        none (defaut), full (comme les builds officiels ; long, jusqu'a
#              30 Go de memoire pour Windows) ou auto.
#   JOBS       taches en parallele (defaut : tous les coeurs).
#   WORK       dossier de travail des sources (defaut : ~/godot-double). Sous
#              WSL, le laisser dans le systeme de fichiers Linux : /mnt/c est
#              trop lent.
#   SKIP_APT   1 = ne pas installer les paquets.
#   GODOT_REPO depot des sources (defaut : le depot officiel).
#   GODOT_VERSION_STATUS  pour une pre-version compilee depuis un commit
#              (dev7, beta1...) : lu directement par le SConstruct de Godot.
#
# Sort dans le dossier de sortie les binaires sous le nom que Godot leur donne
# (godot.windows.editor.double.x86_64.exe, ...) et BUILD-INFO.txt : etiquette,
# commit, options, duree et taille de chaque cible, empreintes SHA-256.
#
# Options retenues, et pourquoi :
#   precision=double  le but.
#   production=yes    les options des builds publies (sans symboles, C++ statique).
#   d3d12=no          le jeu est en Vulkan Forward+ ; evite le SDK Direct3D 12.
#   accesskit=no      lecteur d'ecran : demande des bibliotheques precompilees.
set -euo pipefail

REF="${1:?usage : build_godot_double.sh <etiquette-ou-commit> [dossier-de-sortie]}"
OUT="${2:-$PWD/godot-double-out/$REF}"
TARGETS="${TARGETS:-win-editor win-release win-debug linux-release}"
PRECISION="${PRECISION:-double}"
LTO="${LTO:-none}"
JOBS="${JOBS:-$(nproc)}"
WORK="${WORK:-$HOME/godot-double}"
GODOT_REPO="${GODOT_REPO:-https://github.com/godotengine/godot.git}"

SRC="$WORK/src-$REF"
COMMON="precision=$PRECISION production=yes lto=$LTO accesskit=no"
WINDOWS="arch=x86_64 use_mingw=yes d3d12=no"
LINUX="arch=x86_64"

log() { printf '\n=== %s ===\n' "$*"; }

install_packages() {
    [ "${SKIP_APT:-0}" = "1" ] && return
    local wanted="build-essential scons pkg-config git mingw-w64 libx11-dev libxcursor-dev
        libxinerama-dev libgl1-mesa-dev libglu1-mesa-dev libasound2-dev libpulse-dev
        libudev-dev libxi-dev libxrandr-dev libwayland-dev"
    local missing=""
    for package in $wanted; do
        dpkg -s "$package" >/dev/null 2>&1 || missing="$missing $package"
    done
    if [ -n "$missing" ]; then
        log "Paquets a installer :$missing"
        sudo DEBIAN_FRONTEND=noninteractive apt-get update -q
        # shellcheck disable=SC2086
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q $missing
    fi
    # Godot demande la variante posix de MinGW (threads) ; Ubuntu propose win32 par defaut.
    for tool in gcc g++; do
        sudo update-alternatives --set "x86_64-w64-mingw32-$tool" "/usr/bin/x86_64-w64-mingw32-$tool-posix"
    done
}

fetch_sources() {
    if [ -d "$SRC/.git" ]; then
        log "Sources deja la : $SRC"
        return
    fi
    log "Sources : $REF depuis $GODOT_REPO"
    mkdir -p "$SRC"
    git -C "$SRC" init -q
    git -C "$SRC" remote add origin "$GODOT_REPO"
    # Une etiquette comme un commit, sans historique.
    git -C "$SRC" fetch -q --depth 1 origin "$REF"
    git -C "$SRC" -c advice.detachedHead=false checkout -q FETCH_HEAD
}

# build <nom> <plateforme> <cible> <options scons...> : compile, chronometre,
# range les binaires. Le journal complet de scons va dans log-<nom>.txt.
build() {
    local name="$1" platform="$2" target="$3"
    shift 3
    log "$name : scons platform=$platform target=$target $* $COMMON"
    local started=$SECONDS status=0
    # shellcheck disable=SC2086
    (cd "$SRC" && scons -j"$JOBS" platform="$platform" target="$target" "$@" $COMMON) > "$OUT/log-$name.txt" 2>&1 || status=$?
    local seconds=$((SECONDS - started))
    if [ "$status" -ne 0 ]; then
        echo "ECHEC $name apres ${seconds}s : voir $OUT/log-$name.txt"
        tail -n 20 "$OUT/log-$name.txt"
        echo "$name : ECHEC apres ${seconds}s" >> "$OUT/BUILD-INFO.txt"
        return 1
    fi
    local precision_tag=""
    [ "$PRECISION" = "double" ] && precision_tag="double."
    local file
    for file in "$SRC/bin/godot.$platform.$target.${precision_tag}x86_64"*; do
        [ -f "$file" ] || continue
        cp -f "$file" "$OUT/"
        printf '%s : %ss, %s, %s octets\n' "$name" "$seconds" "$(basename "$file")" "$(stat -c %s "$file")" >> "$OUT/BUILD-INFO.txt"
    done
    echo "$name : ${seconds}s"
}

mkdir -p "$OUT" "$WORK"
total_started=$SECONDS
install_packages
fetch_sources
# Les binaires d'une Release portent la licence de Godot et celles de ses tiers.
cp -f "$SRC/LICENSE.txt" "$SRC/COPYRIGHT.txt" "$OUT/"

{
    echo "Godot $PRECISION precision, construit le $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "reference : $REF"
    echo "commit    : $(git -C "$SRC" rev-parse HEAD)"
    echo "options   : $COMMON"
    echo "windows   : platform=windows $WINDOWS ($(x86_64-w64-mingw32-g++ --version | head -1))"
    echo "linux     : platform=linuxbsd $LINUX ($(g++ --version | head -1))"
    echo "machine   : $(nproc) coeurs, $(lsb_release -ds 2>/dev/null || uname -sr)"
    echo
} > "$OUT/BUILD-INFO.txt"

failed=""
for target in $TARGETS; do
    case "$target" in
        win-editor)    build "$target" windows editor $WINDOWS || failed="$failed $target" ;;
        win-release)   build "$target" windows template_release $WINDOWS || failed="$failed $target" ;;
        win-debug)     build "$target" windows template_debug $WINDOWS || failed="$failed $target" ;;
        linux-release) build "$target" linuxbsd template_release $LINUX || failed="$failed $target" ;;
        linux-debug)   build "$target" linuxbsd template_debug $LINUX || failed="$failed $target" ;;
        linux-editor)  build "$target" linuxbsd editor $LINUX || failed="$failed $target" ;;
        *) echo "Cible inconnue : $target"; failed="$failed $target" ;;
    esac
done

{
    echo
    echo "duree totale : $((SECONDS - total_started))s"
    echo
    (cd "$OUT" && sha256sum godot.* 2>/dev/null)
} >> "$OUT/BUILD-INFO.txt"

log "Termine en $((SECONDS - total_started))s"
cat "$OUT/BUILD-INFO.txt"
if [ -n "$failed" ]; then
    echo "Cibles en echec :$failed"
    exit 1
fi
