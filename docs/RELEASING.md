# Releases maken

Een release begint met een commit waarin de wijzigingen en het changelog compleet zijn. Een tag `vX.Y.Z` start de GitHub Actions-workflow. Die bouwt een universele app, ondertekent hem met Developer ID, laat Apple de app en DMG notarizen, voegt de tickets toe en controleert de resultaten. Pas daarna verschijnt de GitHub Release met DMG en checksum. De repository hoeft daarvoor niet openbaar te worden.

## Eenmalige inrichting

Benodigd: een betaald Apple Developer-account, een **Developer ID Application**-certificaat met bijbehorende private key, je Team ID, en een Apple-account dat mag notarizen. Voor lokale builds is volledige Xcode nodig. Accepteer de Xcode-licentie zelf via Xcode wanneer Apple daarom vraagt; scripts doen dit niet automatisch.

1. Open **Sleutelhangertoegang → Mijn certificaten**. Klap het juiste Developer ID Application-certificaat open en controleer dat er een private key bij staat. Exporteer certificaat en sleutel als een met een sterk wachtwoord beveiligd `.p12`-bestand. Een `.cer` zonder private key is niet voldoende.
2. Maak bij [je Apple-account](https://account.apple.com/) een app-specifiek wachtwoord voor notarization. Gebruik niet je gewone Apple-wachtwoord. Je Apple-account heeft tweefactorauthenticatie nodig.
3. Open in deze GitHub-repository **Settings → Secrets and variables → Actions → New repository secret** en sla onderstaande waarden op. Bewaar secrets uitsluitend daar of in een wachtwoordmanager, nooit in broncode, issues, chat of shellgeschiedenis.

| GitHub Actions-secret | Waarde |
| --- | --- |
| `APPLE_CERTIFICATE_BASE64` | Base64 van het geëxporteerde `.p12`-bestand, inclusief private key |
| `APPLE_CERTIFICATE_PASSWORD` | Het exportwachtwoord van dat `.p12`-bestand |
| `APPLE_SIGNING_IDENTITY` | Volledige certificaatnaam, bijvoorbeeld `Developer ID Application: Bedrijfsnaam (ABCDEFGHIJ)` |
| `APPLE_TEAM_ID` | Je Apple Team ID van 10 hoofdletters/cijfers |
| `APPLE_ID` | Het Apple-account waarmee je notarizet |
| `APPLE_APP_SPECIFIC_PASSWORD` | Het app-specifieke Apple-wachtwoord |

Je kunt het base64-gecodeerde certificaat op macOS direct naar het klembord kopiëren, zonder het in terminaluitvoer te tonen:

```sh
base64 -i /pad/naar/DeveloperID.p12 | pbcopy
```

Plak dit in `APPLE_CERTIFICATE_BASE64` en wis daarna het klembord. Bewaar het originele certificaat veilig buiten de repository. De workflow gebruikt een tijdelijke sleutelhanger en verwijdert die ook bij een mislukte run. De automatische `GITHUB_TOKEN` van Actions verzorgt publicatie; een persoonlijk GitHub-token is niet nodig.

Houd bundle identifier `nl.rs.writer` en dezelfde Apple Team ID consistent tussen releases, zodat updates bij dezelfde app blijven horen. Wijzig de identifier niet voor elke release.

## Na een batch wijzigingen

1. Rond de wijzigingen af en voer `./scripts/test.sh` uit.
2. Verplaats de relevante punten uit `[Unreleased]` naar een nieuw blok in `CHANGELOG.md`, exact in deze vorm: `## [0.2.0] - 2026-09-20`. Gebruik de werkelijke versie en releasedatum. Laat een leeg `[Unreleased]`-blok bovenaan staan.
3. Zet `MARKETING_VERSION` in `project.yml` op dezelfde versie, voer `xcodegen generate` uit en neem ook het gewijzigde `RSWriter.xcodeproj/project.pbxproj` mee in de commit. De tag, het changelog en beide projectbestanden moeten overeenkomen. Het buildnummer wordt tijdens de workflow gezet. Voor de eerste release staat `0.1.0` al klaar.
4. Controleer vooraf met `./scripts/release-notes.sh v0.1.0` (pas de versie aan). Commit en push daarna alle wijzigingen naar de releasebranch. Maak en push vervolgens een nieuwe tag, bijvoorbeeld:

   ```sh
   git tag -a v0.1.0 -m 'RS Writer 0.1.0'
   git push origin v0.1.0
   ```

5. Bekijk de workflow onder **Actions**. Ontbrekende secrets, een ongeldige handtekening of een geweigerde notarization stoppen de release. Er wordt dan geen downloadbare release gepubliceerd. Los de oorzaak op voordat je een nieuwe release probeert; verplaats geen tag die al een gepubliceerde release heeft.
6. Download na succes de DMG via **Releases** en controleer de installatie op een andere Mac. Ontvangers hebben bij een private repository GitHub-toegang nodig om de release te downloaden.

De release bevat `RS-Writer-X.Y.Z-universal.dmg`, `SHA256SUMS` en `RELEASE_NOTES.md`. De releasebeschrijving begint met het bijbehorende changelogblok; tijdens publicatie worden automatisch door GitHub gegenereerde PR-, contributor- en wijzigingsnotities toegevoegd. De minimalistische DMG toont de app en de map Apps met een pijl ertussen. De lokaal gebouwde `dist/RELEASE_NOTES.md` bevat alleen het eigen changelog tot de publicatiestap de GitHub-notities toevoegt. Na downloaden in dezelfde map kun je de checksum controleren met:

```sh
shasum -a 256 -c SHA256SUMS
```

## Installatie en macOS-controles

Open de DMG, sleep **RS Writer** naar **Applications / Apps**, werp de installatieschijf uit en open RS Writer vanuit Apps. Sluit bij een update eerst de bestaande app af en vervang die daarna; je documenten blijven in je eigen bibliotheekmap staan.

Developer ID en notarization voorkomen de blokkade wegens een onbekende ontwikkelaar of ontbrekende Apple-controle bij een geldige release. macOS kan bij de eerste start nog de normale bevestiging tonen dat de app van internet is gedownload. Een volledige afwezigheid van elke macOS-melding is niet te garanderen. De releaseflow schakelt Gatekeeper nergens uit.

## Alleen de DMG-vormgeving lokaal bekijken

De verpakking wordt headless gemaakt met vastgepinde `dmgbuild`-dependencies uit `packaging/requirements.txt`, zonder een geopende Finder-sessie of AppleScript. Python 3.10 of nieuwer is vereist. Het eerste gebruik maakt een virtualenv onder `build/` en downloadt de dependencies. Daarna gebruikt het script de bestaande omgeving.

```sh
./scripts/build.sh
./scripts/preview-dmg.sh
# Of met een bestaande lokale app:
./scripts/preview-dmg.sh '/pad/naar/RS Writer.app'
```

De preview staat uitsluitend in `build/preview/RS-Writer-UNSIGNED-PREVIEW.dmg`; ook de volumenaam vermeldt `UNSIGNED PREVIEW`. Dit script ondertekent of notarizet niets en publiceert niets. Gebruik dit bestand alleen om de vormgeving te controleren. Het script weigert een bestaand bestand te overschrijven; verwijder de vorige preview bewust voor een nieuwe poging.

`scripts/make-dmg.sh APP_PATH OUTPUT_DMG` is de gedeelde verpakkingsstap. Het controleert de gemounte DMG op de app, de verwijzing naar `/Applications`, de achtergrond en de opgeslagen Finder-instellingen. Zonder correcte vormgeving faalt het script; er is geen kale DMG als fallback.

Zie [VALIDATION.md](VALIDATION.md) voor wat lokaal daadwerkelijk is gecontroleerd. Apple-documentatie: [Developer ID](https://developer.apple.com/developer-id/), [notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [app-specifieke wachtwoorden](https://support.apple.com/en-us/102654), [de eerste keer openen](https://support.apple.com/en-us/102445). Packaging: [dmgbuild-instellingen](https://dmgbuild.readthedocs.io/en/latest/settings.html).
