# Naaste

Een gedeelde zorgmap voor families die samen zorgen voor een ouder of naaste.
Naaste regelt de **administratie**: contactpersonen, documenten (Wmo, Wlz/CIZ, pgb, CAK …),
aanvragen met tijdlijn, deadlines, taken, uren en een overdrachtsoverzicht.
Geen medische app, geen chat-app, geen eigen server: alles staat op de iPhone en in iCloud.

## Bouwen

Nodig: een Mac met **Xcode 26** (iOS 26 SDK) en [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen            # maakt Naaste.xcodeproj uit project.yml
open Naaste.xcodeproj
```

Vóór de eerste build op een echte iPhone:

1. Vul in `project.yml` bij `DEVELOPMENT_TEAM` je Team ID in (of kies je team in Xcode → Signing & Capabilities) en draai `xcodegen` opnieuw.
2. Is de bundle-ID `nl.naaste.app` al bezet? Kies een eigen ID en pas die aan op drie plekken:
   - `project.yml`;
   - `Naaste/Naaste.entitlements` (iCloud-container `iCloud.<bundle-id>`);
   - `PersistenceController.cloudKitContainerID`.

   De product-ID's in `NaasteKit/Sources/NaasteKit/Entitlements.swift` en `Naaste/Resources/Naaste.storekit` mogen blijven zoals ze zijn.
3. Abonnementen testen in de simulator: het schema gebruikt `Naaste.storekit`, dus kopen, verlengen en opzeggen werkt lokaal.

## Tests

- Logica (limieten, abonnementsstatus, herinneringen, zoeken, uren). Dit draait ook zonder Xcode:
  ```bash
  cd NaasteKit && swift test
  ```
- Datamodel, voorbeeld-data en PDF in Xcode: **⌘U** (target `NaasteTests`, Swift Testing).

Alleen in Debug-builds (handig voor screenshots):
`xcrun simctl launch booted nl.naaste.app -laadVoorbeeld -startTab documenten`
laadt de voorbeeld-naaste en opent direct een tabblad (`overzicht`, `documenten`, `zaken`, `taken`, `instellingen`).
Met `-takenWeergave uren` opent het tabblad Taken direct op het urenlogboek.

## Structuur

```
project.yml                 XcodeGen-projectdefinitie (iOS 18+)
NaasteKit/                  platformonafhankelijke logica + tests (Swift Package)
Naaste/
  App/                      app-start, tabbladen, AppModel, links
  Model/                    Core Data-model (CloudKit), opslag, queries, voorbeeld-data
  Services/                 Store (StoreKit 2), PDF, Documenten (scanner, tekstherkenning), Herinneringen (lokale meldingen), (straks) Sharing
  Features/                 schermen per functie
  DesignSystem/             gedeelde componenten
  Resources/                Info.plist, String Catalog, Privacy Manifest, StoreKit-config, assets
NaasteTests/                tests op het datamodel
site/                       privacybeleid en voorwaarden (GitHub Pages)
appstore/                   App Store-teksten, privacy-labels, review notes, checklist
```

## Waarom Core Data en niet SwiftData?

Delen met familie gaat via CloudKit-sharing (CKShare). SwiftData ondersteunt de gedeelde
CloudKit-database niet; `NSPersistentCloudKitContainer` wel (privé- én gedeelde opslag).

## Bouwfasen

| Fase | Inhoud | Status |
|---|---|---|
| 1 | Project, datamodel, opslag, voorbeeld-data, tests | ✅ |
| 2 | Overzicht, profiel, contactpersonen (bellen/mailen), familieleden | ✅ |
| 7 | StoreKit 2, paywall, limieten, Instellingen-abonnement | ✅ (vroeg gebouwd, alle functies gebruiken het) |
| 3 | Documenten: scannen, PDF-import, mappen, tekstherkenning, zoeken | ✅ |
| 4 | Zaken met tijdlijn, herinneringen en notificaties | ✅ |
| 5 | Taken en urenlogboek | ✅ |
| 6 | Delen via CloudKit, stoppen met delen, alle gegevens wissen | ⏳ |
| 8 | PDF-exports (uren, overdracht) | ⏳ |
| 9 | Onboarding, toegankelijkheid, laatste controle | ⏳ |
| 10 | App Store-teksten, site, privacy-labels, review notes, checklist | ⏳ |
