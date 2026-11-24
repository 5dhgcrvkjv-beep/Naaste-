# Checklist voor indienen

Werk van boven naar beneden. Vink af met `[x]`.

## 1. Invullen (verplicht)

- [ ] `[[AANBIEDER]]` vervangen door je naam of bedrijfsnaam (zoals in App Store Connect) in
      `site/privacy.html`, `site/voorwaarden.html` en `appstore/teksten.md` (copyright).
- [ ] `[[E-MAIL]]` vervangen door een supportadres in `site/privacy.html`, `site/voorwaarden.html`
      en `site/support.html`.
      Controle: `grep -rn "\[\[" site appstore` geeft niets meer.

## 2. Site online

- [ ] GitHub → repo → Settings → Pages → Source: **GitHub Actions**.
- [ ] Workflow "Site publiceren" draait na de volgende push (of start hem via Actions → Run workflow).
- [ ] Open en controleer:
      https://5dhgcrvkjv-beep.github.io/Naaste-/ ,
      …/privacy.html , …/voorwaarden.html , …/support.html
      (deze URL's staan ook in `Naaste/App/AppLinks.swift`).

## 3. Apple Developer en Xcode

- [ ] `DEVELOPMENT_TEAM` invullen in `project.yml` → `xcodegen`.
- [ ] Bundle-ID `nl.naaste.app` registreren (of een eigen ID; zie README voor de drie plekken).
- [ ] Capabilities op de App ID: iCloud (CloudKit, container `iCloud.nl.naaste.app`), Push Notifications.
- [ ] In Xcode → Signing & Capabilities: geen rode meldingen.
- [ ] Eén keer in Xcode bouwen, zodat de String Catalog de nieuwste teksten bevat.

## 4. CloudKit

- [ ] App één keer op een echt toestel draaien met iCloud (Development-omgeving), alle soorten
      gegevens aanmaken en delen, zodat het schema compleet is.
- [ ] CloudKit Console → container → Schema → **Deploy Schema Changes to Production**.
      Zonder deze stap werkt synchroniseren niet in de App Store-versie.

## 5. App Store Connect

- [ ] Nieuwe app: naam, primaire taal **Nederlands**, bundle-ID, SKU.
- [ ] Teksten en URL's uit `appstore/teksten.md` (controle: `python3 appstore/controleer.py`).
- [ ] Abonnementsgroep **Naaste Plus** met de twee producten uit `teksten.md`
      (product-ID's exact gelijk aan `NaasteKit/Sources/NaasteKit/Entitlements.swift`),
      prijzen, introductieaanbod, Gezinsdeling aan, lokalisatie en een **review-screenshot van de paywall**.
- [ ] Abonnementen toevoegen aan de eerste versie (sectie "In-app-aankopen en abonnementen").
- [ ] Overeenkomst voor betaalde apps, bank- en belastinggegevens: actief.
- [ ] App-privacy volgens `appstore/privacy-labels.md`.
- [ ] Leeftijdsclassificatie: 4+.
- [ ] Exportnaleving: geen niet-vrijgestelde versleuteling (`ITSAppUsesNonExemptEncryption` = NO staat al in Info.plist).
- [ ] Review notes uit `appstore/review-notes.md` + jouw contactgegevens.

## 6. Screenshots

Verplicht: iPhone 6,9" (1320 × 2868). Apple schaalt die voor kleinere formaten.

Maken in de simulator **iPhone 18 Pro Max** (6,9"), met de voorbeeld-naaste:

```bash
xcrun simctl launch booted nl.naaste.app -laadVoorbeeld -startTab overzicht
xcrun simctl io booted screenshot 01-overzicht.png
# herhaal met -startTab documenten | zaken | taken, en -takenWeergave uren
```

Tip: zet de statusbalk netjes met
`xcrun simctl status_bar booted override --time 9:41 --batteryLevel 100 --cellularBars 4`.
De voorbeeld-naaste bevat verzonnen gegevens; die mag je gewoon in de screenshots gebruiken.

## 7. Testen op een echt toestel (TestFlight)

- [ ] Brief scannen (camera, meerdere pagina's) en terugvinden via zoeken.
- [ ] PDF importeren uit Bestanden.
- [ ] Herinnering met tijdstip → melding komt een uur van tevoren en op tijd.
- [ ] Abonnement kopen, opzeggen en herstellen in de sandbox.
- [ ] Delen op twee toestellen met verschillende Apple ID's (zie README → Delen testen):
      uitnodigen, accepteren, wijziging zichtbaar bij de ander, verlaten, stoppen met delen.
- [ ] Alle gegevens wissen → ook verdwenen op een tweede toestel met dezelfde Apple ID.
- [ ] Dark mode en de grootste tekstgrootte doorlopen.
- [ ] VoiceOver: een document toevoegen, een taak afvinken, een zaak openen.
- [ ] Nieuwe installatie zonder iCloud: app werkt, delen geeft een duidelijke melding.

## 8. Archiveren en indienen

- [ ] Versie/build in `project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`) → `xcodegen`.
- [ ] Xcode → Product → Archive → Distribute App → App Store Connect.
- [ ] Build kiezen bij de versie, abonnementen gekoppeld, indienen voor review.
