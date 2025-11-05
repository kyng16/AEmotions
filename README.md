# app_emotions

Czysty start Flutter – bez domyślnego „counter demo”.

## Jak uruchomić

PowerShell (Windows):

```
cd "c:\\Users\\Admin\\Desktop\\AppEmotions"
flutter run
```

Windows Desktop (opcjonalnie):

```
flutter config --enable-windows-desktop
flutter run -d windows
```

Android (opcjonalnie):

```
# uruchom emulator lub podłącz urządzenie z debugowaniem USB
flutter devices
flutter run -d <ID_urzadzenia>
```

## Struktura
- `lib/main.dart` – minimalny punkt wejścia aplikacji (MaterialApp + pusty Home)
- `lib/pages/chat_page.dart` – chat UI z OpenAI (tekst + nagrywanie + TTS)
- `lib/services/openai_service.dart` – wywołania API: chat, STT (Whisper), TTS
- `test/widget_test.dart` – prosty smoke test uruchamiający aplikację
- `pubspec.yaml` – metadane i zależności

## Wymagania
- Flutter SDK 3.x (i kompatybilny Dart)
- Zainstalowane platformy docelowe wg potrzeb (Android SDK, Windows, iOS/macOS na odpowiednich systemach)

## Konfiguracja OpenAI

Bezpieczniej przekazać klucz przez `--dart-define` (nie zapisuj go w repozytorium):

PowerShell (Windows):

```
flutter run --dart-define=OPENAI_API_KEY=sk-... --dart-define=OPENAI_MODEL=gpt-4.1 --dart-define=OPENAI_TTS_MODEL=tts-1 --dart-define=OPENAI_STT_MODEL=whisper-1
```

Uwagi:
- Jeśli masz dostęp do nowszego modelu (np. gpt-5), podmień `OPENAI_MODEL=gpt-5`.
- Android: upewnij się, że emulator/urządzenie ma internet i pozwolenie na mikrofon.
- iOS: w `Info.plist` dodano opis użycia mikrofonu.

## Linki
- Flutter: https://docs.flutter.dev/
- OpenAI API: https://platform.openai.com/docs/

## Backend na Render (proxy dla OpenAI)

W repo dodałem folder `server/` (Express + OpenAI SDK) i plik `render.yaml` do automatycznego wdrożenia serwisu www na Render.

Szybki deploy (GUI):

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy?repo=https://github.com/kyng16/AEmotions)
1. Zaloguj się do https://render.com/ i wybierz New + From repo.
2. Wskaż to repo. Render odczyta `render.yaml` i zaproponuje serwis „app-emotions-backend”.
3. Ustaw zmienną środowiskową `OPENAI_API_KEY` (sekcja Environment).
4. Deploy.

Lokalnie (dev):
```
cd server
npm ci
setx OPENAI_API_KEY "sk-..."  # trwałe ustawienie w Windows; lub w sesji: $env:OPENAI_API_KEY='sk-...'
npm start
```

Po wdrożeniu ustaw w aplikacji adres backendu (lepiej przez dart-define, np.):
```
flutter run --dart-define=BACKEND_URL=https://twoj-backend.onrender.com --dart-define=OPENAI_MODEL=gpt-4.1
```

Serwer udostępnia:
- POST /chat  { messages: [...], model? }
- POST /stt   multipart/form-data: file, language?
- POST /tts   { text, voice?, format? } => audio/mpeg
