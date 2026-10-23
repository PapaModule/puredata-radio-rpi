# Pure Data Radio — Raspberry Pi / PatchBox OS

Generatywne radio Pure Data na Raspberry Pi z PatchBox OS, kartą dźwiękową Pisound, JACK i streaming MP3 do Icecast.

## Co gra

Patch `patches/szum-morza.pd` — szum morza: 2× `noise~` → filtr LP24 (2× `vcf~`) z LFO na cutoff → `rev3~` (reverb 50/50) → `dac~`. Dźwięk idzie jednocześnie na wyjście Pisound (JACK) i do strumienia Icecast.

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
2. Uruchamia PD w trybie `-nogui -rt -jack -jackname pd_radio -send "pd dsp 1"` z patchu `patches/szum-morza.pd`
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
- Hasło źródła: radio123
- URL strumienia: http://patchbox.local:8000/radio

## Pliki

- `radio-szum.sh` — skrypt startowy (systemd --user)
- `patches/szum-morza.pd` — patch PD (szum morza)
- `docs/PD_RADIO_INSTRUKCJE.md` — pełna instrukcja uruchomienia
