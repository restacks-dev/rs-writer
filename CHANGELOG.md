# Changelog

Belangrijke wijzigingen per release. Versies volgen Semantic Versioning; de datum is de releasedatum.

## [Unreleased]

## [0.1.1] - 2026-09-20

### Opgelost

- Bij onbruikbare opgeslagen maptoegang vraagt de app om de bibliotheek opnieuw te kiezen, zonder technische foutmelding bij het starten. Documenten en herstelteksten blijven behouden.
- De DMG bewaart de app-handtekening zonder extra Finder-metadata op de appbundle.
- De release controleert nu ook de strikte handtekening van de app binnen de uiteindelijke DMG.

## [0.1.0] - 2026-09-19

### Nieuw

- Native Markdown-schrijfapp voor macOS 14 en nieuwer, met een universele app voor Apple Silicon en Intel.
- Bibliotheek, automatisch opslaan, conflictbehoud, focusmodi, Markdown-preview en HTML/PDF-export.
- Vlak app-icoon in de crème- en terracottakleuren van Re:stacks.
- Minimalistische installatieschijf met bijpassende achtergrond en sleep-naar-Apps-installatie.
- GitHub-releaseflow met changelog, SHA-256-checksum en downloadbare DMG. Publicatie volgt uitsluitend na Developer ID-ondertekening, Apple-notarization, stapling en verificatie.

### Bekende beperkingen

- Synchronisatie loopt via je eigen iCloud Drive- of Proton Drive-map; RS Writer heeft geen eigen clouddienst.
- Gelijktijdig offline bewerken op verschillende Macs kan extra conflicten bij de clouddienst veroorzaken.
