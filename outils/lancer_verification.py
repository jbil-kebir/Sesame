"""
lancer_verification.py — Lance la vérification des catalogues puis envoie
le rapport par mail via Claude Code (MCP thunderbird-mail, sendMail skipReview).

Appelé automatiquement par le Planificateur de tâches Windows chaque mercredi.
"""

import subprocess
import sys
import json
from pathlib import Path
from datetime import datetime

SCRIPT_DIR = Path(__file__).parent
EXPEDITEUR = "jbil.kebir@protonmail.com"
DESTINATAIRE = "jbil.kebir@pm.me"
THUNDERBIRD = r"C:\Program Files\Mozilla Thunderbird\thunderbird.exe"
TOKEN_FILE = Path(r"D:\Developpement\Token pour Claude.txt")


def lire_token() -> str:
    if TOKEN_FILE.exists():
        return TOKEN_FILE.read_text(encoding="utf-8").strip()
    return ""


def assurer_thunderbird_ouvert():
    """Démarre Thunderbird s'il n'est pas déjà en cours d'exécution."""
    import time
    result = subprocess.run(
        ["tasklist", "/FI", "IMAGENAME eq thunderbird.exe", "/NH"],
        capture_output=True, text=True
    )
    if "thunderbird.exe" not in result.stdout.lower():
        print("Thunderbird ferme, demarrage en cours...")
        subprocess.Popen([THUNDERBIRD])
        time.sleep(8)  # attendre que l'extension MCP soit prête


def extraire_resume(rapport_text: str) -> str:
    """Extrait la ligne de résultat global pour le sujet du mail."""
    for line in rapport_text.splitlines():
        if line.startswith("Resultat global"):
            return line
    return ""


def main():
    token = lire_token()

    assurer_thunderbird_ouvert()

    # Lancement de la vérification
    args = [sys.executable, str(SCRIPT_DIR / "check_catalogues.py")]
    if token:
        args += ["--token", token]
    subprocess.run(args, check=True)

    # Récupération du rapport le plus récent
    rapports = sorted((SCRIPT_DIR / "rapports").glob("rapport_*.txt"))
    if not rapports:
        print("Aucun rapport trouvé après vérification.", file=sys.stderr)
        sys.exit(1)
    latest = rapports[-1]
    rapport_text = latest.read_text(encoding="utf-8")

    date_str = datetime.now().strftime("%d/%m/%Y")
    resume = extraire_resume(rapport_text)
    subject = f"Sesame {date_str} -- {resume}"

    # Envoi via Claude Code (MCP thunderbird-mail sendMail skipReview)
    prompt = (
        f"Utilise l'outil MCP thunderbird-mail sendMail pour envoyer ce mail sans review "
        f"(skipReview: true) :\n"
        f"- from: {EXPEDITEUR}\n"
        f"- to: {DESTINATAIRE}\n"
        f"- subject: {subject}\n"
        f"- body (texte brut) :\n{rapport_text}\n"
        f"- attachments: [\"{latest}\"]\n"
        f"Ne fais rien d'autre."
    )

    subprocess.run(
        ["claude", "--dangerously-skip-permissions", "-p", prompt],
        check=True,
    )


if __name__ == "__main__":
    main()
