# Icecast — notatka konfiguracyjna

Usługa Icecast musi działać na `localhost:8000` z mountem `/radio`.

Hasło źródła **nie jest przechowywane w repozytorium**. Ustaw je przez zmienną środowiskową `ICECAST_SOURCE_PASSWORD` przed uruchomieniem `radio-szum.sh`.

URL strumienia: http://patchbox.local:8000/radio

Safari/iOS nie obsługuje OGG Vorbis — stream musi być MP3 (kodowane przez ffmpeg z libmp3lame).
