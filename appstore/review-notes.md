# Notes for App Review

Paste into App Store Connect → App Review Information → Notes. In English for the reviewer.

```
Naaste helps families manage the paperwork around caring for an elderly parent in the Netherlands (municipal care applications, insurance letters, deadlines and tasks). It is not a medical app and gives no medical advice.

NO LOGIN NEEDED
There are no accounts. To see every feature with realistic (fictional) data, tap "Sla over" (Skip) on the welcome screens and then "Bekijk eerst een voorbeeld" ("View an example first"). The example can be removed in Instellingen (Settings).

WHERE DATA LIVES
All data stays on the device and in the user's own iCloud (CloudKit private database). We run no server and collect no data. Text recognition for search runs on-device with the Vision framework.

SUBSCRIPTION (Naaste Plus)
Auto-renewable, monthly or yearly, Family Sharing enabled. The paywall only appears after a user action: tap "Bekijk Naaste Plus" in Instellingen, or try to exceed a free limit (e.g. add a second person via the person menu in Overzicht, or open "Uren" in the Taken tab and tap "Bekijk Naaste Plus"). The free version stays fully usable. Restore Purchases is on the paywall and in Instellingen.

FAMILY SHARING OF DATA (CloudKit sharing)
Instellingen → Delen met familie uses UICloudSharingController. Testing requires two devices with different Apple IDs signed in to iCloud. On the example person sharing is disabled because the data is fictional.

PERMISSIONS
- Camera: only when the user chooses "Scan een brief" in Documenten (VisionKit document scanner).
- Notifications: requested only after the user saves a reminder.
- Face ID: only if the user turns on Instellingen → Beveiliging → "Vergrendel met Face ID" (app lock).
- Calendar: "Zet in agenda" (long-press a reminder, or on a case with a follow-up date) shows the system EKEventEditViewController. The app never reads the calendar and does not request calendar access.

OTHER FEATURES
- Spotlight: documents, cases and open tasks are indexed on-device (CoreSpotlight). Disabled while the app lock is on.
- Home screen quick actions: Scan een brief, Nieuwe taak, Uren schrijven.
- Backup: Instellingen → Reservekopie exports a file the user saves via the Files app, optionally password-encrypted (AES-GCM). Restoring only adds missing items.

DELETING DATA
Instellingen → Alle gegevens wissen deletes all data on the device and in iCloud. There is no account to delete.

The interface is in Dutch.
```

## Contactgegevens voor de reviewer

App Store Connect vraagt om een naam, telefoonnummer en e-mailadres van iemand die bereikbaar
is tijdens de review. Die vul je zelf in; ze worden niet gepubliceerd.

## Demo-account

Niet nodig (geen login). Laat "Aanmelden vereist" uit.
