# Artemide Duo for iOS
Port von Artemide Duo für Android (gersiaaan/artemide-duo, Branch `duo`) auf Basis von moonlight-ios. Branch: `artemide`. Version in `IOS_VERSION`.
Ziel: gleiche Funktionen, Einstellungen, UI und Animationen wie Android – aber native iOS-Optik mit Systemschrift (SF Pro), nicht Inter.
Geräte des Nutzers: iPad Pro 11 (2018) mit Magic Keyboard 1, iPhone 13 mini, iPhone 15 Pro Max. Installation per iLoader (IPA).

## Arbeitsregeln (vom Nutzer)
- Antworten auf Deutsch, locker, kurz.
- Feedback des Nutzers sofort in `FEEDBACK.md` eintragen – NICHT sofort umsetzen/bauen.
- Gebaut wird nur, wenn der Nutzer "build" sagt. Dann: ALLE offenen Punkte aus `FEEDBACK.md` umsetzen, Version erhöhen, committen, pushen, CI prüfen bis grün, danach `FEEDBACK.md` leeren (unter "Letzter Build" Version eintragen) und kurz auf Deutsch berichten.
- Niemals IP-Adressen oder Hostnamen des Nutzers in Code, Commits, Screenshots oder Texte schreiben (Platzhalter: "Gaming-PC", "LAN").
- Code lesen statt raten; nur die Dateien öffnen, die für die Aufgabe nötig sind.

## Build
- Lokal (Mac): `xcodebuild -project Moonlight.xcodeproj -scheme Moonlight -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO build`
- CI (`.github/workflows/build.yml`): unsigniertes Archiv, IPA als Prerelease `ios-v<ver>-<run>`. Logs sind evtl. nicht abrufbar → Fehler über Annotations lesen:
  `gh api repos/gersiaaan/Artemide-Duo-for-iOS/check-runs/<JOB>/annotations --jq '.[] | select(.title=="All errors") | .message'`
- Executable heißt `ArtemideDuo`, `PRODUCT_MODULE_NAME` bleibt `Moonlight` (wegen `Moonlight-Swift.h`). Bundle-ID `com.gersiaaan.artemideduo`.

## Code-Landkarte
- Duo-UI: `Limelight/ViewControllers/Duo*.{h,m}` (DuoSupport = Theme/Prefs/Helfer, DuoHomeView, DuoAppsView, DuoSettingsViewController, DuoPad = Controller- + GCKeyboard-Navigation, DuoStreamMenu, DuoConnectOverlay).
- Stream: `StreamFrameViewController.m`, `Limelight/Stream/` (VideoDecoderRenderer, DuoMetalRenderer = MetalFX per dlopen), `Limelight/Input/` (ControllerSupport, StreamView, KeyboardSupport, RelativeTouchHandler).
- Einstellungen: alle in `DuoPrefs` (NSUserDefaults, Keys `duo_*`).

## Fallen
- Neue Dateien in `Moonlight.xcodeproj/project.pbxproj` registrieren (FileRef + BuildFile im iOS-Sources-Phase); eigene IDs nach Schema `D0A0D0A0…A1/B1`.
- KEIN `becomeFirstResponder`/`canBecomeFirstResponder`/`keyCommands` auf MainFrame oder Settings → schwarzer Bildschirm beim Start. Tastatur läuft über GCKeyboard in DuoPad.
- ARC: kein `&_ivar` als Out-Parameter (Local nehmen), kein `weak->ivar` (in Settings-Blöcken `__unsafe_unretained`).
- In ObjC-String-Literalen `\n` nicht per Python-Heredoc als echten Zeilenumbruch einfügen.
- Client-ID/Gerätename eigen (`DuoPrefs clientId/clientName`) – nie wieder Moonlights feste uniqueid.
