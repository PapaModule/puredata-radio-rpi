# PD Radio — instrukcje uruchomienia

## Kluczowe zasady PD vanilla na tym systemie

### 1. `random` przyjmuje TYLKO `bang`, nie `float`

Obiekt `random N` w tej wersji PD nie akceptuje float na wejściu.
Jeśli sygnał przychodzi z `moses`, `sel`, lub innego obiektu wysyłającego float,
MUSISZ wstawić obiekt `b` (bang) przed `random`:

```
DOBRZE:  moses 30 → b → random 8
ŹLE:     moses 30 → random 8   (error: random: no method for float)
```

### 2. DSP start: użyj flagi `-send`, NIE `loadbang → msg`

`loadbang → msg \; pd dsp 1` NIE działa niezawodnie w trybie `-nogui`.
Zamiast tego uruchamiaj PD z flagą:

```bash
pd -nogui -rt -jack -jackname pd_radio -send "pd dsp 1" /tmp/patch.pd
```

### 3. Uruchamiaj PD w tmux, NIE przez nohup

PD uruchomione przez `nohup` ginie po odłączeniu SSH (SIGHUP).
Używaj tmux:

```bash
tmux new-session -d -s pd_radio "pd -nogui -rt -jack -jackname pd_radio -send pd dsp 1 /tmp/patch.pd 2>&1 | tee /tmp/pd-radio.log"
```

### 4. JACK — zombie porty

Po zabiciu PD stare porty JACK mogą wisieć jako zombie.
Nowy PD dostanie suffix `-01` (np. `pd_radio-01:output_1`).
Zawsze sprawdzaj aktualną nazwę: `jack_lsp | grep pd_radio`

### 5. Streaming: ffmpeg MP3, NIE DarkIce

- Safari/iOS NIE obsługuje OGG Vorbis — MUSISZ streamować MP3
- DarkIce crashuje z MP3 (lame lib error) — użyj ffmpeg:

```bash
ffmpeg -f jack -i pd_stream \
  -acodec libmp3lame -ab 192k \
  -content_type audio/mpeg \
  -f mp3 icecast://source:radio123@localhost:8000/radio \
  </dev/null >/tmp/ffmpeg-stream.log 2>&1 &
```

Potem podłącz PD do ffmpeg w JACK:

```bash
jack_connect pd_radio:output_1 pd_stream:input_1
jack_connect pd_radio:output_2 pd_stream:input_2
```

### 6. Podłączanie JACK — pełny routing

```bash
# PD → głośnik (Pisound)
jack_connect pd_radio:output_1 system:playback_1
jack_connect pd_radio:output_2 system:playback_2

# PD → streaming (ffmpeg)
jack_connect pd_radio:output_1 pd_stream:input_1
jack_connect pd_radio:output_2 pd_stream:input_2
```

## Pełna procedura uruchomienia radia

```bash
# 1. Zabij stare procesy
killall pd ffmpeg 2>/dev/null
tmux kill-session -t pd_radio 2>/dev/null
sleep 1

# 2. Uruchom PD w tmux
tmux new-session -d -s pd_radio \
  "pd -nogui -rt -jack -jackname pd_radio -send pd dsp 1 /tmp/emin.pd 2>&1 | tee /tmp/pd-radio.log"
sleep 4

# 3. Uruchom ffmpeg MP3 stream
ffmpeg -f jack -i pd_stream -acodec libmp3lame -ab 192k \
  -content_type audio/mpeg -f mp3 \
  icecast://source:radio123@localhost:8000/radio \
  </dev/null >/tmp/ffmpeg-stream.log 2>&1 &
sleep 3

# 4. Podłącz JACK
jack_connect pd_radio:output_1 system:playback_1
jack_connect pd_radio:output_2 system:playback_2
jack_connect pd_radio:output_1 pd_stream:input_1
jack_connect pd_radio:output_2 pd_stream:input_2
```

## Icecast

- Port: 8000
- Mount: /radio
- Source password: radio123
- URL streamu: http://patchbox.local:8000/radio

## Skala E minor (MIDI)

E3=52, F#3=54, G3=55, A3=57, B3=59, C4=60, D4=62, E4=64
