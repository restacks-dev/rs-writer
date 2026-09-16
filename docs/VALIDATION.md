# Validatie — 16 september 2026

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
- Developer ID-ondertekening, notarization en installatie op een andere Mac.
- Runtime op een Intel-Mac of macOS 14; de architectuur is wel gebouwd.
- PDF-printdialoog, HTML-export met lokale afbeeldingen en zeer grote bibliotheken.

UI-controles gebruikten `nl.rs.writer.smoke` als apart app-ID en de voorbeeldbibliotheek. De aangemaakte praktijktest is na afloop verwijderd. De productieapp en haar door de gebruiker geopende mapkeuze zijn niet gesloten.
