#!/bin/bash
# Radio „szum”: Pd (noise~) -> JACK -> ffmpeg -> Icecast :8000/radio
# Uruchamiane przez systemd --user (radio-szum.service).
PATCH=/home/dan/radio/szum-morza-hall.pd
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
