# Privacylabels (App Store Connect → App-privacy)

## Antwoord

**"Verzamel je gegevens van deze app?" → Nee, we verzamelen geen gegevens van deze app.**

Het label wordt dan: **Geen gegevens verzameld**.

## Onderbouwing

Apple definieert "verzamelen" als het doorsturen van gegevens van het toestel op een manier
waardoor jij (de ontwikkelaar) of een derde partij er langer toegang toe heeft dan nodig is
om het verzoek in realtime af te handelen. Bij Naaste:

| Wat | Waar | Toegang ontwikkelaar? |
|---|---|---|
| Alles wat de gebruiker invult (naaste, contacten, documenten, zaken, taken, uren) | Op het toestel + **privédatabase** van de eigen iCloud (CloudKit) | Nee. De privédatabase is alleen voor de gebruiker zelf; de ontwikkelaar kan die niet lezen. |
| Gedeelde zorgmappen | **Gedeelde** CloudKit-database, alleen voor de genodigden | Nee |
| Tekstherkenning van documenten | Vision-framework, volledig op het toestel | Nee |
| Camera (scannen) | VisionKit, resultaat alleen als PDF in de app | Nee |
| Meldingen | Lokaal gepland (`UNUserNotificationCenter`) | Nee |
| Aankopen | StoreKit 2, afgehandeld door Apple | Nee (alleen de status van het abonnement op het toestel) |
| Analytics, advertenties, crashrapportage van derden | Niet aanwezig | — |
| SDK's van derden | Geen | — |

Crashrapporten die gebruikers via Apple met ontwikkelaars delen (opt-in in de iOS-instellingen)
worden door Apple verzameld en hoeven niet in het label te staan.

## Tracking

**Gebruikt deze app gegevens om te volgen (tracking)?** → Nee. Er is dus geen
App Tracking Transparency-melding nodig.

## Privacy Manifest

`Naaste/Resources/PrivacyInfo.xcprivacy` bevat:

- `NSPrivacyTracking`: false, geen tracking-domeinen
- `NSPrivacyCollectedDataTypes`: leeg
- Required reason API's: UserDefaults (`CA92.1`, eigen voorkeuren van de app) en
  bestandstijden (`C617.1`, bestanden in de eigen container)

## Wanneer moet dit opnieuw?

Pas het label en het manifest aan als je ooit iets toevoegt dat gegevens naar jezelf of een
derde stuurt: analytics, een crashrapportage-SDK, een eigen server, een feedbackformulier
met e-mail, of de publieke CloudKit-database.
