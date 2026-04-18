"""
lancer_verification.py — Lance la vérification des catalogues et ouvre
Thunderbird avec le rapport prêt à envoyer.

Appelé automatiquement par le Planificateur de tâches Windows chaque mercredi.
"""

import subprocess
import sys
from pathlib import Path
from datetime import datetime

SCRIPT_DIR = Path(__file__).parent
THUNDERBIRD = r"C:\Program Files\Mozilla Thunderbird\thunderbird.exe"
EXPEDITEUR = "jbil.kebir@pm.me"
DESTINATAIRE = "jbil.kebir@protonmail.com"

TOKEN_FILE = Path(r"D:\Developpement\Token pour Claude.txt")


def lire_token() -> str:
    if TOKEN_FILE.exists():
        return TOKEN_FILE.read_text(encoding="utf-8").strip()
    return ""


def main():
    token = lire_token()

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

    # Construction de la commande Thunderbird -compose
    date_str = datetime.now().strftime("%d/%m/%Y")
    subject = f"Rapport Sesame -- {date_str}"

    # Encodage du corps pour Thunderbird (les sauts de ligne deviennent %0A)
    body = rapport_text.replace("%", "%25").replace("'", "%27").replace("\r\n", "%0A").replace("\n", "%0A")
    attachment = latest.as_uri()  # file:///U:/...

    compose = (
        f"to='{DESTINATAIRE}',"
        f"from='{EXPEDITEUR}',"
        f"subject='{subject}',"
        f"body='{body}',"
        f"attachment='{attachment}'"
    )

    subprocess.Popen([THUNDERBIRD, "-compose", compose])


if __name__ == "__main__":
    main()
