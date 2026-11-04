#!/bin/bash
# Radio „szum”: Pd (noise~) -> JACK -> ffmpeg -> Icecast :8000/radio
# Uruchamiane przez systemd --user (radio-szum.service).
PATCH=/home/dan/radio/szum-morza-bas.pd
ICE=icecast://source:radio123@localhost:8000/radio

# Czekaj na serwer JACK (systemowy jack.service) i Icecast
for i in $(seq 1 60); do
    jack_lsp 2>/dev/null | grep -qx system:playback_1 && curl -s -o /dev/null localhost:8000/ && break
    sleep 2
done

# Zabij Pd z tą samą nazwą JACK uruchomione poza usługą: inaczej nasze Pd dostaje
# nazwę pd_radio-01, a jack_connect poniżej podłącza do streamu cudzą instancję
pkill -f -- "-jackname pd_radio" 2>/dev/null && sleep 1

trap "kill 0" EXIT
pd -nogui -rt -jack -jackname pd_radio -send "pd dsp 1" "$PATCH" &
sleep 4
ffmpeg -nostdin -loglevel warning -f jack -i pd_stream -acodec libmp3lame -ab 192k \
       -content_type audio/mpeg -f mp3 "$ICE" &

# stereo: L i R z Pd do streamu. Ponawiaj do skutku: przy obciążonym Pi port
# pd_stream potrafi pojawić się po kilku minutach (4.11.2026: 13 min), a jednorazowe
# jack_connect zostawiało stream z ciszą aż do następnego restartu
polaczone() { [ "$(jack_lsp -c pd_stream | grep -c 'pd_radio:output_')" = 2 ]; }
for i in $(seq 1 300); do
    jack_connect pd_radio:output_1 pd_stream:input_1 2>/dev/null
    jack_connect pd_radio:output_2 pd_stream:input_2 2>/dev/null
    polaczone && break
    sleep 2
done
polaczone || { echo "Nie udało się podłączyć pd_radio do pd_stream (10 min)"; exit 1; }

# Gdy padnie Pd albo ffmpeg, kończymy i systemd restartuje całość
wait -n
exit 1
