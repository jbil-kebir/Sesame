# Documentation développeur — Sésame

## Vue d'ensemble

**Sésame** est une application Android développée avec Flutter. Elle permet de créer des raccourcis vers des pages web favorites et de les ouvrir dans une WebView intégrée, avec gestion automatique des identifiants de connexion. L'accès à l'application est protégé par un code PIN avec biométrie optionnelle. Des catalogues de raccourcis peuvent être téléchargés depuis un dépôt GitHub public.

---

## Stack technique

| Élément | Valeur |
|---|---|
| Framework | Flutter |
| Langage | Dart |
| SDK Dart minimum | ^3.11.0 |
| Cible principale | Android |
| Version application | 2.0 |

### Dépendances

| Package | Version | Rôle |
|---|---|---|
| `flutter_inappwebview` | ^6.0.0 | Affichage de pages web (WebView système Android), HTTP auth, download listener |
| `open_filex` | ^4.7.0 | Ouverture des fichiers téléchargés dans l'application système appropriée |
| `shared_preferences` | ^2.3.0 | Persistance locale des raccourcis (JSON) et préférences |
| `flutter_secure_storage` | ^9.0.0 | Stockage chiffré des mots de passe et du hash PIN (AES / Keystore Android) |
| `package_info_plus` | ^8.0.0 | Lecture de la version applicative depuis pubspec.yaml |
| `encrypt` | ^5.0.0 | Chiffrement AES-256-CBC |
| `crypto` | ^3.0.0 | Dérivation de clé PBKDF2-HMAC-SHA256, hash SHA-256 |
| `share_plus` | ^10.0.0 | Partage du fichier d'export via la feuille Android |
| `path_provider` | ^2.0.0 | Dossier temporaire pour l'écriture du fichier d'export |
| `file_picker` | ^8.0.0 | Sélection du fichier à l'import |
| `url_launcher` | ^6.0.0 | Ouverture des liens intent:// et navigation externe |
| `local_auth` | ^2.3.0 | Authentification biométrique (empreinte digitale) |
| `http` | ^1.2.0 | Téléchargement de l'index et des catalogues en ligne |

### Dépendances de développement

| Package | Version | Rôle |
|---|---|---|
| `flutter_launcher_icons` | ^0.14.0 | Génération automatique des icônes Android dans toutes les résolutions |

---

## Architecture

```
lib/
├── main.dart
├── models/
│   ├── raccourci.dart
│   ├── catalogue.dart
│   └── catalogue_en_ligne.dart
├── services/
│   ├── storage_service.dart
│   ├── export_service.dart
│   ├── catalogue_service.dart
│   ├── catalogue_en_ligne_service.dart
│   └── pin_service.dart
└── screens/
    ├── home_screen.dart
    ├── webview_screen.dart
    ├── catalogue_screen.dart
    ├── catalogues_en_ligne_screen.dart
    ├── lock_screen.dart
    └── pin_setup_screen.dart
```

---

## Description des fichiers

### `lib/main.dart`

Point d'entrée. `AppRouter` choisit l'écran initial selon l'état de l'application :

| État | Destination |
|---|---|
| `onboarding_done == false` | `CatalogueScreen` (premier lancement) |
| `onboarding_done == true` et PIN non configuré | `PinSetupScreen` |
| `onboarding_done == true` et PIN configuré | `LockScreen` |

La route nommée `/home` pointe vers `PinSetupScreen` : elle est utilisée par `CatalogueScreen` à la fin de l'onboarding pour enchaîner obligatoirement sur la configuration du PIN.

L'écran de démarrage (pendant le routage) utilise le fond bleu de l'application pour éviter le flash blanc.

---

### `lib/models/raccourci.dart`

Modèle `Raccourci` :

| Champ | Type | Description |
|---|---|---|
| `id` | `String` | Identifiant unique (timestamp en ms) |
| `nom` | `String` | Nom affiché sur la carte |
| `url` | `String` | URL complète de la page web |
| `login` | `String?` | Identifiant de connexion (optionnel) |
| `estSeparateur` | `bool` | `true` si l'entrée est un séparateur visuel (défaut : `false`) |

Le mot de passe n'est **pas** stocké dans le modèle : il est géré séparément par `StorageService` via `flutter_secure_storage`, indexé par l'`id` du raccourci.

Un séparateur est un `Raccourci` avec `estSeparateur: true`, `nom: ''` et `url: ''`. Il est créé via `Raccourci.separateur(id)`. En JSON, le champ `separateur` est omis quand `false` (rétrocompatibilité). Les séparateurs ne sont jamais ouverts ni modifiés — uniquement déplacés ou supprimés.

---

### `lib/models/catalogue.dart`

Modèles `CatalogueCategorie` et `CatalogueRaccourci` utilisés pour les catalogues embarqués (assets) et les catalogues en ligne (`.catalogue`).

`CatalogueRaccourci` : `id`, `label`, `url` — pas de champ login ou password par construction.

---

### `lib/models/catalogue_en_ligne.dart`

Modèle `CatalogueEnLigneInfo` représentant une entrée de l'index GitHub :

| Champ | Type | Description |
|---|---|---|
| `id` | `String` | Identifiant unique du catalogue |
| `nom` | `String` | Nom affiché |
| `description` | `String` | Description courte |
| `version` | `int` | Numéro de version (incrémenté à chaque mise à jour) |
| `updated` | `String` | Date de dernière mise à jour (format `YYYY-MM-DD`) |
| `nbRaccourcis` | `int` | Nombre total de raccourcis |
| `url` | `String` | URL raw GitHub du fichier `.catalogue` |

---

### `lib/services/storage_service.dart`

Couche d'accès aux données, deux backends :

**`SharedPreferences`** — raccourcis (données non sensibles)
- Clé : `'raccourcis'`, format JSON
- `charger()` → `Future<List<Raccourci>>`
- `sauvegarder(List<Raccourci>)` → `Future<void>`
- `effacerRaccourcis()` → `Future<void>`

**`FlutterSecureStorage`** — mots de passe et données sensibles (chiffrés via Android Keystore)
- Clé : `'pwd_<id>'` pour chaque mot de passe de raccourci
- Clés `'app_pin_hash'`, `'app_pin_salt'`, `'app_pin_backup_codes'` pour le verrouillage PIN
- `chargerMotDePasse(id)` → `Future<String?>`
- `sauvegarderMotDePasse(id, motDePasse)` → `Future<void>`
- `supprimerMotDePasse(id)` → `Future<void>`

Méthodes supplémentaires :
- `effacerTout()` → vide la clé raccourcis et appelle `FlutterSecureStorage.deleteAll()`
- `reinitialiserApp()` → `prefs.clear()` + `FlutterSecureStorage.deleteAll()` — réinitialisation complète (utilisé lors de la procédure de recouvrement PIN)

---

### `lib/services/pin_service.dart`

Gère l'ensemble du système de verrouillage PIN.

**Stockage**

| Clé | Backend | Contenu |
|---|---|---|
| `app_pin_hash` | FlutterSecureStorage | SHA-256(salt \|\| pin) |
| `app_pin_salt` | FlutterSecureStorage | Sel aléatoire 16 octets (base64) |
| `app_pin_backup_codes` | FlutterSecureStorage | JSON array de SHA-256 des codes de secours |
| `pin_failures` | SharedPreferences | Compteur d'échecs consécutifs |
| `pin_cooldown_until` | SharedPreferences | Timestamp ms de fin de cooldown |

**API publique**

- `estConfigure()` → `Future<bool>`
- `configurerPin(pin)` → génère sel aléatoire, hash SHA-256(sel ‖ pin), persiste
- `verifierPin(pin)` → `Future<bool>`
- `genererCodesSecours()` → `Future<List<String>>` — 8 codes `XXXX-XXXX` depuis un alphabet de 32 caractères (sans 0/O/1/I), stocke leurs hashes
- `utiliserCodeSecours(code)` → `Future<bool>` — valide le code, le consomme (usage unique), réinitialise le compteur d'échecs
- `codesSecoursRestants()` → `Future<int>`
- `enregistrerEchec()` → incrémente le compteur et pose un cooldown (30 s dès 3 échecs, 5 min dès 5 échecs)
- `cooldownRestant()` → `Future<Duration>`
- `reinitialiserEchecs()` → `Future<void>`

**Politique d'échecs**

| Échecs | Conséquence |
|---|---|
| 3 | Cooldown 30 secondes |
| 5 | Cooldown 5 minutes + lien "Code oublié ?" affiché |
| 10 (`maxEchecs`) | Saisie bloquée, lien "Code oublié ?" obligatoire |

---

### `lib/services/export_service.dart`

Gère le chiffrement et le déchiffrement des sauvegardes. Les deux méthodes publiques s'exécutent dans un isolate Dart (`Isolate.run`) pour ne pas bloquer l'UI pendant la dérivation de clé.

**Format du fichier exporté** — JSON, extension `.sesame` :
```json
{ "v": 1, "salt": "<base64>", "iv": "<base64>", "data": "<base64>" }
```
Le champ `data` contient le JSON chiffré :
```json
{ "raccourcis": [...], "passwords": { "<id>": "<mdp>", ... } }
```

**Chiffrement** (`chiffrer`) :
1. Salt et IV aléatoires (16 octets chacun, `Random.secure`)
2. Clé AES-256 dérivée via PBKDF2-HMAC-SHA256 (100 000 itérations)
3. Chiffrement AES-256-CBC

**Déchiffrement** (`dechiffrer`) :
Inverse les étapes ci-dessus. Toute erreur (passphrase incorrecte, fichier corrompu) lève une `FormatException`.

---

### `lib/services/catalogue_service.dart`

Charge le catalogue embarqué depuis `assets/default.catalogue` via `rootBundle`.

---

### `lib/services/catalogue_en_ligne_service.dart`

Télécharge et met en cache l'index des catalogues publiés sur GitHub.

**URL de l'index** : `https://raw.githubusercontent.com/jbil-kebir/Sesame/main/catalogues/index.json`

**API publique**

- `chargerIndex()` → tente le réseau (timeout 10 s), met à jour le cache en cas de succès, utilise le cache en cas d'échec. Lève une exception si aucune donnée n'est disponible (premier lancement hors-ligne).
- `telechargerCatalogue(url)` → `Future<List<CatalogueCategorie>>` — télécharge et parse un fichier `.catalogue`.
- `versionLocale(id)` → `Future<int?>` — version du catalogue actuellement importé (`null` si jamais importé).
- `sauvegarderVersion(id, version)` → persiste la version après un import.

**Cache**

| Clé SharedPreferences | Contenu |
|---|---|
| `catalogue_index_cache` | JSON brut du dernier index téléchargé |
| `catalogue_version_<id>` | Version (int) du dernier import de ce catalogue |

---

### `lib/screens/lock_screen.dart`

Écran de verrouillage affiché à chaque démarrage si le PIN est configuré.

**Comportement**

- Au montage : charge le nombre d'échecs et le cooldown éventuel depuis `PinService`. Si la biométrie est disponible et que le nombre d'échecs est inférieur à `maxEchecs`, déclenche automatiquement l'authentification biométrique.
- Clavier numérique personnalisé (pas de clavier système) : saisie de 6 chiffres avec validation automatique dès le 6ème.
- Cooldown : le clavier est grisé pendant la durée restante, affichée avec un compte à rebours mis à jour chaque seconde.
- Biométrie (`local_auth`) : bouton empreinte visible si disponible. `biometricOnly: true` — n'utilise pas le code Android du téléphone, uniquement les capteurs biométriques.
- Le lien "Code oublié ?" apparaît à partir de 5 échecs.

**Feuille de récupération (`_RecuperationSheet`)**

Deux options :
1. **Code de secours** : saisie libre, normalisée avant hash (suppression du tiret, mise en majuscules). En cas de succès → navigue vers `PinSetupScreen` pour définir un nouveau PIN.
2. **Réinitialisation** : section dépliable avec avertissement. Confirmation par dialog → `StorageService.reinitialiserApp()` → retour à l'onboarding.

---

### `lib/screens/pin_setup_screen.dart`

Wizard en 3 étapes pour la configuration initiale du PIN. Non-bypassable (`PopScope(canPop: false)`).

| Étape | Description |
|---|---|
| `saisie` | Saisie du PIN (6 chiffres, clavier personnalisé) |
| `confirmation` | Resaisie du PIN pour vérification |
| `codesSecours` | Affichage des 8 codes de secours, bouton copie, checkbox obligatoire |

À la confirmation du PIN : `PinService.configurerPin()` puis `PinService.genererCodesSecours()`. Le bouton "Accéder à Sésame" est désactivé tant que la checkbox n'est pas cochée.

---

### `lib/screens/catalogue_screen.dart`

Écran de sélection et d'import de raccourcis. Utilisé dans trois contextes :

| Contexte | `premierLancement` | `categories` |
|---|---|---|
| Onboarding | `true` | `null` (catalogue embarqué) |
| Menu "Ajouter depuis le catalogue" | `false` | `null` (catalogue embarqué) |
| Catalogue en ligne | `false` | liste téléchargée |

En mode `premierLancement`, valider navigue vers `/home` (→ `PinSetupScreen`). En mode normal, `Navigator.pop(context, nombreImportés)` retourne le nombre de raccourcis ajoutés à l'appelant.

---

### `lib/screens/catalogues_en_ligne_screen.dart`

Écran listant les catalogues disponibles sur GitHub.

**Comportement**

- Charge l'index via `CatalogueEnLigneService.chargerIndex()` au montage.
- Charge en parallèle les versions locales de chaque catalogue pour afficher les badges.
- Pull-to-refresh disponible.
- En cas d'erreur réseau sans cache : écran d'erreur avec bouton "Réessayer".

**Badges sur les cartes**

| État | Badge |
|---|---|
| Jamais importé | aucun |
| Importé, version identique | "Importé" (vert) |
| Version distante > version locale | "Mise à jour" (orange) |

**Import** : tap sur une carte → dialog de chargement → `telechargerCatalogue()` → `CatalogueScreen` avec les catégories téléchargées → si au moins 1 raccourci ajouté, `sauvegarderVersion()` est appelé.

---

### `lib/screens/home_screen.dart`

Écran principal. Menu ⋮ :

| Item | Action |
|---|---|
| Réorganiser | Mode réorganisation par drag (avec séparateurs) |
| Catalogue par défaut | `CatalogueScreen` avec catalogue embarqué (`assets/default.catalogue`) |
| Importer un catalogue (.catalogue) | Import d'un fichier `.catalogue` local |
| Catalogues en ligne | `CataloguesEnLigneScreen` |
| Exporter | Export chiffré `.sesame` |
| Importer | Import chiffré `.sesame` |
| Tout effacer | Suppression de tous les raccourcis |
| Restaurer la sauvegarde | Restauration backup automatique (si disponible) |

---

### `lib/screens/webview_screen.dart`

Écran de navigation web. Utilise `flutter_inappwebview` (`InAppWebView`).

**Mécanismes JS (inchangés depuis v1.1)**

Les canaux JS utilisent désormais `window.flutter_inappwebview.callHandler('NomCanal', payload)` (API `flutter_inappwebview`) au lieu de `NomCanal.postMessage(payload)` (ancienne API `webview_flutter`). Trois canaux :

| Canal | Déclencheur | Action Flutter |
|---|---|---|
| `CredentialCapture` | Blur sur un champ password | Stocke les identifiants en attente |
| `CredentialSaveNow` | Capture manuelle (bouton clé) | Propose immédiatement la sauvegarde |
| `FormDetected` | MutationObserver détecte un champ password | Affiche le bouton clé dans l'AppBar |

**Authentification HTTP Basic (`.htpasswd`)**

`onReceivedHttpAuthRequest` affiche un `AlertDialog` avec les champs login/mot de passe, pré-remplis avec les identifiants du raccourci si disponibles. `permanentPersistence: true` — le WebView mémorise les credentials pour la durée de la session.

**Téléchargement de fichiers**

`onDownloadStartRequest` intercepte tout contenu que le WebView ne peut pas afficher nativement (PDF, Office…). Flux :
1. Lecture des cookies de session via `CookieManager.instance().getCookies()`
2. Téléchargement HTTP avec les cookies dans l'en-tête `Cookie`
3. Écriture dans le dossier temporaire (`getTemporaryDirectory()`)
4. Ouverture avec `OpenFilex.open()` (application système)

Un overlay "Téléchargement en cours..." bloque l'UI pendant le téléchargement.

**Gestion des drives cloud**

`shouldOverrideUrlLoading` intercepte les URLs de drives via `_urlDrive()` :

| Domaine | Traitement |
|---|---|
| `drive.google.com`, `docs.google.com` | Conversion en URL de téléchargement direct (`/uc?export=download&id=FILE_ID`) puis `_telechargerUrl()` |
| `drive.proton.me`, `onedrive.live.com`, `1drv.ms`, `dropbox.com`, `box.com`, `*.sharepoint.com` | `launchUrl` → navigateur externe |

`_urlDrive()` retourne `null` si l'URL n'est pas un drive connu, une URL non vide pour Google Drive (URL de téléchargement), ou une chaîne vide pour les autres drives (signal "ouvrir externalement").

---

## Formats de fichiers

### `.sesame` — sauvegarde personnelle chiffrée

```json
{ "v": 1, "salt": "<base64>", "iv": "<base64>", "data": "<base64>" }
```

`data` déchiffré :
```json
{ "raccourcis": [...], "passwords": { "<id>": "<mdp>", ... } }
```

Usage : sauvegarde personnelle, migration entre appareils. Contient raccourcis et mots de passe chiffrés (AES-256-CBC, clé PBKDF2).

### `.catalogue` — catalogue de raccourcis

```json
{
  "categories": [
    { "id": "...", "label": "...", "shortcuts": [
      { "id": "...", "label": "...", "url": "..." }
    ]}
  ]
}
```

Utilisé pour :
- Le catalogue embarqué (`assets/default.catalogue`) — chargé au premier lancement
- Les catalogues en ligne distribués via GitHub (`catalogues/*.catalogue`)
- L'import manuel de catalogues locaux

Par construction, ne contient jamais de credentials (le modèle `CatalogueRaccourci` ne comporte que `id`, `label`, `url`).

> **Note** : bien que `.sesame` et `.catalogue` partagent l'extension `.sesame` / `.catalogue`, ils sont structurellement distincts — l'un est chiffré, l'autre est du JSON brut.

---

## Dépôt GitHub des catalogues

**Dépôt** : `https://github.com/jbil-kebir/Sesame`

```
catalogues/
├── index.json
├── kleber_college.catalogue
└── kleber_lycee.catalogue
```

**Format `index.json`** :
```json
[
  {
    "id": "kleber_college",
    "nom": "Collège Kléber — Strasbourg",
    "description": "...",
    "version": 1,
    "updated": "2026-04-17",
    "nb_raccourcis": 11,
    "url": "https://raw.githubusercontent.com/jbil-kebir/Sesame/main/catalogues/kleber_college.catalogue"
  }
]
```

Pour publier une mise à jour d'un catalogue : incrémenter `version` dans `index.json` et mettre à jour le fichier `.catalogue` correspondant dans le même commit.

---

## Flux de données

```
SharedPreferences                FlutterSecureStorage
      ↓ charger()                      ↓ chargerMotDePasse()
      └──────────────┬─────────────────┘
               StorageService
                    ↓ List<Raccourci> + motDePasse
               HomeScreen (state)
                    ↓ tap
               WebViewScreen
               ↙                         ↘
  _injecterIdentifiants             _injecterCapture
  (JS → auto-login)                 (JS → écoute blur / submit)
                                          ↓ CredentialCapture
                                    _proposerSauvegarde → dialog
                                          ↓
                              StorageService.sauvegarderMotDePasse()

GitHub (raw)
  ↓ chargerIndex() / telechargerCatalogue()
CatalogueEnLigneService
  ↓ cache SharedPreferences
CataloguesEnLigneScreen
  ↓ CatalogueCategorie[]
CatalogueScreen (sélection + import)
  ↓ sauvegarderVersion()
CatalogueEnLigneService
```

---

## Flux de démarrage

```
AppRouter
  ├── onboarding_done == false
  │     └── CatalogueScreen (premierLancement: true)
  │           └── [valider] → /home → PinSetupScreen → HomeScreen
  │
  ├── onboarding_done == true, PIN non configuré
  │     └── PinSetupScreen → HomeScreen
  │
  └── onboarding_done == true, PIN configuré
        └── LockScreen
              ├── biométrie / PIN correct → HomeScreen
              ├── code de secours → PinSetupScreen → HomeScreen
              └── réinitialisation → reinitialiserApp() → AppRouter
```

---

## Comportement des cookies et sessions

`flutter_inappwebview` utilise la **WebView système Android**. Les cookies sont persistés nativement par l'OS dans le répertoire de données de l'application. Un utilisateur connecté à un site reste connecté lors des prochaines ouvertures.

Les cookies sont également accessibles depuis Dart via `CookieManager.instance().getCookies(url: WebUri(url))`, ce qui permet de les transmettre lors des téléchargements HTTP authentifiés (PDFs ENT, intranet…).

---

## Versionnement

La version est définie dans `pubspec.yaml` au format `n.m.0+build` :
- `n` : incrémenté pour les modifications importantes
- `m` : incrémenté pour les modifications mineures
- `.0` : patch figé à 0 (contrainte Flutter, non affiché)

L'historique des changements est maintenu dans `CHANGELOG.md`.

---

## Scripts de build et publication

### `build.bat` — compilation

1. Copie `doc/default.catalogue` → `assets/default.catalogue`
2. Build APK release via Flutter
3. Copie l'APK dans `U:\Info-Developpement\GitHub\Sesame\apk\sesame.apk`

```
build
```

### `publish.bat` — publication GitHub

1. Vérifie qu'un APK est présent
2. Synchronise `lib/`, `assets/`, `doc/` → `sources/` et `docs/` du dépôt GitHub via `sync_github.py`
3. `git add -A` + `git commit` + `git push`

```
publish
```

> L'enchaînement `build` puis `publish` est le workflow standard. `build_release.bat` est conservé pour compatibilité.

### `sync_github.py` — synchronisation des sources

Copie les dossiers `lib/`, `assets/`, `doc/` vers `U:\Info-Developpement\GitHub\Sesame\sources\` et les fichiers HTML (`doc/*.html`) vers `U:\Info-Developpement\GitHub\Sesame\docs\`.

> **Important** : toujours modifier les sources dans le projet local (`D:\Developpement\FlutterProjects\Sesame\`). Le dépôt GitHub est un miroir — ne jamais éditer directement les fichiers sous `sources/`.

---

## Outils de maintenance

Situés dans `U:\Info-Developpement\GitHub\Sesame\outils\` (voir `outils/README.md`).

### `check_catalogues.py`

Vérifie l'accessibilité de tous les liens des catalogues hébergés sur GitHub. Détecte les erreurs DNS, timeouts, HTTP 4xx/5xx et les redirections d'un sous-domaine vers le domaine racine du même site.

```bash
python check_catalogues.py [--token GITHUB_TOKEN]
```

### `lancer_verification.py`

Lance `check_catalogues.py` puis envoie le rapport par mail via le MCP Thunderbird (`thunderbird-mail`). Démarre Thunderbird automatiquement si nécessaire.

Planifié chaque mercredi à 19h via le Planificateur de tâches Windows (`StartWhenAvailable`).

---

## Icône application

Le fichier source est `doc/icon.svg` (1024 × 1024) : clé blanche avec lueur et ombre portée, sur fond dégradé bleu (`#42A5F5` → `#1565C0`), coins arrondis (`rx="220"`). La clé est centrée verticalement (anneau à y=362, bas de tige à y=852, centre à y=512).

Pour régénérer les icônes Android après modification du SVG :

```bash
npx svgexport doc/icon.svg doc/icon.png 1024:1024
dart run flutter_launcher_icons
```

---

## Commandes utiles

```bash
# Lancer en mode debug sur Android
flutter run

# Build APK release (préférer build.bat)
flutter build apk --release

# Installer directement sur l'appareil connecté
flutter install --release

# Mettre à jour les dépendances
flutter pub upgrade

# Vérifier les dépendances obsolètes
flutter pub outdated
```

---

## Pistes d'évolution

- Groupes / catégories de raccourcis dans l'écran principal
- Bouton de partage d'URL depuis la WebView
- Titre dynamique de la WebView (titre de la page en cours)
- Synchronisation automatique des catalogues en arrière-plan
