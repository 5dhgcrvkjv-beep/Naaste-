# App Store-teksten (Nederlands)

Kopieer per veld naar App Store Connect → App → [versie] → Nederlands.
Tekenlimieten staan tussen haakjes; `appstore/controleer.py` telt ze na.

## Naam (max 30)

```
Naaste – zorgadministratie
```

## Subtitel (max 30)

```
Samen zorgen, samen regelen
```

## Promotietekst (max 170)

```
Brieven van de gemeente, het CIZ of het CAK, aanvragen, deadlines en taken: alles rond de zorg voor je ouder op één plek, samen met je familie.
```

## Beschrijving (max 4000)

```
Zorg je samen met broers, zussen of buren voor een ouder of naaste? Naaste houdt de administratie overzichtelijk: wie belde de gemeente, waar is de beschikking, wanneer moet de herindicatie, en wie pakt wat op?

DOCUMENTEN OP ÉÉN PLEK
• Scan brieven met je iPhone of importeer PDF's.
• Mappen voor Wmo, Wlz/CIZ, pgb, CAK, verzekering, wonen, juridisch en financiën.
• Zoek op elk woord, ook in gescande brieven: de tekst wordt op je iPhone gelezen.

AANVRAGEN MET EEN TIJDLIJN
• Volg een Wmo-aanvraag, CIZ-indicatie of pgb stap voor stap.
• Zie in één oogopslag wie aan zet is: de familie of de instantie.
• Leg contactmomenten en notities vast, en koppel de bijbehorende brieven.

NOOIT MEER EEN DEADLINE MISSEN
• Herinneringen voor herindicaties, verlengingen, betalingen en afspraken.
• Kies zelf hoeveel dagen van tevoren je een seintje krijgt.
• Herhalende herinneringen, zoals de maandelijkse eigen bijdrage.

SAMEN MET DE FAMILIE
• Deel de zorgmap via iCloud. Iedereen ziet dezelfde documenten, zaken en taken op de eigen iPhone.
• Verdeel taken en zie wie wat oppakt.
• Houd met het urenlogboek bij wie hoeveel tijd besteedt (Plus).

OVERDRACHT IN ÉÉN TIK
• Maak een overzicht als PDF voor wie het even overneemt: contactpersonen, lopende zaken, afspraken en taken. Altijd gratis.

VAN JOU, NIET VAN ONS
• Alles staat op je iPhone en in je eigen iCloud.
• Geen account, geen eigen server, geen advertenties, geen tracking.

GRATIS EN PLUS
De gratis versie is echt bruikbaar: één naaste, 15 documenten, delen met één persoon en het overdrachtsoverzicht.
Naaste Plus geeft onbeperkt naasten en documenten, delen met de hele familie, het urenlogboek en de uren-export. Plus is per maand of per jaar af te sluiten en kan via Gezinsdeling worden gedeeld.

Het abonnement wordt automatisch verlengd, tenzij je minstens 24 uur voor het einde van de periode opzegt in de instellingen van je Apple ID.

Naaste is geen medische app en geeft geen medisch advies.

Privacybeleid: https://5dhgcrvkjv-beep.github.io/Naaste-/privacy.html
Gebruiksvoorwaarden: https://5dhgcrvkjv-beep.github.io/Naaste-/voorwaarden.html
```

## Trefwoorden (max 100, komma's zonder spaties)

```
mantelzorg,wmo,ciz,wlz,pgb,cak,ouder,familie,beschikking,indicatie,documenten,scan,herindicatie
```

## Wat is er nieuw (versie 1.0)

```
De eerste versie van Naaste. Laat ons gerust weten wat je ervan vindt via de hulppagina.
```

## Overige velden

| Veld | Waarde |
|---|---|
| Primaire categorie | Productiviteit |
| Secundaire categorie | Lifestyle *(niet "Gezondheid": dat leidt tot extra vragen over medische claims)* |
| Support-URL | https://5dhgcrvkjv-beep.github.io/Naaste-/support.html |
| Marketing-URL | https://5dhgcrvkjv-beep.github.io/Naaste-/ |
| Privacybeleid-URL | https://5dhgcrvkjv-beep.github.io/Naaste-/privacy.html |
| Copyright | 2026 Mitch Overbeek |
| Leeftijdsclassificatie | 4+ (alle vragen "Nee"; geen medische of behandelinformatie) |

## Abonnementen (App Store Connect → Abonnementen)

Abonnementsgroep: **Naaste Plus** (één groep, zodat maand en jaar elkaar vervangen).

| Product-ID | Weergavenaam | Beschrijving (max 45) | Looptijd | Prijs | Introductieaanbod |
|---|---|---|---|---|---|
| `nl.naaste.app.plus.maand` | Naaste Plus maandelijks | Onbeperkt, delen met familie, uren | 1 maand | € 3,99 | — |
| `nl.naaste.app.plus.jaar` | Naaste Plus jaarlijks | Onbeperkt, delen met familie, uren | 1 jaar | € 34,99 | 2 weken gratis |

Zet **Gezinsdeling** aan voor beide producten (zoals in `Naaste.storekit`).
De prijzen moeten overeenkomen met `Naaste/Resources/Naaste.storekit`, anders test je in de simulator met andere bedragen.
