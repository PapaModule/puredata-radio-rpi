# Pure Data Radio — Raspberry Pi / PatchBox OS

Generatywne radio Pure Data na Raspberry Pi z PatchBox OS, kartą dźwiękową Pisound, JACK i streaming MP3 do Icecast.

## Co gra

Patch `patches/szum-morza-bas.pd` (na Pi: `~/radio/szum-morza-bas.pd`) — mikser dwóch kanałów przed reverbem:

- kanał 1: szum morza, 2× `noise~` (stereo) → LP24 (2× `vcf~ 0.7`, wyjście lowpass) z LFO `osc~ 0.08` na cutoff 250–2050 Hz,
- kanał 2: bas, sinus z krótkim decayem (`vline~` 2/280 ms, do kwadratu), co 300 ms losowa nuta z arpeggio E-moll od E2 (E2 G2 B2 D3 E3 F#3 G3), mono na oba wyjścia,
- `+~` (mikser) → `rev3~ 100 92 3000 30`, dry/wet 50/50 → `dac~`. Dźwięk idzie jednocześnie na wyjście Pisound (JACK) i do strumienia Icecast.

## Wymagania

- Raspberry Pi 4, PatchBox OS (Debian 12)
- Karta dźwiękowa Pisound
- `puredata` (PD vanilla 0.53.1)
- `jackd2` (JACK na `hw:pisound`, 48000 Hz)
- `ffmpeg` z `libmp3lame`
- Icecast2 na `localhost:8000` (mount `/radio`, source hasło `radio123`)

## Uruchomienie (skrót)

```bash
chmod +x radio-szum.sh
./radio-szum.sh
```

Skrypt:
1. Czeka na JACK (`system:playback_1`) i Icecast (`localhost:8000`)
2. Zabija inne Pd o nazwie JACK `pd_radio`, potem uruchamia PD w trybie `-nogui -rt -jack -jackname pd_radio -send "pd dsp 1"` z patchu `szum-morza-bas.pd`
3. Uruchamia ffmpeg odczytujący z JACK (`pd_stream`), kodujący MP3 192k do Icecast
4. Podłącza porty JACK: `pd_radio:output_1/2` → `pd_stream:input_1/2`
5. Czeka (`wait -n`) — gdy PD lub ffmpeg padnie, skrypt kończy się z kodem 1 (systemd --user restartuje)

## Kluczowe zasady PD (docs/PD_RADIO_INSTRUKCJE.md)

- `random` przyjmuje TYLKO bang — wstaw `b` przed `random`, jeśli sygnał pochodzi z float
- Start DSP flagą `-send "pd dsp 1"`, nie `loadbang → msg`
- Uruchamiaj PD w tmux, nie przez nohup (SIGHUP zabija proces)
- Po zabiciu PD stare porty JACK mogą wisieć (zombie) — sprawdzaj `jack_lsp | grep pd_radio`
- Streaming MP3 przez ffmpeg, nie DarkIce (lame crashuje)
- Safari/iOS wymaga MP3 — nie OGG

## Icecast

- Port: 8000
- Mount: /radio
- Hasło źródła: przez zmienną `ICECAST_SOURCE_PASSWORD` (nie w repo!)
- URL strumienia: http://patchbox.local:8000/radio

## Pliki

- `radio-szum.sh` — skrypt startowy (systemd --user)
- `patches/szum-morza.pd` — oryginalny patch PD (szum morza, rev3~)
- `patches/szum-morza-bas.pd` — **aktualny** patch radia (szum morza + bas, mikser, rev3~)
- `patches/szum-morza-hall.pd` — eksperyment z `s-jonverb~`; nieużywany (GarageBeat nie działa w `-nogui`)
- `docs/PD_RADIO_INSTRUKCJE.md` — pełna instrukcja uruchomienia
