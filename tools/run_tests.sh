#!/bin/bash
# Corre la suite GUT SIN contaminar el guardado real del usuario.
#
# Bug real encontrado jugando: SaveManager/MetaManager/LevelManager son autoloads reales
# que persisten en user://save.json / user://meta.json / user://pack_progress.json — los
# MISMOS archivos que usa una partida jugada a mano. GUT no aísla ese estado entre
# corridas, así que CUALQUIER test que suba un valor "solo si es mayor" (best_score,
# max_wave, highest_level_unlocked, progreso de un pack) u otorgue oro/desbloquee un
# personaje sin revertirlo queda escrito ahí PARA SIEMPRE. Con decenas de corridas de esta
# suite a lo largo de una sesión, el guardado real terminó con highest_level_unlocked=110
# (más alto que los 100 niveles que existen), oro/mejor puntaje inflados y un personaje
# "desbloqueado" sin haberlo comprado — el usuario lo reportó como "todos los niveles
# aparecen habilitados desde el inicio".
#
# Los tests conocidos que mutaban este estado ya se corrigieron para restaurarlo ellos
# mismos (ver test_save_manager.gd/test_meta_manager.gd/test_pack_levels_screen.gd), pero
# un test NUEVO puede volver a introducir el mismo problema sin que nadie lo note (el
# síntoma es sutil: los tests siguen en verde, solo el archivo real queda contaminado).
# Este script es la red de seguridad real: respalda los 3 archivos antes de correr la
# suite y los restaura después, pase lo que pase (incluido si la suite falla) — así
# CUALQUIER test, presente o futuro, nunca puede afectar permanentemente una partida real
# jugada a mano.
#
# Uso: ./tools/run_tests.sh (mismos argumentos de siempre para godot/GUT, opcional)
set -uo pipefail

USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/Totopo Smash"
SAVE_FILE="$USER_DATA_DIR/save.json"
META_FILE="$USER_DATA_DIR/meta.json"
PACK_PROGRESS_FILE="$USER_DATA_DIR/pack_progress.json"
AUDIO_SETTINGS_FILE="$USER_DATA_DIR/audio_settings.json"
BACKUP_DIR=$(mktemp -d)

_backup() {
    local src="$1" name="$2"
    if [ -f "$src" ]; then
        cp "$src" "$BACKUP_DIR/$name"
    else
        rm -f "$BACKUP_DIR/$name.absent"
        touch "$BACKUP_DIR/$name.absent"  # marca "no existía" para poder borrar al restaurar
    fi
}

_restore() {
    local dst="$1" name="$2"
    if [ -f "$BACKUP_DIR/$name.absent" ]; then
        rm -f "$dst"
    elif [ -f "$BACKUP_DIR/$name" ]; then
        cp "$BACKUP_DIR/$name" "$dst"
    fi
}

_backup "$SAVE_FILE" "save.json"
_backup "$META_FILE" "meta.json"
_backup "$PACK_PROGRESS_FILE" "pack_progress.json"
_backup "$AUDIO_SETTINGS_FILE" "audio_settings.json"

godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit -glog=2 "$@"
EXIT_CODE=$?

_restore "$SAVE_FILE" "save.json"
_restore "$META_FILE" "meta.json"
_restore "$PACK_PROGRESS_FILE" "pack_progress.json"
_restore "$AUDIO_SETTINGS_FILE" "audio_settings.json"
rm -rf "$BACKUP_DIR"

exit $EXIT_CODE
