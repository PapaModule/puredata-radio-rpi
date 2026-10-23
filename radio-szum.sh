#!/bin/bash
# Radio „szum”: Pd (noise~) -> JACK -> ffmpeg -> Icecast :8000/radio
# Uruchamiane przez systemd --user (radio-szum.service).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH="$SCRIPT_DIR/patches/szum-morza.pd"

# Hasło źródła Icecast — podaj przez zmienną środowiskową, np.:
#   export ICECAST_SOURCE_PASSWORD=twoje_haslo
# Nie trzymaj prawdziwego hasła w tym pliku!
ICECAST_SOURCE_PASSWORD="${ICECAST_SOURCE_PASSWORD:-TU_WPISZ_HASLO}"
if [ "$ICECAST_SOURCE_PASSWORD" = "TU_WPISZ_HASLO" ]; then
    echo "BŁĄD: ustaw zmienną ICECAST_SOURCE_PASSWORD przed uruchomieniem" >&2
    exit 1
fi
ICE=icecast://source:${ICECAST_SOURCE_PASSWORD}@localhost:8000/radio

# Czekaj na serwer JACK (systemowy jack.service) i Icecast
for i in $(seq 1 60); do
    jack_lsp 2>/dev/null | grep -qx system:playback_1 && curl -s -o /dev/null localhost:8000/ && break
    sleep 2
done

trap "kill 0" EXIT
pd -nogui -rt -jack -jackname pd_radio -send "pd dsp 1" "$PATCH" &
sleep 4
ffmpeg -nostdin -loglevel warning -f jack -i pd_stream -acodec libmp3lame -ab 192k \
       -content_type audio/mpeg -f mp3 "$ICE" &

for i in $(seq 1 15); do
    jack_lsp | grep -qx pd_stream:input_1 && break
    sleep 1
done
# stereo: L i R z Pd do streamu
jack_connect pd_radio:output_1 pd_stream:input_1
jack_connect pd_radio:output_2 pd_stream:input_2

# Gdy padnie Pd albo ffmpeg, kończymy i systemd restartuje całość
wait -n
exit 1
