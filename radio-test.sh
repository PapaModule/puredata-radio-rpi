#!/bin/bash
# Radio TESTOWE: Pd (patch testowy) -> JACK (test_*) -> ffmpeg -> Icecast :8001/test
# Produkcja (:8000, pd_radio, pd_stream, usluga radio-szum) pozostaje NIETKNIETA.
# Tor chodzi jako usluga systemd --user `radio-test` (startuje tez po reboocie z ostatnim
# patchem), wiec nie ginie przy restarcie tego, kto go odpalil (np. hermes-gateway).
# Uzycie:
#   ./radio-test.sh start <patch.pd> [jackname]   # zapisuje patch i (re)startuje usluge
#   ./radio-test.sh stop                          # zatrzymuje usluge (po reboocie wstanie znow)
#   ./radio-test.sh status                        # co chodzi w torze testowym
#   ./radio-test.sh run                           # tylko dla radio-test.service
set -u
. /home/dan/radio/.radio-test.env
TEST_URL="icecast://source:${ICECAST_TEST_SOURCE_PASSWORD}@localhost:8001/test"
STATE=/home/dan/radio/.radio-test-patch   # linia 1: patch, linia 2: jackname

# zabija instancje testowe uruchomione poza usluga (NIE rusza pd_radio ani /test-idle)
sprzataj() {
    for P in $(pgrep -x pd); do
        tr '\0' ' ' < /proc/$P/cmdline 2>/dev/null | grep -q "jackname test_" && kill "$P" 2>/dev/null && echo "zabito test pd PID $P"
    done
    for P in $(pgrep -x ffmpeg); do
        tr '\0' ' ' < /proc/$P/cmdline 2>/dev/null | grep -q "8001/test " && kill "$P" 2>/dev/null && echo "zabito test ffmpeg PID $P"
    done
}

cmd="${1:-status}"
case "$cmd" in
  start)
    PATCH="${2:-}"
    [ -z "$PATCH" ] && { echo "Uzycie: $0 start <patch.pd> [jackname]"; exit 1; }
    [ -f "$PATCH" ] || { echo "Brak pliku: $PATCH"; exit 1; }
    JN="${3:-test_$(basename "$PATCH" .pd | tr -c 'a-zA-Z0-9' '_')}"
    printf '%s\n%s\n' "$(realpath "$PATCH")" "$JN" > "$STATE"
    echo "Pd: $PATCH (jackname $JN)"
    systemctl --user restart radio-test
    echo "Stream: http://localhost:8001/test (publicznie: ...:8443/test); log: journalctl --user -u radio-test"
    ;;
  stop)
    systemctl --user stop radio-test
    sprzataj
    ;;
  run)
    { read -r PATCH; read -r JN; } < "$STATE" || { echo "Brak $STATE - uzyj: $0 start <patch.pd>"; exit 1; }
    [ -f "$PATCH" ] || { echo "Brak pliku: $PATCH"; exit 1; }
    # po reboocie czekaj na JACK i icecast testowy
    for i in $(seq 1 60); do
        jack_lsp 2>/dev/null | grep -qx system:playback_1 && curl -s -o /dev/null localhost:8001/ && break
        sleep 2
    done
    sprzataj
    sleep 1
    trap "kill 0" EXIT
    pd -nogui -rt -jack -jackname "$JN" -send "pd dsp 1" "$PATCH" &
    sleep 4
    ffmpeg -nostdin -loglevel warning -f jack -i test_stream \
           -acodec libmp3lame -ab 192k -content_type audio/mpeg -f mp3 "$TEST_URL" &
    # ponawiaj do skutku: przy obciazonym Pi port test_stream potrafi wstac po minutach
    polaczone() { [ "$(jack_lsp -c test_stream | grep -c "$JN:output_")" = 2 ]; }
    for i in $(seq 1 300); do
        jack_connect "$JN:output_1" test_stream:input_1 2>/dev/null
        jack_connect "$JN:output_2" test_stream:input_2 2>/dev/null
        polaczone && break
        sleep 2
    done
    polaczone || { echo "Nie udalo sie podlaczyc $JN do test_stream (10 min)"; exit 1; }
    # Pd auto-connectuje do system:playback - odlaczamy, glosniki = tylko produkcja
    jack_disconnect "$JN:output_1" system:playback_1 2>/dev/null
    jack_disconnect "$JN:output_2" system:playback_2 2>/dev/null
    echo "Gra: $PATCH -> :8001/test"
    # gdy padnie Pd albo ffmpeg, konczymy i systemd restartuje calosc
    wait -n
    exit 1
    ;;
  status)
    echo "--- usluga radio-test: $(systemctl --user is-active radio-test), patch: $(head -1 "$STATE" 2>/dev/null || echo brak)"
    echo "--- test pd:";    pgrep -a -f "[j]ackname test_"  || echo "brak"
    echo "--- test ffmpeg:"; pgrep -a -f "[8]001/test$"     || echo "brak"
    echo "--- icecast-test:"; systemctl --user is-active icecast-test
    echo "--- produkcja (musi grac!):"
    pgrep -a -x pd | grep -F szum-morza-bas.pd || echo "UWAGA: brak produkcji!"
    ;;
  *) echo "Uzycie: $0 {start <patch.pd> [jackname]|stop|status}"; exit 1;;
esac
