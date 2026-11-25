# Checklist voor indienen

Werk van boven naar beneden. Vink af met `[x]`.

## 0. Vooraf regelen

- [ ] **Naam vastleggen**: zodra het Developer-account er is, de app aanmaken in App Store Connect
      (zie 5). Daarmee is "Naaste" van jou. Is de naam bezet, dan een variant kiezen
      (bijv. "Naaste – zorgadministratie") en die ook in `teksten.md` en de site aanpassen.
- [ ] **Merk controleren** in het merkenregister van het BOIP (boip.int): heeft niemand "Naaste"
      vastgelegd voor software/apps (klasse 9 en 42)?
- [ ] **Belasting**: inkomsten uit abonnementen opgeven bij de inkomstenbelasting. Btw in de EU
      regelt Apple. Vraag een boekhouder of kijk op belastingdienst.nl ("Ben ik ondernemer?").
- [ ] **Prijzen** in `teksten.md` controleren (nu € 3,99 per maand en € 34,99 per jaar met 2 weken gratis).

## 1. Invullen (verplicht)

- [x] `[[AANBIEDER]]` vervangen door je naam of bedrijfsnaam (zoals in App Store Connect) in
      `site/privacy.html`, `site/voorwaarden.html` en `appstore/teksten.md` (copyright).
- [x] `[[E-MAIL]]` vervangen door een supportadres in `site/privacy.html`, `site/voorwaarden.html`
      en `site/support.html`.
      Controle: `grep -rn "\[\[" site appstore` geeft niets meer.

- [ ] **Handelaarsstatus (EU, DSA)**: omdat Naaste Plus betaald is, geef je je in App Store Connect op als
      handelaar. Apple toont dan adres, telefoonnummer en e-mail op de App Store-pagina. Wil je je
      thuisadres niet tonen, regel dan een zakelijk adres (bijv. via een KvK-inschrijving).

## 2. Site online

- [x] GitHub → repo → Settings → Pages → Source: **GitHub Actions**.
- [x] Workflow "Site publiceren" draait na elke push naar `site/` (of via Actions → Run workflow).
- [x] Online en bereikbaar (alle vier de pagina's). Na het invullen van stap 1 opnieuw controleren:
      https://5dhgcrvkjv-beep.github.io/Naaste-/ ,
      …/privacy.html , …/voorwaarden.html , …/support.html
      (deze URL's staan ook in `Naaste/App/AppLinks.swift`).

## 3. Apple Developer en Xcode

- [x] Betaald lidmaatschap van het Apple Developer Program (€99 per jaar). Met een gratis Apple ID
      kan alleen de testversie "Naaste Lokaal" (zonder iCloud) op je eigen iPhone.

- [x] `DEVELOPMENT_TEAM` invullen in `project.yml` → `xcodegen`.
- [x] Bundle-ID `nl.naaste.app` registreren (of een eigen ID; zie README voor de drie plekken).
- [x] Capabilities op de App ID: iCloud (CloudKit, container `iCloud.nl.naaste.app`), Push Notifications.
- [ ] In Xcode → Signing & Capabilities: geen rode meldingen.
- [ ] Eén keer in Xcode bouwen, zodat de String Catalog de nieuwste teksten bevat.

## 3b. Betalingen (zonder dit verschijnt Naaste Plus niet in de app)

In App Store Connect → **Business** (Agreements, Tax, and Banking):

- [x] **Paid Apps Agreement** ondertekenen.
- [ ] **Bankgegevens**: IBAN, naam precies zoals bij de bank.
- [ ] **Belastingformulier W-8BEN**: niet in de VS wonend, beroep op het belastingverdrag
      Nederland–VS. Dan houdt Apple geen Amerikaanse belasting in.
- [ ] **Handelaarsstatus** opgegeven (zie 1).
- [ ] Status van de overeenkomst is **Active**.
- [ ] **App Store Small Business Program** aanmelden (15% commissie in plaats van 30%):
      developer.apple.com/app-store/small-business-program. Gaat niet vanzelf.

Uitbetaling: maandelijks, ongeveer 33 dagen na het einde van de maand, vanaf een minimumbedrag.

## 4. CloudKit

- [x] App één keer op een echt toestel draaien met iCloud (Development-omgeving), alle soorten
      gegevens aanmaken en delen, zodat het schema compleet is.
- [x] CloudKit Console → container → Schema → **Deploy Schema Changes to Production**.
      Zonder deze stap werkt synchroniseren niet in de App Store-versie.

## 5. App Store Connect

- [ ] Nieuwe app: naam, primaire taal **Nederlands**, bundle-ID, SKU.
- [ ] Teksten en URL's uit `appstore/teksten.md` (controle: `python3 appstore/controleer.py`).
- [ ] Abonnementsgroep **Naaste Plus** met de twee producten uit `teksten.md`
      (product-ID's exact gelijk aan `NaasteKit/Sources/NaasteKit/Entitlements.swift`),
      prijzen, introductieaanbod, lokalisatie en een **review-screenshot van de paywall**.
      - `nl.naaste.app.plus.maand`: 1 maand
      - `nl.naaste.app.plus.jaar`: 1 jaar, introductieaanbod 2 weken gratis
- [ ] **Gezinsdeling** aan op beide producten (kan daarna niet meer uit; de app rekent erop).
- [ ] Abonnementen toevoegen aan de eerste versie (sectie "In-app-aankopen en abonnementen").
- [ ] **Sandbox-testaccount** aanmaken: Users and Access → Sandbox (e-mailadres dat nog geen Apple ID is).
      Op de iPhone: Instellingen → App Store → Sandbox-account.
- [ ] App-privacy volgens `appstore/privacy-labels.md`.
- [ ] Leeftijdsclassificatie: 4+.
- [ ] **Beschikbaarheid: alleen Nederland** (Prijzen en beschikbaarheid → landen). De app is ingericht op
      het Nederlandse zorgsysteem (Wmo, Wlz/CIZ, pgb, CAK). België/Vlaanderen komt later, met een landkeuze in de app.
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

- [ ] **TestFlight met familie**: een paar familieleden uitnodigen (maximaal 10.000 externe testers, na een korte controle door Apple)
      en een week echt laten gebruiken, vooral delen.
- [ ] **Oudste iOS-versie**: de app werkt vanaf iOS 18 maar is alleen op iOS 27 getest. Test via
      TestFlight op minstens één iPhone met iOS 18 (bijv. van een familielid).

- [ ] Brief scannen (camera, meerdere pagina's) en terugvinden via zoeken.
- [ ] PDF importeren uit Bestanden.
- [ ] Herinnering met tijdstip → melding komt een uur van tevoren en op tijd.
- [ ] Abonnement kopen, opzeggen en herstellen met het sandbox-account (abonnementen lopen versneld:
      een maand duurt een paar minuten). Ook: Plus via Gezinsdeling, en Plus van de eigenaar bij een
      gedeelde zorgmap.
- [ ] Delen op twee toestellen met verschillende Apple ID's (zie README → Delen testen):
      uitnodigen, accepteren, wijziging zichtbaar bij de ander, verlaten, stoppen met delen.
- [ ] Alle gegevens wissen → ook verdwenen op een tweede toestel met dezelfde Apple ID.
- [ ] Dark mode en de grootste tekstgrootte doorlopen.
- [ ] VoiceOver: een document toevoegen, een taak afvinken, een zaak openen.
- [ ] Nieuwe installatie zonder iCloud: app werkt, delen geeft een duidelijke melding.
- [ ] Face ID-vergrendeling aan: app-kiezer toont het slot, na de achtergrond opnieuw ontgrendelen.
- [ ] Spotlight: zoek op tekst uit een gescande brief, tik op het resultaat.
- [ ] Snelle acties op het app-icoon (ook terwijl de app vergrendeld is).
- [ ] Zet in agenda: herinnering met herhaling, vervolgdatum van een zaak.
- [ ] Reservekopie met wachtwoord maken, app verwijderen, opnieuw installeren en terugzetten.

## 8. Archiveren en indienen

- [ ] Versie/build in `project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`) → `xcodegen`.
- [ ] Xcode → Product → Archive → Distribute App → App Store Connect.
- [ ] Build kiezen bij de versie, abonnementen gekoppeld, indienen voor review.

## 9. Na de lancering

- [ ] Het supportadres wordt echt gelezen; reageer ook op reviews in de App Store.
- [ ] Elk jaar in september (nieuwe iOS): app testen met de nieuwe Xcode en zo nodig een update indienen.
- [ ] Bij wijzigingen in wat de app doet met gegevens: privacybeleid (`site/privacy.html`, met datum)
      en privacylabels bijwerken.

## Testversie op je eigen iPhone (gratis Apple ID)

- Scheme **"Naaste Lokaal"**, zonder iCloud en delen. Verloopt na **7 dagen**; je gegevens blijven
  bewaard. Opnieuw installeren: iPhone aansluiten → Xcode → scheme "Naaste Lokaal" → ⌘R.
- Maak af en toe een reservekopie (Instellingen → Reservekopie): bij het verwijderen van de app ben je
  anders alles kwijt.
