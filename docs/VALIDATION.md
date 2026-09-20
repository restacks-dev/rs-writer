# Validatie

## Re:stacks-accentkleuren — 20 september 2026

- Het gedeelde `BrandPalette` vervangt de turquoise kleuren in navigatie, toolbar, status, editorcursor, code/links en de Markdown-preview. Tekstselecties hebben een warme achtergrond met de gewone leesbare tekstkleur. Licht gebruikt terracotta `#A34F39`; donker gebruikt perzik `#E99A83`.
- Een `AccentColor`-asset met lichte en donkere variant is ingesteld als globale accentkleur voor native controls. De XcodeGen-bron en het gegenereerde project zijn bijgewerkt. SwiftUI-schermen krijgen dezelfde expliciete tint.
- Volledige lokale Swift-appcompilatie met SDK 26.5, gesandboxte preview-/HTML-/PDF-/native-printchecks en `git diff --check` geslaagd. De lokale CLT-build compileert geen assetcatalogus; die stap blijft onderdeel van de Xcode-build.
- Voor de release is de testapp alsnog visueel gecontroleerd in lichte modus: warme tekstselectie, terracotta navigatie-/sorteeraccenten en statusindicator. De controle in donkere modus en van de door Xcode gecompileerde globale accentkleur staat nog open.

## HTML-export en print/PDF — 20 september 2026

- Beide acties zijn beschikbaar bij een geopend document, ook als de Markdown-preview dicht staat. Dit geldt voor het toolbar-menu, het Archief-menu en ⌘P. Een afzonderlijke renderer verwerkt de actuele tekst voordat het bewaar- of printvenster opent.
- De native printtest vond daarnaast ontbrekende sandbox-printrechten en lege PDF-uitvoer. `com.apple.security.print` is toegevoegd conform [Apple's print-entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.print). De printweergave krijgt een eigen onzichtbaar venster; de printoperatie loopt asynchroon als native sheet, zodat WebKit zijn werk kan afronden. De documentnaam wordt gebruikt als voorgestelde PDF-naam.
- De gesandboxte regressietest controleert HTML zonder vooraf geopende preview, actuele tekst, sanitization, een lege export zonder previewhulptekst, WebKit-PDF en de echte native printoperatie naar een tijdelijke PDF. PDFKit bevestigt dat de verwachte documenttekst aanwezig is. Alle controles geslaagd.
- End-to-end in de aparte testapp met gesloten preview: HTML opgeslagen via het bewaarvenster; ⌘P opent de native printsheet en ‘Bewaar als pdf…’ slaat `Example.pdf` op. De HTML en de PDF van één pagina bevatten de juiste kop en tekst. Geen afdruk naar een fysieke printer verstuurd.
- Volledige appcompilatie geslaagd met de macOS 26.5 SDK. Geen nieuwe release gemaakt.

## Native naamdialogen — 20 september 2026

- De zelfgemaakte SwiftUI-sheet vervangen door een standaard AppKit-sheet (`NSAlert`) met het app-icoon en één compact naamveld. Nieuw document, nieuwe map en hernoemen gebruiken dezelfde presentatie; AppKit bepaalt lay-out en toetsenbordgedrag.
- Een afzonderlijke app lokaal gecompileerd met de macOS 26.5 Command Line Tools, sandbox en eigen bundle-ID `nl.rs.writer.ui-check`. Visueel gecontroleerd: compact venster, eigen icoon, doelmap en vooraf geselecteerde naam. Een lege naam schakelt bevestigen uit.
- Via de echte UI in een aparte voorbeeldmap geverifieerd: nieuw document aanmaken met Enter, openen met ⌘N, annuleren met Escape, een map aanmaken en een document hernoemen. Bestanden bestaan op de verwachte plek. De testapp is daarna gesloten; de productieapp en gebruikersdocumenten zijn niet aangepast.
- Volledige Swift-typecontrole en lokale appcompilatie geslaagd. Geen nieuwe release gemaakt.

## Markdown-preview — 20 september 2026

- De lege preview gereproduceerd in een apart gesandboxt appbundle met de productiecontroller en oorspronkelijke entitlements: na 15 seconden geen pagina, geen inhoud en geen foutmelding. Met alleen de aanvullende `com.apple.security.network.client`-toestemming renderde dezelfde test direct.
- Die WebKit-toestemming is toegevoegd; de bestaande CSP en DOMPurify-filtering blijven actief. Navigatiefouten en het stoppen van het WebKit-inhoudsproces worden nu gemeld.
- `scripts/test-preview.sh` bouwt een apart appbundle met de echte parserbestanden, Hardened Runtime en productie-entitlements. De test slaagt voor koppen, vet, taken, tabel, gewone tekst en live updates, verwijdering van scripts/eventhandlers, wisselen van documentmap, relatieve lokale afbeeldingen en een leeg document.
- Deze gesandboxte WebKit-test is opgenomen in `scripts/test.sh` voor CI en releases. Volledige Swift-typecontrole, zeven releaseveiligheidstests en entitlement-/shellvalidatie geslaagd. Geen nieuwe release gemaakt.

## Tooltips in de toolbar — 20 september 2026

- Elke knop heeft een afzonderlijk `ToolbarItem` met stabiele identifier en eigen helptekst. De gedeelde HStack binnen één toolbar-item is verwijderd; ook het actiemenu heeft nu een expliciete tooltip en toegankelijkheidsnaam.
- Volledige Swift-typecontrole geslaagd met de macOS 26.5 SDK van de Command Line Tools. Het hovergedrag moet nog visueel in de gebouwde app worden gecontroleerd; er is geen nieuwe release gemaakt.

## Documentselectie — 20 september 2026

- De lijst volgt de aangeklikte URL meteen; de editor houdt de vorige document-URL aan tot opslaan en laden zijn afgerond. De tijdelijke selectie wordt daarna vrijgegeven, ook bij fouten.
- Vier regressiecontroles geslaagd: directe selectie met opslaan naar het vorige bestand, conflictbehoud zonder tussentijdse selectiewissel, mislukte save met behouden hersteltekst en een mislukt leesverzoek met terugkeer naar het vorige document. Samen met de maptoegangcontroles slagen alle acht modelchecks.
- Volledige Swift-typecontrole geslaagd met de macOS 26.5 SDK van de Command Line Tools; alleen de bestaande deprecation-waarschuwing in MarkdownPreview. Nog geen nieuwe release of visuele verificatie van deze wijziging in een gebouwde app.

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
- HTML-export met lokale afbeeldingen en zeer grote bibliotheken. De PDF-printdialoog is inmiddels wel gecontroleerd; zie de exportvalidatie bovenaan.

UI-controles gebruikten `nl.rs.writer.smoke` als apart app-ID en de voorbeeldbibliotheek. De aangemaakte praktijktest is na afloop verwijderd. De productieapp en haar door de gebruiker geopende mapkeuze zijn niet gesloten.
