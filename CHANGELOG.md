# Changelog

Belangrijke wijzigingen per release. Versies volgen Semantic Versioning; de datum is de releasedatum.

## [Unreleased]

## [0.1.1] - 2026-09-20

### Opgelost

- Selecties, cursor, knoppen, navigatie en Markdown-accenten gebruiken het Re:stacks-palet met terracotta en perzik, inclusief aangepaste kleuren voor donkere modus.
- HTML-export en print/PDF zijn beschikbaar zonder zichtbare preview; de app bereidt eerst de actuele tekst voor en opent daarna het native bewaar- of printvenster. De benodigde printtoestemming en asynchrone printafhandeling voorkomen geweigerde of lege PDF-uitvoer.
- Nieuw document, nieuwe map en hernoemen gebruiken compacte native macOS-dialogen met app-icoon, naamselectie en toetsenbordbediening.
- De Markdown-preview rendert weer in de gesandboxte app dankzij de benodigde WebKit-toestemming; laadfouten worden gemeld in plaats van stil een leeg vlak te tonen.
- Elke toolbarknop heeft een eigen toolbar-item en tooltipgebied, zodat de tooltip van een aangrenzende knop niet eerst wordt getoond.
- De documentselectie blijft bij het aangeklikte bestand terwijl de vorige tekst wordt opgeslagen en het nieuwe document wordt geladen, zonder kort terug te springen.
- De welkomstpagina en lege editor tonen het eigen RS Writer-icoon in plaats van het verwarrende A-met-tekstcursor-symbool.
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
