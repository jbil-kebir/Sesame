"""
check_catalogues.py — Vérifie l'accessibilité de tous les liens des catalogues Sésame.

Usage :
    python check_catalogues.py [--token TOKEN]

Le token GitHub est optionnel (dépôt public). Il accélère la récupération des
catalogues en évitant le rate-limit de l'API GitHub anonyme.

Critères "lien cassé" :
  - Timeout / erreur réseau / DNS introuvable
  - HTTP 404, 410, 5xx
Exclus (lien considéré OK) :
  - 401, 403 (ressource protégée mais existante)
  - 3xx (redirections suivies automatiquement)
  - 200, 206, etc.

Rapport : affiché dans la console ET sauvegardé dans doc/rapports/
"""

import argparse
import asyncio
import json
import os
import sys
import urllib.request
import base64
from datetime import datetime
from pathlib import Path

# Force UTF-8 sur la console Windows
if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

# ── Dépendance optionnelle : aiohttp pour les vérifications parallèles ─────────
try:
    import aiohttp
    HAS_AIOHTTP = True
except ImportError:
    HAS_AIOHTTP = False

GITHUB_API = "https://api.github.com/repos/jbil-kebir/Sesame/contents/catalogues"
TIMEOUT = 10          # secondes par requête
CONCURRENCY = 10      # requêtes HEAD parallèles max

CODES_CASSES = {404, 410, 500, 502, 503, 504}


# ── Récupération des catalogues depuis GitHub ──────────────────────────────────

def github_get(path: str, token: str | None) -> bytes:
    headers = {"User-Agent": "SesameChecker/1.0"}
    if token:
        headers["Authorization"] = f"token {token}"
    req = urllib.request.Request(path, headers=headers)
    with urllib.request.urlopen(req, timeout=15) as r:
        return r.read()


def fetch_catalogues(token: str | None) -> list[dict]:
    """Retourne la liste des catalogues : [{nom, catalogue_id, shortcuts:[{label,url}]}]"""
    raw = github_get(GITHUB_API, token)
    files = json.loads(raw)

    # Lire index.json pour avoir les noms lisibles
    index_entry = next((f for f in files if f["name"] == "index.json"), None)
    index_map = {}
    if index_entry:
        raw_index = github_get(index_entry["url"], token)
        meta = json.loads(raw_index)
        content = base64.b64decode(meta["content"]).decode("utf-8")
        for entry in json.loads(content):
            index_map[entry["id"]] = entry["nom"]

    catalogues = []
    for f in files:
        if not f["name"].endswith(".catalogue"):
            continue
        cat_id = f["name"].replace(".catalogue", "")
        raw_cat = github_get(f["url"], token)
        meta = json.loads(raw_cat)
        content = base64.b64decode(meta["content"]).decode("utf-8")
        data = json.loads(content)

        shortcuts = []
        for cat in data.get("categories", []):
            for s in cat.get("shortcuts", []):
                shortcuts.append({
                    "label": s["label"],
                    "url": s["url"],
                    "categorie": cat["label"],
                })

        catalogues.append({
            "id": cat_id,
            "nom": index_map.get(cat_id, cat_id),
            "shortcuts": shortcuts,
        })

    return catalogues


# ── Vérification des URLs ──────────────────────────────────────────────────────

async def check_url_aiohttp(session: "aiohttp.ClientSession", shortcut: dict) -> dict:
    url = shortcut["url"]
    try:
        async with session.head(url, allow_redirects=True, timeout=aiohttp.ClientTimeout(total=TIMEOUT)) as resp:
            code = resp.status
            if code in CODES_CASSES:
                return {**shortcut, "statut": "CASSE", "code": code, "detail": f"HTTP {code}"}
            return {**shortcut, "statut": "OK", "code": code, "detail": ""}
    except asyncio.TimeoutError:
        return {**shortcut, "statut": "CASSE", "code": None, "detail": "Delai depasse"}
    except aiohttp.ClientConnectorError as e:
        return {**shortcut, "statut": "CASSE", "code": None, "detail": f"Connexion impossible : {e.os_error}".encode("ascii", "replace").decode("ascii")}
    except Exception as e:
        return {**shortcut, "statut": "CASSE", "code": None, "detail": str(e)}


async def check_all_aiohttp(shortcuts: list[dict]) -> list[dict]:
    sem = asyncio.Semaphore(CONCURRENCY)
    connector = aiohttp.TCPConnector(ssl=False)
    headers = {
        "User-Agent": "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 "
                      "(KHTML, like Gecko) Chrome/131.0.6778.135 Mobile Safari/537.36"
    }
    async with aiohttp.ClientSession(connector=connector, headers=headers) as session:
        async def bounded(s):
            async with sem:
                return await check_url_aiohttp(session, s)
        return await asyncio.gather(*[bounded(s) for s in shortcuts])


def check_url_urllib(shortcut: dict) -> dict:
    """Fallback synchrone si aiohttp n'est pas installé."""
    import socket
    url = shortcut["url"]
    req = urllib.request.Request(url, method="HEAD", headers={
        "User-Agent": "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 "
                      "(KHTML, like Gecko) Chrome/131.0.6778.135 Mobile Safari/537.36"
    })
    try:
        ctx = urllib.request.ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = urllib.request.ssl.CERT_NONE
        with urllib.request.urlopen(req, timeout=TIMEOUT, context=ctx) as r:
            code = r.status
            if code in CODES_CASSES:
                return {**shortcut, "statut": "CASSE", "code": code, "detail": f"HTTP {code}"}
            return {**shortcut, "statut": "OK", "code": code, "detail": ""}
    except urllib.error.HTTPError as e:
        if e.code in CODES_CASSES:
            return {**shortcut, "statut": "CASSE", "code": e.code, "detail": f"HTTP {e.code}"}
        return {**shortcut, "statut": "OK", "code": e.code, "detail": ""}
    except urllib.error.URLError as e:
        return {**shortcut, "statut": "CASSE", "code": None, "detail": str(e.reason)}
    except socket.timeout:
        return {**shortcut, "statut": "CASSE", "code": None, "detail": "Delai depasse"}
    except Exception as e:
        return {**shortcut, "statut": "CASSE", "code": None, "detail": str(e)}


def check_all_urllib(shortcuts: list[dict]) -> list[dict]:
    results = []
    total = len(shortcuts)
    for i, s in enumerate(shortcuts, 1):
        print(f"  [{i}/{total}] {s['label']}...", end="\r")
        results.append(check_url_urllib(s))
    print()
    return results


# ── Rapport ───────────────────────────────────────────────────────────────────

def generer_rapport(catalogues: list[dict], resultats: dict[str, list[dict]]) -> str:
    ts = datetime.now().strftime("%d/%m/%Y %H:%M")
    lines = [f"Rapport Sesame -- {ts}", "=" * 60, ""]

    total_ok = total_casse = 0

    for cat in catalogues:
        res = resultats[cat["id"]]
        casses = [r for r in res if r["statut"] == "CASSE"]
        ok = len(res) - len(casses)
        total_ok += ok
        total_casse += len(casses)

        lines.append(f"[{cat['nom']}]  ({ok}/{len(res)} OK)")
        if casses:
            for r in casses:
                code_str = f"HTTP {r['code']}" if r["code"] else r["detail"]
                lines.append(f"   ERREUR : {r['label']}")
                lines.append(f"     {r['url']}")
                lines.append(f"     Detail : {code_str}")
        else:
            lines.append("   Tous les liens sont accessibles.")
        lines.append("")

    lines.append("-" * 60)
    total = total_ok + total_casse
    lines.append(f"Resultat global : {total_ok}/{total} liens OK, {total_casse} lien(s) inaccessible(s)")
    return "\n".join(lines)


# ── Point d'entrée ─────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Vérifie les liens des catalogues Sésame.")
    parser.add_argument("--token", default=None, help="Token GitHub (optionnel)")
    args = parser.parse_args()

    # Cherche le token dans l'env si non fourni en argument
    token = args.token or os.environ.get("GITHUB_TOKEN")

    print("Récupération des catalogues depuis GitHub...")
    try:
        catalogues = fetch_catalogues(token)
    except Exception as e:
        print(f"Erreur lors de la récupération des catalogues : {e}", file=sys.stderr)
        sys.exit(1)

    total_liens = sum(len(c["shortcuts"]) for c in catalogues)
    print(f"{len(catalogues)} catalogue(s), {total_liens} lien(s) à vérifier.")

    if HAS_AIOHTTP:
        print(f"Vérification en parallèle (aiohttp, {CONCURRENCY} connexions simultanées)...")
    else:
        print("Vérification séquentielle (installez aiohttp pour accélérer)...")

    resultats = {}
    for cat in catalogues:
        print(f"\n  Catalogue : {cat['nom']}")
        if HAS_AIOHTTP:
            res = asyncio.run(check_all_aiohttp(cat["shortcuts"]))
        else:
            res = check_all_urllib(cat["shortcuts"])
        resultats[cat["id"]] = res
        casses = sum(1 for r in res if r["statut"] == "CASSE")
        print(f"  -> {len(res) - casses}/{len(res)} OK", end="")
        if casses:
            print(f", {casses} casse(s)")
        else:
            print()

    rapport = generer_rapport(catalogues, resultats)
    print("\n" + rapport)

    rapport_dir = Path(__file__).parent / "rapports"
    rapport_dir.mkdir(parents=True, exist_ok=True)
    ts_file = datetime.now().strftime("%Y%m%d_%H%M%S")
    rapport_path = rapport_dir / f"rapport_{ts_file}.txt"
    rapport_path.write_text(rapport, encoding="utf-8")
    print(f"\nRapport sauvegardé : {rapport_path}")


if __name__ == "__main__":
    main()
