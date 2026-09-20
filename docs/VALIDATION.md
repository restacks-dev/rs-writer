# Validatie

## Herstel van maptoegang — 20 september 2026

- Vier geïsoleerde modelcontroles geslaagd tegen de productiecode: onbruikbare bookmark over twee starts, behouden herstelteksten, opnieuw kiezen en herstellen bij de volgende start, ontbrekende drive en een eerste installatie. De controles gebruiken tijdelijke mappen en eigen UserDefaults-suites.
- `scripts/test.sh` voert deze modelcontroles voortaan ook in CI uit. De modeltests zijn lokaal met de Command Line Tools uitgevoerd; de volledige lokale Xcode-build blijft geblokkeerd door de nog niet geaccepteerde Xcode-licentie.
- De startpagina biedt bij mislukte maprestauratie opnieuw de mapkiezer. Er wordt geen technische opstartalert getoond; een handmatige keuze die mislukt blijft wel een fout melden. De oorspronkelijke bookmark en herstelteksten blijven behouden totdat een map succesvol is gekozen.

## Ondertekende release — 19 september 2026

- GitHub-release `v0.1.0` gebouwd voor arm64 en x86_64, ondertekend met Developer ID en door Apple goedgekeurd. Zowel app als DMG hebben een notarization-ticket; Gatekeeper accepteert beide. De gedownloade DMG heeft de verwachte SHA-256-checksum.
- De lokale controle vond extra `com.apple.FinderInfo` op de appbundle door `hide_extensions`. Gatekeeper accepteerde de app, maar `codesign --verify --deep --strict` wees die metadata af, ook na kopiëren uit de DMG. Verwijderen van uitsluitend die metadata laat de bestaande handtekening weer slagen.
- Voor `0.1.1` zet de verpakking geen FinderInfo meer op de appbundle. `make-dmg.sh` controleert de strikte handtekening ook binnen de gemounte, definitieve DMG, voordat die naar de publicatiestap gaat.
- Installatie op een andere fysieke Mac is nog niet getest.

## Releaseverpakking — 19 september 2026

- Zeven releaseveiligheidstests geslaagd: versie/changelog-validatie, ontbrekende credentials, exacte Apple-status en keychain-cleanup bij fouten. Actionlint 1.7.12, shellsyntax, plist-validatie en `git diff --check` geslaagd.
- Definitieve minimale DMG in Finder geopend zoals bij normale installatie: crèmekleurige achtergrond, vlak app-icoon, Applications en sleeppijl zichtbaar; geen extra teksten of HTML-bestand, niets afgeknipt. Venster 720 × 392 inclusief titelbalk.

- `scripts/make-dmg.sh` en `scripts/preview-dmg.sh`: shellsyntax gecontroleerd; bestaande output, ontbrekende app en een verkeerd uitvoerformaat worden geweigerd.
- Echte previews gebouwd, laatst `RS-Writer-v3-UNSIGNED-PREVIEW.dmg`, met vastgepinde `dmgbuild` 1.6.7, zonder Finder/AppleScript tijdens de build.
- `hdiutil verify` geslaagd; de uiteindelijke DMG opnieuw read-only gemount en gecontroleerd op app-executable, `Applications → /Applications`, exacte bytes van de achtergrond, plus `.DS_Store` met afbeelding als achtergrond en de bedoelde icoonposities. Exact twee zichtbare items aanwezig: de app en Applications.
- In Finder zijn achtergrond, vlakke app-icoon en icoonposities van een eerdere preview visueel gecontroleerd. De definitieve achtergrond is daarna vereenvoudigd tot een rustige sleep-naar-Apps-indeling. De definitieve vensterhoogte is 392 punten om naast de 360 punten hoge achtergrond ook ruimte te bieden aan de titelbalk; het script controleert deze vensterafmetingen mee.
- De preview gebruikt een kopie van de bestaande universele 0.1.0-build met het nieuwe vlakke icoon, een aparte preview-bundle identifier en ad-hoc-handtekening. De bestaande app is niet gewijzigd. Dit is geen nieuwe compilatie en geen bewijs van Developer ID-ondertekening of notarization.
- Een nieuwe lokale Xcode-build is geblokkeerd doordat de Xcode-licentie nog niet is geaccepteerd. De licentie is niet automatisch geaccepteerd. Het maken van de DMG lukte wel via macOS-schijfservices buiten de sandbox.
- Bovenstaande previewcontroles gingen vooraf aan de ondertekende release; zie de releasevalidatie bovenaan voor signing en notarization.

## Appvalidatie — 16 september 2026

## Geslaagd

- Debug-build met Xcode 26.5 / Swift 6.3.2, deployment target macOS 14.
- Release-build via `scripts/build.sh`, universeel `x86_64 arm64`.
- `codesign --verify --deep --strict`: geldige lokale ad-hoc-handtekening.
- Hardened Runtime aanwezig. Release-entitlements: App Sandbox, user-selected read/write en app-scoped bookmarks. Geen `get-task-allow` in de release.
- 10 Swift Package-tests, 0 fouten: veilige create/rename, gewone save, gelijke remote save, conflictbehoud, ontbrekende documenten, ontbrekende map, mapscan/symlinks, ongeldige namen/UTF-8, koppen buiten codeblokken, Unicode/CRLF en herstel met oorspronkelijke baseline.
- Native UI: nieuw document aangemaakt, Markdown geplakt, opgeslagen en de daadwerkelijke bestandsbytes gecontroleerd.
- Preview: koppen, vet, cursief, checkbox en tabel zichtbaar; een ingevoegd script is verwijderd en niet uitgevoerd.
- Externe wijziging van het testbestand verschijnt automatisch in editor en preview.
- Visuele controle van de uiteindelijke kolombreedtes en editor.
- Aparte release-testkopie met sandbox-entitlements: bibliotheek gekozen via NSOpenPanel, app afgesloten en herstart. Bibliotheek en document zijn zonder nieuwe mapkeuze hersteld.

## Nog niet end-to-end geverifieerd

- Synchronisatie tussen twee fysieke Macs met iCloud Drive of Proton Drive.
- Installatie op een andere fysieke Mac.
- Runtime op een Intel-Mac of macOS 14; de architectuur is wel gebouwd.
- PDF-printdialoog, HTML-export met lokale afbeeldingen en zeer grote bibliotheken.

UI-controles gebruikten `nl.rs.writer.smoke` als apart app-ID en de voorbeeldbibliotheek. De aangemaakte praktijktest is na afloop verwijderd. De productieapp en haar door de gebruiker geopende mapkeuze zijn niet gesloten.
