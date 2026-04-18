# Outils de maintenance Sésame / Sésame Maintenance Tools

Scripts Python de vérification et d'envoi automatique des rapports de liens des catalogues.  
Python scripts for automated catalogue link verification and report delivery.

---

## Prérequis / Prerequisites

- Python 3.10+
- *(optionnel / optional)* [`aiohttp`](https://docs.aiohttp.org/) — vérification parallèle (x10 plus rapide) / parallel checking (10× faster)

```bash
pip install aiohttp
```

---

## Scripts

### `check_catalogues.py` — Vérification des liens / Link checker

Récupère tous les catalogues depuis GitHub et vérifie l'accessibilité de chaque lien.  
Fetches all catalogues from GitHub and checks whether each link is reachable.

**Usage :**
```bash
python check_catalogues.py [--token TOKEN]
```

- `--token` : token GitHub (optionnel, accélère les appels API en évitant le rate-limit).  
  La variable d'environnement `GITHUB_TOKEN` est également acceptée.  
  GitHub token (optional, avoids API rate-limiting). The `GITHUB_TOKEN` environment variable is also supported.

**Critères "lien cassé" / Broken link criteria :**
- Timeout, erreur réseau, DNS introuvable / Timeout, network error, DNS failure
- HTTP 404, 410, 5xx
- Redirection d'un sous-domaine spécifique vers le domaine racine du même site  
  *(ex : `clg-xxx.monbureaunumerique.fr` → `www.monbureaunumerique.fr`)*  
  Redirect from a specific subdomain to the root domain of the same site

**Considérés OK / Considered OK :**
- HTTP 401, 403 (ressource protégée mais existante / protected but existing resource)
- Redirections cross-domaine légitimes, ex. Pronote → CAS / Legitimate cross-domain redirects

**Limitation connue / Known limitation :**  
Les *soft 404* (serveur retourne HTTP 200 avec une page d'erreur générique) ne sont pas détectés.  
Cela concerne notamment certains portails ENT qui affichent une page "portail générique" au lieu de renvoyer une erreur HTTP.  
*Soft 404s (server returns HTTP 200 with a generic error page) are not detected. This affects some ENT portals that display a generic landing page instead of returning an HTTP error.*

**Rapport :**  
Affiché dans la console et sauvegardé dans `outils/rapports/rapport_YYYYMMDD_HHMMSS.txt`.  
Displayed in the console and saved to `outils/rapports/rapport_YYYYMMDD_HHMMSS.txt`.

---

### `lancer_verification.py` — Lancement automatique / Automated launcher

Lance `check_catalogues.py` puis envoie le rapport par mail via le MCP Thunderbird.  
Runs `check_catalogues.py` then sends the report by email via the Thunderbird MCP.

**Configuration (en tête du fichier / at the top of the file) :**

| Variable | Description |
|----------|-------------|
| `EXPEDITEUR` | Adresse mail expéditeur / Sender address |
| `DESTINATAIRE` | Adresse mail destinataire / Recipient address |
| `THUNDERBIRD` | Chemin vers l'exécutable Thunderbird / Path to Thunderbird executable |
| `TOKEN_FILE` | Chemin vers le fichier contenant le token GitHub / Path to GitHub token file |

**Dépendances :**
- [Claude Code](https://claude.ai/code) installé (`claude` accessible dans le PATH)
- MCP `thunderbird-mail` configuré dans Claude Code (scope utilisateur) :
  ```bash
  claude mcp add thunderbird-mail -s user node D:\IA\thunderbird-mcp\mcp-bridge.cjs
  ```
- Thunderbird installé (démarré automatiquement si fermé / auto-started if closed)

**Sujet du mail / Email subject :**  
`Sésame DD/MM/YYYY -- Resultat global : X/Y liens OK, N lien(s) inaccessible(s)`

---

## Automatisation / Automation

### Windows — Planificateur de tâches / Task Scheduler

Exécution automatique chaque mercredi à 19h, dès que le PC est allumé.  
Automatic execution every Wednesday at 7 PM, as soon as the PC is on.

```powershell
$action = New-ScheduledTaskAction `
    -Execute "python" `
    -Argument '"U:\Info-Developpement\GitHub\Sesame\outils\lancer_verification.py"'

$trigger = New-ScheduledTaskTrigger `
    -Weekly -DaysOfWeek Wednesday -At "19:00"

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1)

Register-ScheduledTask `
    -TaskName "Sesame-VerificationCatalogues" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -RunLevel Highest `
    -Force
```

---

## Structure des fichiers / File structure

```
outils/
├── check_catalogues.py      # Vérificateur de liens / Link checker
├── lancer_verification.py   # Lanceur automatique + envoi mail / Auto-launcher + email
├── rapports/                # Rapports générés (ignoré par git) / Generated reports (git-ignored)
│   └── rapport_*.txt
└── README.md                # Ce fichier / This file
```

---

## Format du rapport / Report format

```
Rapport Sesame -- DD/MM/YYYY HH:MM
============================================================

[Nom du catalogue] (id.catalogue)  (N/N OK)
   Tous les liens sont accessibles.

[Nom du catalogue] (id.catalogue)  (X/N OK)
   ERREUR : Nom du raccourci
     https://url-du-lien
     Detail : HTTP 404

------------------------------------------------------------
Resultat global : X/Y liens OK, N lien(s) inaccessible(s)
```
