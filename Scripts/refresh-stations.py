#!/usr/bin/env python3
"""
refresh-stations.py - Bouw curated-stations.json opnieuw op vanuit Radio-Browser.

Workflow:
  1. Haal alle NL stations op via Radio-Browser (limit=500, hidebroken=true).
  2. Dedupe op genormaliseerde naam (lowercase, geen punctuation),
     behoud de variant met de hoogste clickcount * bitrate.
  3. Match curated NL-zenders op naam (whitelist) en map naar onze genre/region taxonomie.
  4. Live HEAD/GET test op stream URLs in parallel; verwerp wat 404/timeout/text geeft.
  5. Voor stations zonder favicon in Radio-Browser: handmatige logo URLs uit een mapping.
  6. Schrijf het resultaat naar RadioNaoufal/Resources/curated-stations.json.

Gebruik: python3 Scripts/refresh-stations.py
"""
from __future__ import annotations
import json
import re
import sys
import urllib.request
import urllib.error
import concurrent.futures
from pathlib import Path
from datetime import date
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "RadioNaoufal" / "Resources" / "curated-stations.json"

UA = "RadioNaoufal/1.0 (macOS; +https://github.com/naoufalandichi/Radio-Naoufal)"

RADIO_BROWSER_HOSTS = [
    "de1.api.radio-browser.info",
    "fr1.api.radio-browser.info",
    "at1.api.radio-browser.info",
    "nl1.api.radio-browser.info",
]

# Whitelist van NL-zenders die we willen tonen.
# Key = onze internal id, value = {
#   "match": [namen om in Radio-Browser te zoeken; eerste match wint],
#   "genre": onze genre,
#   "region": onze regio,
#   "dial": optionele FM-frequentie,
#   "tags": tags voor onze app,
#   "logo": fallback logo URL als Radio-Browser geen favicon heeft,
#   "stream": optionele override stream URL (bypass Radio-Browser),
# }
WHITELIST: dict[str, dict[str, Any]] = {
    # ===== NPO (publiek) =====
    "npo-radio1": {
        "match": ["NPO Radio 1"],
        "genre": "news", "region": "national", "dial": 88.4,
        "tags": ["public", "news", "sport", "talk"],
        "stream": "https://icecast.omroep.nl/radio1-bb-mp3",
        "logo": "https://www.nporadio1.nl/_next/image?url=%2Fimages%2Flogos%2Fnporadio1.png&w=256&q=75",
    },
    "npo-radio2": {
        "match": ["NPO Radio 2"],
        "genre": "popClassics", "region": "national", "dial": 92.6,
        "tags": ["public", "pop", "classics"],
        "stream": "https://icecast.omroep.nl/radio2-bb-mp3",
        "logo": "https://www.nporadio2.nl/_next/image?url=%2Fimages%2Flogos%2Fnporadio2.png&w=256&q=75",
    },
    "npo-3fm": {
        "match": ["NPO 3FM", "3FM"],
        "genre": "alternative", "region": "national", "dial": 96.8,
        "tags": ["public", "alternative", "rock", "indie"],
        "stream": "https://icecast.omroep.nl/3fm-bb-mp3",
        "logo": "https://www.npo3fm.nl/_next/image?url=%2Fimages%2Flogos%2Fnpo3fm.png&w=256&q=75",
    },
    "npo-radio4": {
        "match": ["NPO Radio 4"],
        "genre": "classical", "region": "national", "dial": 98.7,
        "tags": ["public", "classical", "opera"],
        "stream": "https://icecast.omroep.nl/radio4-bb-mp3",
        "logo": "https://www.nporadio4.nl/_next/image?url=%2Fimages%2Flogos%2Fnporadio4.png&w=256&q=75",
    },
    "npo-radio5": {
        "match": ["NPO Radio 5"],
        "genre": "oldies", "region": "national", "dial": 1008.0,
        "tags": ["public", "oldies", "60s", "70s"],
        "stream": "https://icecast.omroep.nl/radio5-bb-mp3",
        "logo": "https://www.nporadio5.nl/_next/image?url=%2Fimages%2Flogos%2Fnporadio5.png&w=256&q=75",
    },
    "npo-funx": {
        "match": ["FunX", "NPO FunX"],
        "genre": "urban", "region": "national", "dial": 103.7,
        "tags": ["public", "urban", "hiphop", "young"],
        "stream": "https://icecast.omroep.nl/funx-bb-mp3",
        "logo": "https://www.funx.nl/_next/static/media/funx-logo.svg",
    },
    "npo-souljazz": {
        "match": ["NPO Soul & Jazz", "Radio 6"],
        "genre": "soulJazz", "region": "national", "dial": None,
        "tags": ["public", "soul", "jazz"],
        "stream": "https://icecast.omroep.nl/radio6-bb-mp3",
        "logo": None,
    },
    # ===== Commercieel landelijk =====
    "sky-radio": {
        "match": ["Sky Radio"],
        "genre": "hits", "region": "national", "dial": 101.2,
        "tags": ["commercial", "hits", "pop"],
        "stream": None,  # Pak uit Radio-Browser
        "logo": "https://www.skyradio.nl/sites/skyradio/themes/sky_radio_theme/logo.svg",
    },
    "radio538": {
        "match": ["Radio 538", "538"],
        "genre": "top40", "region": "national", "dial": 102.1,
        "tags": ["commercial", "top40", "dance"],
        "stream": None,
        "logo": "https://538.nl/img/538-logo.svg",
    },
    "qmusic": {
        "match": ["Qmusic", "Q-music", "Q music Nederland"],
        "genre": "hits", "region": "national", "dial": 100.7,
        "tags": ["commercial", "hits", "comedy"],
        "stream": None,
        "logo": "https://qmusic.nl/static/images/logo-qmusic.svg",
    },
    "radio10": {
        "match": ["Radio 10"],
        "genre": "oldies", "region": "national", "dial": None,
        "tags": ["commercial", "70s", "80s", "90s"],
        "stream": None,
        "logo": "https://www.radio10.nl/themes/custom/radio10/logo.svg",
    },
    "radio-veronica": {
        "match": ["Radio Veronica", "Veronica"],
        "genre": "rock", "region": "national", "dial": 103.4,
        "tags": ["commercial", "rock", "classics"],
        "stream": None,
        "logo": "https://www.radioveronica.nl/themes/custom/veronica/logo.svg",
    },
    "100pct-nl": {
        "match": ["100% NL", "100%NL"],
        "genre": "dutch", "region": "national", "dial": None,
        "tags": ["commercial", "dutch", "nederlandstalig"],
        "stream": "https://stream.100p.nl/100pctnl.mp3",
        "logo": "https://100p.nl/themes/custom/honderd_procent_nl/logo.svg",
    },
    "slamfm": {
        "match": ["SLAM!", "SLAM FM"],
        "genre": "dance", "region": "national", "dial": None,
        "tags": ["commercial", "dance", "edm"],
        "stream": "https://stream.slam.nl/slam_mp3_hi",
        "logo": "https://www.slam.nl/themes/custom/slam/logo.svg",
    },
    "bnr": {
        "match": ["BNR Nieuwsradio", "BNR"],
        "genre": "business", "region": "national", "dial": 87.9,
        "tags": ["commercial", "news", "business"],
        "stream": None,
        "logo": "https://www.bnr.nl/static/images/bnr-logo.svg",
    },
    "sublime": {
        "match": ["Sublime", "Sublime FM"],
        "genre": "soulJazz", "region": "national", "dial": None,
        "tags": ["commercial", "soul", "jazz"],
        "stream": None,
        "logo": "https://sublime.nl/themes/custom/sublime/logo.svg",
    },
    "kink": {
        "match": ["KINK"],
        "genre": "alternative", "region": "national", "dial": None,
        "tags": ["online", "alternative", "rock"],
        "stream": None,
        "logo": "https://kink.nl/themes/custom/kink/logo.svg",
    },
    "joe": {
        "match": ["JOE", "JOE FM"],
        "genre": "popClassics", "region": "national", "dial": None,
        "tags": ["commercial", "classics", "feelgood"],
        "stream": None,
        "logo": None,
    },
    "arrow-classic": {
        "match": ["Arrow Classic Rock"],
        "genre": "rock", "region": "national", "dial": None,
        "tags": ["online", "rock", "classics"],
        "stream": None,
        "logo": None,
    },
    "radio-nl": {
        "match": ["RadioNL", "Radio NL"],
        "genre": "dutch", "region": "national", "dial": None,
        "tags": ["commercial", "dutch"],
        "stream": None,
        "logo": None,
    },
    "decibel": {
        "match": ["Decibel"],
        "genre": "dance", "region": "national", "dial": None,
        "tags": ["commercial", "hardstyle", "dance"],
        "stream": None,
        "logo": None,
    },
    # "jukebox-radio" verwijderd: niet meer in Radio-Browser DB.
    #
    # NPO Soul & Jazz (Radio 6) is hierboven al gedefinieerd.
    "radio-noordzee": {
        "match": ["Radio Noordzee", "Noordzee FM"],
        "genre": "popClassics", "region": "national", "dial": None,
        "tags": ["online", "classics"],
        "stream": None,
        "logo": None,
    },
    # ===== Regionaal =====
    "nh-radio": {
        "match": ["NH Radio", "RTV Noord Holland (NH Radio)", "NH Nieuws Radio"],
        "genre": "regional", "region": "noordHolland", "dial": 87.9,
        "tags": ["regional", "noord-holland"],
        "stream": None,
        "logo": None,
    },
    "omroep-brabant": {
        "match": ["Omroep Brabant Radio", "Omroep Brabant"],
        "genre": "regional", "region": "noordBrabant", "dial": 97.5,
        "tags": ["regional", "brabant"],
        "stream": None,
        "logo": None,
    },
    "rtv-rijnmond": {
        "match": ["Radio Rijnmond", "Rijnmond Radio"],
        "genre": "regional", "region": "zuidHolland", "dial": 93.4,
        "tags": ["regional", "rotterdam", "rijnmond"],
        "stream": None,
        "logo": None,
    },
    "omroep-west": {
        "match": ["Omroep West", "Radio West"],
        "genre": "regional", "region": "zuidHolland", "dial": 89.3,
        "tags": ["regional", "den-haag"],
        "stream": None,
        "logo": None,
    },
    "rtv-utrecht": {
        "match": ["Radio M Utrecht", "RTV Utrecht"],
        "genre": "regional", "region": "utrecht", "dial": 93.1,
        "tags": ["regional", "utrecht"],
        "stream": None,
        "logo": None,
    },
    "omroep-gelderland": {
        "match": ["Omroep Gelderland", "Radio Gelderland"],
        "genre": "regional", "region": "gelderland", "dial": 89.2,
        "tags": ["regional", "gelderland"],
        "stream": None,
        "logo": None,
    },
    "rtv-oost": {
        "match": ["RTV Oost", "Radio Oost"],
        "genre": "regional", "region": "overijssel", "dial": 89.4,
        "tags": ["regional", "overijssel"],
        "stream": None,
        "logo": None,
    },
    "rtv-drenthe": {
        "match": ["RTV Drenthe", "Radio Drenthe"],
        "genre": "regional", "region": "drenthe", "dial": 91.6,
        "tags": ["regional", "drenthe"],
        "stream": None,
        "logo": None,
    },
    "rtv-noord": {
        "match": ["RTV Noord", "Radio Noord"],
        "genre": "regional", "region": "groningen", "dial": 95.4,
        "tags": ["regional", "groningen"],
        "stream": None,
        "logo": None,
    },
    "omrop-fryslan": {
        "match": ["Omrop Fryslan", "Omrop Fryslân"],
        "genre": "regional", "region": "friesland", "dial": 92.2,
        "tags": ["regional", "friesland", "frysk"],
        "stream": None,
        "logo": None,
    },
    "l1": {
        "match": ["L1 Radio", "L1 Limburg"],
        "genre": "regional", "region": "limburg", "dial": 95.3,
        "tags": ["regional", "limburg"],
        "stream": None,
        "logo": None,
    },
    "omroep-zeeland": {
        "match": ["Omroep Zeeland Radio", "Omroep Zeeland", "Radio Zeeland"],
        "genre": "regional", "region": "zeeland", "dial": 87.9,
        "tags": ["regional", "zeeland"],
        "stream": None,
        "logo": None,
    },
    # Omroep Flevoland is uitgesloten: stream URL niet bereikbaar vanuit publieke internet
    # (zowel de officiele icecast als de streamtheworld variant zijn dood/geblokkeerd).
    # User kan hem handmatig toevoegen via de "Aangepaste zender" feature.
}


def normalize_name(name: str) -> str:
    """Lowercased, alphanumeric-only naam voor matching."""
    name = name.lower()
    name = re.sub(r"[^a-z0-9]", "", name)
    return name


def fetch_radio_browser(host: str) -> list[dict[str, Any]] | None:
    # Geen clickcount sort en geen limit: pak alles van NL en filter zelf.
    url = f"https://{host}/json/stations/bycountrycodeexact/NL?hidebroken=true&order=votes&reverse=true&limit=2000"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.loads(r.read().decode("utf-8"))
    except Exception as e:
        print(f"  Mirror {host} faalde: {e}", file=sys.stderr)
        return None


def get_nl_stations() -> list[dict[str, Any]]:
    for host in RADIO_BROWSER_HOSTS:
        result = fetch_radio_browser(host)
        if result:
            print(f"Geladen: {len(result)} stations via {host}")
            return result
    raise RuntimeError("Geen Radio-Browser mirror bereikbaar")


def best_match(stations: list[dict[str, Any]], names_to_match: list[str]) -> dict[str, Any] | None:
    """Vind de beste Radio-Browser entry voor een whitelist-entry.
    Match strategy: exact normalized > substring, gewogen op clickcount/bitrate/favicon-aanwezigheid."""
    normalized_targets = [normalize_name(n) for n in names_to_match]

    def score(s: dict[str, Any], exact: bool) -> float:
        clicks = s.get("clickcount", 0) or 0
        bitrate = s.get("bitrate", 0) or 0
        has_favicon = 1 if (s.get("favicon") or "").strip() else 0
        last_ok = 1 if s.get("lastcheckok") == 1 else 0
        exact_bonus = 100_000 if exact else 0
        # Volgorde: exact-match > favicon > lastcheckok > clicks > bitrate
        return exact_bonus + has_favicon * 50_000 + last_ok * 10_000 + clicks * 100 + bitrate

    candidates: list[tuple[float, dict[str, Any]]] = []
    # Exact matches (hoogste prioriteit via score)
    for s in stations:
        norm = normalize_name(s.get("name", ""))
        if norm in normalized_targets:
            candidates.append((score(s, exact=True), s))
    # Substring fallback alleen als geen exact matches
    if not candidates:
        for s in stations:
            norm = normalize_name(s.get("name", ""))
            for target in normalized_targets:
                if target and target in norm and len(target) > 3:
                    candidates.append((score(s, exact=False), s))
                    break

    if not candidates:
        return None
    candidates.sort(key=lambda x: x[0], reverse=True)
    return candidates[0][1]


def test_stream(url: str, timeout: float = 6.0) -> tuple[bool, str]:
    """Verifieer dat een stream URL daadwerkelijk audio data returnt.
    Accepteert ook FLV-wrapped en HLS-streams omdat AVPlayer die afspeelt."""
    streaming_mimes = (
        "audio/",
        "application/ogg",
        "application/flv",          # FLV-wrapped AAC (oa Veronica)
        "application/octet-stream", # generieke binary stream
        "video/mp2t",               # MPEG-TS HLS segment
        "application/vnd.apple.mpegurl",
        "application/x-mpegurl",
        "application/x-scpls",
        "audio/x-mpegurl",
    )
    try:
        req = urllib.request.Request(url, headers={
            "User-Agent": UA,
            "Icy-MetaData": "1",
            "Range": "bytes=0-1023",
        })
        with urllib.request.urlopen(req, timeout=timeout) as r:
            content_type = r.headers.get("Content-Type", "").lower()
            data = r.read(1024)
            if any(t in content_type for t in streaming_mimes):
                return True, content_type
            # Shoutcast servers met text/html maar wel ICY metadata
            if "icy-name" in {k.lower() for k in r.headers.keys()}:
                return True, content_type or "icy"
            # MP3 magic bytes
            if data[:3] == b"ID3" or (data[:2] == b"\xff\xfb") or (data[:2] == b"\xff\xfa"):
                return True, content_type or "audio/mpeg (magic)"
            # AAC ADTS magic bytes
            if len(data) >= 2 and (data[0] == 0xFF and (data[1] & 0xF0) == 0xF0):
                return True, content_type or "audio/aac (magic)"
            # OGG magic bytes
            if data[:4] == b"OggS":
                return True, content_type or "audio/ogg (magic)"
            # FLV magic bytes
            if data[:3] == b"FLV":
                return True, content_type or "application/flv (magic)"
            return False, f"unexpected content-type: {content_type}"
    except urllib.error.HTTPError as e:
        return False, f"HTTP {e.code}"
    except urllib.error.URLError as e:
        return False, f"URLError: {e.reason}"
    except TimeoutError:
        return False, "timeout"
    except Exception as e:
        return False, f"error: {e}"


def codec_for(raw: str) -> str:
    raw = (raw or "").lower()
    if raw == "mp3": return "mp3"
    if raw == "aac": return "aac"
    if raw in ("aac+", "he-aac", "heaac"): return "heAac"
    if raw in ("ogg", "vorbis"): return "ogg"
    if raw == "hls": return "hls"
    return "unknown"


def main() -> int:
    print(">>> Stap 1: NL stations ophalen via Radio-Browser...")
    rb_stations = get_nl_stations()

    print()
    print(">>> Stap 2: Whitelist matchen tegen Radio-Browser data...")
    resolved: list[dict[str, Any]] = []
    for station_id, entry in WHITELIST.items():
        match = best_match(rb_stations, entry["match"])
        stream_url = entry.get("stream")
        favicon = None
        bitrate = None
        codec = "mp3"
        rb_name = entry["match"][0]

        if match:
            rb_name = match.get("name", rb_name).strip()
            favicon = match.get("favicon") or None
            bitrate = match.get("bitrate") or None
            codec = codec_for(match.get("codec", "mp3"))
            if not stream_url:
                stream_url = (match.get("url_resolved") or match.get("url") or "").strip()
        else:
            print(f"  GEEN MATCH voor {station_id} ({entry['match'][0]})")

        if not stream_url:
            print(f"  GEEN STREAM voor {station_id}, overslaan")
            continue

        logo = favicon if favicon else entry.get("logo")
        resolved.append({
            "id": station_id,
            "name": rb_name,
            "_match_names": entry["match"],
            "streamURL": stream_url,
            "logoURL": logo,
            "homepageURL": None,
            "genre": entry["genre"],
            "region": entry["region"],
            "dial": entry.get("dial"),
            "bitrate": bitrate or 128,
            "codec": codec,
            "source": "curated",
            "tags": entry["tags"],
        })
        print(f"  OK {station_id:<20} | {rb_name[:30]:<30} | {bitrate or '?':>4} kbps | logo={'yes' if logo else 'no '} | rb_match={'yes' if match else 'no '}")

    print()
    print(">>> Stap 3: Live stream verificatie...")
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as ex:
        futures = {ex.submit(test_stream, s["streamURL"]): s for s in resolved}
        for fut in concurrent.futures.as_completed(futures):
            station = futures[fut]
            ok, info = fut.result()
            station["_works"] = ok
            station["_check_info"] = info
            status = "OK   " if ok else "FAIL "
            print(f"  {status} {station['id']:<20} | {info[:60]}")

    working = [s for s in resolved if s.get("_works")]
    broken = [s for s in resolved if not s.get("_works")]
    print()
    print(f">>> {len(working)} werkende, {len(broken)} kapotte streams")

    if broken:
        print()
        print("Kapotte streams (worden eruit gefilterd):")
        for s in broken:
            print(f"  - {s['id']}: {s['_check_info']}")

    print()
    print(">>> Stap 4: curated-stations.json schrijven...")
    final = []
    for s in working:
        # Strip de internal underscore-velden voor de output
        clean = {k: v for k, v in s.items() if not k.startswith("_")}
        final.append(clean)

    bundle = {
        "version": 2,
        "updatedAt": date.today().isoformat(),
        "stations": final,
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(bundle, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"  Geschreven naar {OUTPUT}")
    print(f"  {len(final)} stations totaal")
    return 0


if __name__ == "__main__":
    sys.exit(main())
