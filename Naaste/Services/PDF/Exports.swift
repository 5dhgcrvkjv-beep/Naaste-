import Foundation
import NaasteKit

/// Welke onderdelen in het overdrachtsoverzicht komen. Zo kan de gebruiker bijvoorbeeld
/// de medicatie weglaten als het overzicht naar de gemeente gaat.
struct OverdrachtOpties: Equatable {
    var profiel = true
    var medicatie = true
    var contacten = true
    var familie = true
    var zaken = true
    var herinneringen = true
    var taken = true
    var documenten = true
}

/// PDF-exports: het overdrachtsoverzicht (gratis) en het urenoverzicht (Plus).
@MainActor
enum Exports {
    // MARK: - Overdracht

    /// Alles wat een vervanger (broer, buurvrouw, casemanager) moet weten om het even over te nemen.
    static func overdracht(_ naaste: Naaste, opties: OverdrachtOpties = .init(), nu: Date = .now) -> Data {
        var pdf = PDFOpmaak()
        pdf.voettekst = String(localized: "Overdrachtsoverzicht \(naaste.weergaveNaam) · \(nu.formatted(date: .long, time: .omitted)) · vertrouwelijk")
        pdf.voegToe(.titel(naaste.weergaveNaam))
        pdf.voegToe(.ondertitel(String(localized: "Overdrachtsoverzicht, gemaakt op \(nu.formatted(date: .long, time: .shortened))")))

        if opties.profiel {
            pdf.voegToe(.kop(String(localized: "Gegevens")))
            veld(&pdf, String(localized: "Geboortedatum"), naaste.geboortedatum?.formatted(date: .long, time: .omitted))
            veld(&pdf, String(localized: "Adres"), naaste.adresRegel)
            veld(&pdf, String(localized: "Telefoon"), naaste.telefoon)
            veld(&pdf, String(localized: "Huisarts"), [naaste.huisartsNaam?.nietLeeg, naaste.huisartsTelefoon?.nietLeeg].compactMap { $0 }.joined(separator: " · ").nietLeeg)
            veld(&pdf, String(localized: "Zorgverzekeraar"), [naaste.zorgverzekeraar?.nietLeeg, naaste.verzekeraarTelefoon?.nietLeeg].compactMap { $0 }.joined(separator: " · ").nietLeeg)
            veld(&pdf, String(localized: "Polisnummer"), naaste.polisnummer)
            if let notities = naaste.notities?.nietLeeg {
                pdf.voegToe(.ruimte(4))
                pdf.voegToe(.tekst(notities))
            }
        }

        if opties.medicatie, let medicatie = naaste.medicatieNotitie?.nietLeeg {
            pdf.voegToe(.kop(String(localized: "Medicatie")))
            pdf.voegToe(.tekst(medicatie))
            pdf.voegToe(.kleineTekst(String(localized: "Overgenomen uit de notitie in Naaste. Controleer altijd het actuele medicatieoverzicht van de apotheek.")))
        }

        if opties.contacten {
            let contacten = naaste.contactenLijst.sorted(by: Contactpersoon.sorteer)
            if !contacten.isEmpty {
                pdf.voegToe(.kop(String(localized: "Contactpersonen")))
                pdf.voegToe(.tabel(
                    kop: [String(localized: "Rol"), String(localized: "Naam"), String(localized: "Telefoon"), String(localized: "E-mail")],
                    rijen: contacten.map { c in
                        [c.rolWaarde.titel, [c.naam?.nietLeeg, c.organisatie?.nietLeeg].compactMap { $0 }.joined(separator: ", "), c.telefoon ?? "", c.email ?? ""]
                    },
                    breedtes: [1.1, 1.8, 1.2, 1.7]
                ))
            }
        }

        if opties.familie {
            let leden = naaste.familieledenLijst.sorted { $0.weergaveNaam < $1.weergaveNaam }
            if !leden.isEmpty {
                pdf.voegToe(.kop(String(localized: "Familie")))
                pdf.voegToe(.opsomming(leden.map { lid in
                    let open = lid.takenLijst.filter { !$0.afgerond }.count
                    let zaken = lid.zakenLijst.filter { $0.statusWaarde.isLopend }.count
                    var delen = [lid.weergaveNaam]
                    if zaken > 0 {
                        delen.append(zaken == 1 ? String(localized: "pakt 1 zaak op") : String(localized: "pakt \(zaken) zaken op"))
                    }
                    if open > 0 {
                        delen.append(open == 1 ? String(localized: "1 open taak") : String(localized: "\(open) open taken"))
                    }
                    return delen.joined(separator: " · ")
                }))
            }
        }

        if opties.zaken {
            let zaken = naaste.zakenLijst.filter { $0.statusWaarde.isLopend }.sorted(by: Zaak.sorteerOpVervolg)
            pdf.voegToe(.kop(String(localized: "Lopende zaken")))
            if zaken.isEmpty {
                pdf.voegToe(.tekst(String(localized: "Er lopen geen zaken.")))
            }
            for zaak in zaken {
                pdf.voegToe(.subkop("\(zaak.weergaveTitel) — \(zaak.statusWaarde.titel)"))
                veld(&pdf, String(localized: "Soort"), zaak.categorieWaarde.titel)
                veld(&pdf, String(localized: "Pakt het op"), zaak.opgepaktDoor?.weergaveNaam)
                veld(&pdf, String(localized: "Aangevraagd"), zaak.datumAangevraagd?.formatted(date: .long, time: .omitted))
                veld(&pdf, String(localized: "Volgende stap"), zaak.vervolgdatum?.formatted(date: .long, time: .omitted))
                if let laatste = zaak.tijdlijn.first {
                    let datum = laatste.datum?.formatted(date: .abbreviated, time: .omitted) ?? ""
                    let tekst = laatste.tekst?.nietLeeg ?? laatste.nieuweStatusWaarde.map { String(localized: "Status: \($0.titel)") } ?? laatste.soortWaarde.titel
                    veld(&pdf, String(localized: "Laatst gebeurd"), "\(datum): \(tekst)")
                }
                veld(&pdf, String(localized: "Notities"), zaak.notities)
                pdf.voegToe(.ruimte(6))
            }
        }

        if opties.herinneringen {
            let grens = Calendar.current.date(byAdding: .day, value: 90, to: nu) ?? nu
            let komend = naaste.herinneringenLijst
                .filter { !$0.afgerond }
                .compactMap { h in h.volgendeDatum(nu: nu).map { (h, $0) } }
                .filter { $0.1 <= grens }
                .sorted { $0.1 < $1.1 }
            if !komend.isEmpty {
                pdf.voegToe(.kop(String(localized: "Komende 3 maanden")))
                pdf.voegToe(.tabel(
                    kop: [String(localized: "Datum"), String(localized: "Wat"), String(localized: "Soort")],
                    rijen: komend.map { h, datum in
                        [h.heeftTijd ? datum.formatted(date: .abbreviated, time: .shortened) : datum.formatted(date: .abbreviated, time: .omitted),
                         h.weergaveTitel + (h.herhalingWaarde == .geen ? "" : " (\(h.herhalingWaarde.titel.lowercased()))"),
                         h.soortWaarde.titel]
                    },
                    breedtes: [1.3, 3, 1.2]
                ))
            }
        }

        if opties.taken {
            let taken = naaste.takenLijst.filter { !$0.afgerond }.sorted(by: Taak.sorteer)
            if !taken.isEmpty {
                pdf.voegToe(.kop(String(localized: "Open taken")))
                pdf.voegToe(.tabel(
                    kop: [String(localized: "Taak"), String(localized: "Wie"), String(localized: "Deadline")],
                    rijen: taken.map { [$0.weergaveTitel, $0.toegewezenAan?.weergaveNaam ?? "—", $0.deadline?.formatted(date: .abbreviated, time: .omitted) ?? "—"] },
                    breedtes: [3, 1.2, 1.2]
                ))
            }
        }

        if opties.documenten {
            let documenten = naaste.documentenLijst
            if !documenten.isEmpty {
                pdf.voegToe(.kop(String(localized: "Documenten in Naaste")))
                pdf.voegToe(.kleineTekst(String(localized: "Alleen de lijst; de documenten zelf staan in de app.")))
                for categorie in DocumentCategorie.allCases {
                    let inMap = documenten.filter { $0.categorieWaarde == categorie }
                        .sorted { ($0.documentDatum ?? .distantPast) > ($1.documentDatum ?? .distantPast) }
                    guard !inMap.isEmpty else { continue }
                    pdf.voegToe(.subkop(categorie.titel))
                    pdf.voegToe(.opsomming(inMap.map { d in
                        [d.weergaveTitel, d.documentDatum?.formatted(date: .abbreviated, time: .omitted)].compactMap { $0 }.joined(separator: " · ")
                    }))
                }
            }
        }

        pdf.voegToe(.ruimte(12))
        pdf.voegToe(.lijn)
        pdf.voegToe(.kleineTekst(String(localized: "Gemaakt met de app Naaste. Dit overzicht bevat persoonlijke gegevens: deel het alleen met mensen die meehelpen.")))
        return pdf.maakPDF(titelMetadata: String(localized: "Overdrachtsoverzicht \(naaste.weergaveNaam)"))
    }

    // MARK: - Uren

    /// Urenoverzicht over een periode, bijv. voor de verdeling in de familie of de
    /// mantelzorgwaardering van de gemeente.
    static func uren(_ naaste: Naaste, periode: UrenPeriode, nu: Date = .now) -> Data {
        let interval = periode.interval(nu: nu)
        let regels = naaste.urenregelsLijst
            .filter { regel in
                guard let interval else { return true }
                let d = regel.data.datum
                return d >= interval.start && d < interval.end
            }
            .sorted { ($0.datum ?? .distantPast) < ($1.datum ?? .distantPast) }
        let data = regels.map(\.data)

        var pdf = PDFOpmaak()
        pdf.voettekst = String(localized: "Urenoverzicht \(naaste.weergaveNaam) · \(periodeTekst(periode, interval: interval, regels: data))")
        pdf.voegToe(.titel(String(localized: "Urenoverzicht mantelzorg")))
        pdf.voegToe(.ondertitel("\(naaste.weergaveNaam) · \(periodeTekst(periode, interval: interval, regels: data))"))

        let totaal = UrenRekenaar.totaal(data)
        veld(&pdf, String(localized: "Totaal"), Duur.tekst(minuten: totaal, kort: false))
        veld(&pdf, String(localized: "Aantal keer"), regels.count.formatted())

        let perPersoon = UrenRekenaar.perPersoon(data)
        if !perPersoon.isEmpty {
            pdf.voegToe(.kop(String(localized: "Per persoon")))
            pdf.voegToe(.tabel(
                kop: [String(localized: "Naam"), String(localized: "Tijd"), String(localized: "Aandeel")],
                rijen: perPersoon.map { [$0.naam, Duur.tekst(minuten: $0.minuten), $0.aandeel.formatted(.percent.precision(.fractionLength(0)))] },
                breedtes: [2.5, 1.5, 1]
            ))
        }

        let perCategorie = UrenRekenaar.perCategorie(data)
        if !perCategorie.isEmpty {
            pdf.voegToe(.kop(String(localized: "Waaraan")))
            pdf.voegToe(.tabel(
                kop: [String(localized: "Soort"), String(localized: "Tijd")],
                rijen: perCategorie.map { [$0.categorie.titel, Duur.tekst(minuten: $0.minuten)] },
                breedtes: [3, 1.5]
            ))
        }

        pdf.voegToe(.kop(String(localized: "Logboek")))
        if regels.isEmpty {
            pdf.voegToe(.tekst(String(localized: "Geen uren in deze periode.")))
        } else {
            pdf.voegToe(.tabel(
                kop: [String(localized: "Datum"), String(localized: "Wie"), String(localized: "Waaraan"), String(localized: "Omschrijving"), String(localized: "Tijd")],
                rijen: regels.map { r in
                    [r.datum?.formatted(date: .numeric, time: .omitted) ?? "",
                     r.familielid?.weergaveNaam ?? "—",
                     r.categorieWaarde.titel,
                     r.omschrijving ?? "",
                     Duur.tekst(minuten: Int(r.minuten))]
                },
                breedtes: [1.1, 1.1, 1.5, 2.6, 0.9]
            ))
        }

        pdf.voegToe(.ruimte(12))
        pdf.voegToe(.kleineTekst(String(localized: "Gemaakt met de app Naaste op \(nu.formatted(date: .long, time: .omitted)). De uren zijn door de familie zelf bijgehouden.")))
        return pdf.maakPDF(titelMetadata: String(localized: "Urenoverzicht \(naaste.weergaveNaam)"))
    }

    /// "november 2026", "2026" of "12 jan 2025 – 3 nov 2026".
    static func periodeTekst(_ periode: UrenPeriode, interval: DateInterval?, regels: [UrenRegelData]) -> String {
        switch periode {
        case .dezeMaand, .vorigeMaand:
            return interval?.start.formatted(.dateTime.month(.wide).year()) ?? periode.titel
        case .ditJaar:
            return interval?.start.formatted(.dateTime.year()) ?? periode.titel
        case .alles:
            let datums = regels.map(\.datum)
            guard let eerste = datums.min(), let laatste = datums.max() else { return periode.titel }
            return "\(eerste.kort) – \(laatste.kort)"
        }
    }

    // MARK: - Hulp

    private static func veld(_ pdf: inout PDFOpmaak, _ label: String, _ waarde: String?) {
        guard let waarde = waarde?.nietLeeg else { return }
        pdf.voegToe(.veld(label: label, waarde: waarde))
    }
}
