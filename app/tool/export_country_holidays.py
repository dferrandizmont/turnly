#!/usr/bin/env python
"""Exports the official holidays of other countries into the app's bundle.

Development tool: it never runs on the phone and the app never calls an API.
It reads the `python-holidays` library (MIT, https://github.com/vacanza/holidays)
at a PINNED version and writes, in the format of docs/festivos.md:

  assets/holidays/{year}/<cc>.json            one file per country and year
  assets/holidays/NOTICE                      licence and provenance
  tool/country_holidays_sources.json          provenance per file (read by
                                              tool/build_holidays.dart to fill
                                              `source` in manifest.json)
  lib/features/holidays/domain/country_holiday_data.dart
                                              which countries have data, and
                                              the names of their subdivisions

Regenerate (from `app/`, once a year, see docs/festivos.md):

  python -m venv ../.venv
  ../.venv/Scripts/pip install holidays==<PINNED, below>      # Windows
  ../.venv/Scripts/python tool/export_country_holidays.py
  dart format lib/features/holidays/domain/country_holiday_data.dart
  dart run tool/build_holidays.dart                           # manifest.json

Rules of the export
-------------------
* Public holidays only (the library's default category), with the observed
  (moved) date when the day is moved, in the language closest to the country's
  own that the library has.
* `national` = the days every subdivision of the country has (compared by
  date). A day the country has but only some subdivisions keep is written
  under those subdivisions with `origin: national-optional` (the same idea as
  Spain's files); a day only some subdivisions have is `origin: regional`.
  Countries without subdivisions in the library (or whose subdivisions are not
  worth offering) only have `national`.
* Subdivisions are ISO 3166-2 codes (`DE-BY`). Their names come from the
  library's own alias table.

Use `--check` to see whether the files on disk are what this script would
write (no files are touched), `--list` to print what would be exported.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import holidays as pyholidays
from holidays import country_holidays

# The only version the output is valid for. Bump it on purpose, regenerate and
# review the `git diff` of assets/holidays/ (see docs/festivos.md).
PINNED_VERSION = "0.107"

# Date of the data snapshot: goes to `source.published` in the manifest. Bump
# it when the script is re-run with new data.
SNAPSHOT_DATE = "2026-11-06"

YEARS = (2026, 2027)

SOURCE_URL = "https://github.com/vacanza/holidays"

# (ISO 3166-1 code, library language, kind of subdivision the app offers).
# Order: the roadmap's. Language: Spanish for Spanish-speaking countries, the
# country's own language elsewhere, English for the multilingual ones (Belgium,
# Switzerland: Dutch/French/German/Italian) and Ireland (library default).
# kind: state, federalState, province, region, nation, canton, city,
# cityOrRegion, department, or None (no subdivisions offered).
COUNTRIES: list[tuple[str, str | None, str | None]] = [
    ("MX", "es", None),
    ("AR", "es", "province"),
    ("CO", "es", None),
    ("CL", "es", "region"),
    ("PE", "es", None),
    ("EC", "es", None),
    ("UY", "es", None),
    ("VE", "es", None),
    ("PT", "pt_PT", "cityOrRegion"),
    ("BR", "pt_BR", "state"),
    ("FR", "fr", "region"),
    ("IT", "it_IT", "city"),
    ("DE", "de", "federalState"),
    ("GB", "en_GB", "nation"),
    ("IE", None, None),
    ("US", "en_US", "state"),
    ("CA", "en_CA", "province"),
    ("NL", "nl", None),
    ("BE", "en_US", None),
    ("CH", "en_US", "canton"),
    ("AT", "de", "federalState"),
    # 6 Nov 2026 (proposal 8 of docs/competencia-2026-11.md): the rest of
    # Latin America the reviews ask for, and the Nordic, Central European and
    # small neighbours of the picker list. Not exported: Morocco (religious
    # days follow the moon sighting), the Philippines (proclaimed every year),
    # Puerto Rico (the library has no Spanish), Equatorial Guinea, Australia
    # and New Zealand (state days with no ISO codes), see docs/festivos.md.
    ("GT", "es", None),
    ("BO", "es", "department"),
    ("PY", "es", None),
    ("PA", "es", None),
    ("CR", "es", None),
    ("DO", "es", None),
    ("HN", "es", None),
    ("SV", "es", None),
    ("NI", "es", None),
    ("CU", "es", None),
    ("PL", "pl", None),
    ("SE", "sv", None),
    ("NO", "no", None),
    ("DK", "da", None),
    ("FI", "fi", None),
    ("LU", "en_US", None),
    ("GR", "el", None),
    ("RO", "ro", None),
    ("AD", "ca", None),
]

# Library subdivisions we do not offer, with the reason (kept for the review).
SKIP_SUBDIVISIONS: dict[str, set[str]] = {
    # Territories have their own entry as countries (PR) or hardly any
    # residents (UM); several of them drop federal days, which would shrink
    # the national list of the whole country.
    "US": {"AS", "GU", "MP", "PR", "UM", "VI"},
}

# Days the library lists that are not a day off anywhere (one-offs, wishes),
# as (country, date) -> reason. Reviewed by hand at every regeneration.
DROP_DAYS: dict[tuple[str, str], str] = {
    # Decreed for 2024 only (Globovision, 15 May 2024); no decree found for
    # 2026-27, and the labour law (LOTTT art. 184) does not list it.
    ("VE", "2026-05-15"): "Dia de la Familia, one-off decree of 2024",
    ("VE", "2027-05-15"): "Dia de la Familia, one-off decree of 2024",
    # Assumption is a holiday of Guatemala City only (a municipal day), not
    # of the country: it would mark a day off to everyone else.
    ("GT", "2026-08-15"): "Dia de la Asuncion, only Guatemala City",
    ("GT", "2027-08-15"): "Dia de la Asuncion, only Guatemala City",
}

# Names we write differently from the library, as (country, date) -> name.
RENAME_DAYS: dict[tuple[str, str], str] = {
    # gov.scot calls it «World Cup bank holiday» (Scotland, one-off).
    ("GB", "2026-06-15"): "World Cup bank holiday",
}

# Countries whose `national` list is what the country-level calendar says, not
# the days every subdivision shares: US federal holidays are national even
# when a state names or moves them differently (Presidents' Day in
# California...). The states only add their own days.
NATIONAL_FROM_BASE = {"US"}

ISO_SUBDIVISION = re.compile(r"^[A-Z0-9]{1,3}$")

ROOT = Path(__file__).resolve().parent.parent  # app/
OUT = ROOT / "assets" / "holidays"
SOURCES = ROOT / "tool" / "country_holidays_sources.json"
DART = ROOT / "lib" / "features" / "holidays" / "domain" / "country_holiday_data.dart"


def check_version() -> None:
    have = getattr(pyholidays, "__version__", None)
    if have != PINNED_VERSION:
        sys.exit(
            f"python-holidays {have} is installed; the export is pinned to "
            f"{PINNED_VERSION} (pip install holidays=={PINNED_VERSION})."
        )


def subdivision_names(cls, skip: set[str]) -> dict[str, str]:
    """ISO code -> name, from the library's aliases (first long-enough alias)."""
    names: dict[str, str] = {}
    for alias, code in cls.subdivisions_aliases.items():
        if code in names or code in skip:
            continue
        if not ISO_SUBDIVISION.match(code):
            continue
        if len(alias) <= 3 and alias.isupper():
            continue
        names[code] = alias
    return names


def day_map(cc: str, year: int, language: str | None, subdiv: str | None):
    h = country_holidays(
        cc, subdiv=subdiv, years=year, language=language, observed=True
    )
    out: dict[str, str] = {}
    for d, name in h.items():
        iso = d.isoformat()
        if (cc, iso) in DROP_DAYS:
            continue
        out[iso] = RENAME_DAYS.get((cc, iso), name)
    return out


def export_country(cc: str, language: str | None, kind: str | None, year: int):
    """(json dict, {iso code: name}) for one country and year."""
    cls = type(country_holidays(cc, years=year))
    base = day_map(cc, year, language, None)
    subs: dict[str, dict[str, str]] = {}
    names: dict[str, str] = {}
    if kind is not None:
        names = subdivision_names(cls, SKIP_SUBDIVISIONS.get(cc, set()))
        for code in sorted(names):
            subs[code] = day_map(cc, year, language, code)
    if subs and cc not in NATIONAL_FROM_BASE:
        common = set(base)
        for days in subs.values():
            common &= set(days)
    else:
        common = set(base)
    national = [{"date": d, "name": base[d]} for d in sorted(common)]
    regional: dict[str, list[dict[str, str]]] = {}
    for code, days in subs.items():
        rows = []
        for d in sorted(days):
            if d in common:
                continue
            if cc in NATIONAL_FROM_BASE and d in base:
                continue  # a federal day the state names or moves its way
            if d in base and base[d] == days[d]:
                origin = "national-optional"
            else:
                origin = "regional"
            rows.append({"date": d, "name": days[d], "origin": origin})
        regional[f"{cc}-{code}"] = rows
    doc: dict[str, object] = {
        "schema": 1,
        "year": year,
        "country": cc,
        "national": national,
    }
    if regional:
        doc["regional"] = regional
    return doc, {f"{cc}-{c}": n for c, n in names.items()}


def encode(value, depth=0, line_depth=2) -> str:
    """Same layout as `encodeBundleJson` in tool/build_holidays.dart."""
    if depth < line_depth and isinstance(value, dict):
        lines = [
            f"{json.dumps(k, ensure_ascii=False)}:{encode(v, depth + 1, line_depth)}"
            for k, v in value.items()
        ]
        return "{}" if not lines else "{\n" + ",\n".join(lines) + "\n}"
    if depth < line_depth and isinstance(value, list):
        lines = [encode(v, depth + 1, line_depth) for v in value]
        return "[]" if not lines else "[\n" + ",\n".join(lines) + "\n]"
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


NOTICE = f"""\
Holidays of other countries (assets/holidays/<year>/<cc>.json)
===============================================================

Generated at development time by app/tool/export_country_holidays.py from
python-holidays {PINNED_VERSION} (data snapshot {SNAPSHOT_DATE}).
Nothing is downloaded or computed on the phone.

  python-holidays
  https://github.com/vacanza/holidays
  Copyright (c) Vacanza Team and individual contributors
  Copyright (c) 2017-2023 ryanss, 2014-2017 dr-prodigy
  MIT License

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to
  deal in the Software without restriction, including without limitation the
  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
  sell copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
  IN THE SOFTWARE.

The names of the subdivisions come from the same library. The sample checks
against official sources are in docs/festivos.md.
"""


def dart_source(countries: list[str], kinds: dict[str, str], subs: dict[str, dict[str, str]]) -> str:
    def q(s: str) -> str:
        return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"

    out = [
        "// GENERATED by tool/export_country_holidays.py (python-holidays "
        f"{PINNED_VERSION}). Do not edit by hand:",
        "// regenerate (docs/festivos.md, «Otros países») and run `dart format`.",
        "",
        "/// Countries other than Spain whose official holidays are in the bundle",
        "/// (`assets/holidays/{year}/<cc>.json`), in the order they were added.",
        "const List<String> bundledCountryCodes = [",
    ]
    out += [f"  {q(c)}," for c in countries]
    out += [
        "];",
        "",
        "/// Kind of subdivision each country offers (`state`, `federalState`,",
        "/// `province`, `region`, `nation`, `canton`, `city`, `cityOrRegion`,",
        "/// `department`).",
        "const Map<String, String> bundledSubdivisionKinds = {",
    ]
    out += [f"  {q(c)}: {q(k)}," for c, k in kinds.items()]
    out += [
        "};",
        "",
        "/// ISO 3166-2 code -> name of the subdivisions of each country that has",
        "/// them in its files (the keys of `regional`).",
        "const Map<String, Map<String, String>> bundledSubdivisionNames = {",
    ]
    for c, names in subs.items():
        out.append(f"  {q(c)}: {{")
        out += [f"    {q(code)}: {q(name)}," for code, name in names.items()]
        out.append("  },")
    out += ["};", ""]
    return "\n".join(out)


def build():
    """Everything to write: {path: text}."""
    files: dict[Path, str] = {}
    sources: dict[str, dict[str, str]] = {}
    kinds: dict[str, str] = {}
    subs: dict[str, dict[str, str]] = {}
    for cc, language, kind in COUNTRIES:
        names_all: dict[str, str] = {}
        docs: dict[int, dict] = {}
        for year in YEARS:
            docs[year], names = export_country(cc, language, kind, year)
            names_all.update(names)
        # A country offers its subdivisions when at least one of them adds a
        # day in some year (a state with no day of its own is still listed:
        # a missing state would look like a bug). When none does (Austria),
        # the country has no subdivisions at all.
        has_rows = any(
            rows
            for doc in docs.values()
            for rows in doc.get("regional", {}).values()
        )
        keep = set(names_all) if has_rows else set()
        for year, doc in docs.items():
            if "regional" in doc:
                doc["regional"] = {
                    k: v for k, v in doc["regional"].items() if k in keep
                }
                if not doc["regional"]:
                    del doc["regional"]
            rel = f"{year}/{cc.lower()}.json"
            files[OUT / rel] = encode(doc) + "\n"
            sources[rel] = {
                "url": SOURCE_URL,
                "ref": (
                    f"python-holidays {PINNED_VERSION} (MIT), "
                    f"country_holidays('{cc}', years={year}, "
                    f"language={language!r}, observed=True)"
                ),
                "published": SNAPSHOT_DATE,
            }
        if keep:
            kinds[cc] = kind
            subs[cc] = {k: names_all[k] for k in sorted(keep)}
    files[OUT / "NOTICE"] = NOTICE
    files[SOURCES] = json.dumps(sources, indent=1, ensure_ascii=False) + "\n"
    files[DART] = dart_source([c for c, _, _ in COUNTRIES], kinds, subs)
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true", help="only compare")
    parser.add_argument("--list", action="store_true", help="print a summary")
    args = parser.parse_args()
    check_version()
    files = build()
    if args.list:
        for path, text in files.items():
            print(f"{path.relative_to(ROOT)}  {len(text.encode('utf-8'))} B")
        return 0
    stale = [
        p
        for p, text in files.items()
        if not p.exists() or p.read_bytes() != text.encode("utf-8")
    ]
    if args.check:
        for p in stale:
            print("stale:", p.relative_to(ROOT))
        return 1 if stale else 0
    for p in stale:
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(files[p].encode("utf-8"))
        print("wrote", p.relative_to(ROOT))
    total = sum(
        len(t.encode("utf-8"))
        for p, t in files.items()
        if p.suffix == ".json" and OUT in p.parents
    )
    print(f"{len(files)} files, country JSON {total} B; snapshot {SNAPSHOT_DATE}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
