"""Telt de tekens van de velden in teksten.md en vergelijkt ze met de limieten van App Store Connect.

Gebruik:  python3 appstore/controleer.py
"""
import pathlib
import re
import sys

LIMIETEN = {
    "Naam": 30,
    "Subtitel": 30,
    "Promotietekst": 170,
    "Beschrijving": 4000,
    "Trefwoorden": 100,
    "Wat is er nieuw": 4000,
}

tekst = (pathlib.Path(__file__).parent / "teksten.md").read_text(encoding="utf-8")
fout = False
for veld, limiet in LIMIETEN.items():
    m = re.search(rf"^## {re.escape(veld)}[^\n]*\n+```\n(.*?)\n```", tekst, re.S | re.M)
    if not m:
        print(f"?  {veld}: niet gevonden")
        fout = True
        continue
    waarde = m.group(1)
    lengte = len(waarde)
    status = "ok" if lengte <= limiet else "TE LANG"
    fout |= lengte > limiet
    print(f"{'✓' if status == 'ok' else '✗'}  {veld}: {lengte}/{limiet}")
    if veld == "Trefwoorden" and ", " in waarde:
        print("   let op: spaties na komma's tellen mee; laat ze weg")
sys.exit(1 if fout else 0)
