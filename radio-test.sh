#!/bin/bash
# Radio TESTOWE: Pd (patch testowy) -> JACK (test_*) -> ffmpeg -> Icecast :8001/test
# Produkcja (:8000, pd_radio, pd_stream, usluga radio-szum) pozostaje NIETKNIETA.
# Uzycie:
#   ./radio-test.sh start <patch.pd> [jackname]   # odpala patch testowy i stream
#   ./radio-test.sh stop                          # zabija patch i stream testowy
#   ./radio-test.sh status                        # co chodzi w torze testowym
set -u
. /home/dan/radio/.radio-test.env
TEST_URL="icecast://source:${ICECAST_TEST_SOURCE_PASSWORD}@localhost:8001/test"

cmd="${1:-status}"
case "$cmd" in
  start)
    PATCH="${2:-}"
    [ -z "$PATCH" ] && { echo "Uzycie: $0 start <patch.pd> [jackname]"; exit 1; }
    [ -f "$PATCH" ] || { echo "Brak pliku: $PATCH"; exit 1; }
    JN="${3:-test_$(basename "$PATCH" .pd | tr -c 'a-zA-Z0-9' '_')}"
    # porzadki po poprzedniej sesji testowej (NIE ruszamy pd_radio/produkcji!)
    pkill -f "jackname test_" 2>/dev/null && sleep 1
    pkill -f "localhost:8001/test" 2>/dev/null && sleep 1
    # icecast testowy musi dzialac (usluga icecast-test)
    curl -s -o /dev/null localhost:8001/ || { echo "Icecast testowy nie dziala - systemctl --user start icecast-test"; exit 1; }
    echo "Pd: $PATCH (jackname $JN)"
    pd -nogui -rt -jack -jackname "$JN" -send "pd dsp 1" "$PATCH" &
    sleep 4
    ffmpeg -nostdin -loglevel warning -f jack -i test_stream \
           -acodec libmp3lame -ab 192k -content_type audio/mpeg -f mp3 "$TEST_URL" &
    for i in $(seq 1 15); do
        jack_lsp 2>/dev/null | grep -qx test_stream:input_1 && break
        sleep 1
    done
    jack_connect "$JN:output_1" test_stream:input_1
    jack_connect "$JN:output_2" test_stream:input_2
    # Pd auto-connectuje do system:playback - odlaczamy, glosniki = tylko produkcja
    jack_disconnect "$JN:output_1" system:playback_1 2>/dev/null
    jack_disconnect "$JN:output_2" system:playback_2 2>/dev/null
    echo "Stream: http://localhost:8001/test (publicznie: ...:8443/test)"
    ;;
  stop)
    pkill -f "jackname test_" 2>/dev/null && echo "zabito test pd"
    pkill -f "localhost:8001/test" 2>/dev/null && echo "zabito test ffmpeg"
    ;;
  status)
    echo "--- test pd:";    pgrep -a -f "jackname test_"  || echo "brak"
    echo "--- test ffmpeg:"; pgrep -a -f "8001/test"      || echo "brak"
    echo "--- icecast-test:"; systemctl --user is-active icecast-test
    echo "--- produkcja (musi grac!):"
    pgrep -a -x pd | grep -F szum-morza-bas.pd || echo "UWAGA: brak produkcji!"
    ;;
  *) echo "Uzycie: $0 {start <patch.pd> [jackname]|stop|status}"; exit 1;;
esac
