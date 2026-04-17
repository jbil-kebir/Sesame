# Documentation développeur — Sésame

## Vue d'ensemble

**Sésame** est une application Android développée avec Flutter. Elle permet de créer des raccourcis vers des pages web favorites et de les ouvrir dans une WebView intégrée, avec gestion automatique des identifiants de connexion.

---

## Stack technique

| Élément | Valeur |
|---|---|
| Framework | Flutter |
| Langage | Dart |
| SDK Dart minimum | ^3.11.0 |
| Cible principale | Android |
| Version application | 1.4 |

### Dépendances

| Package | Version | Rôle |
|---|---|---|
| `webview_flutter` | ^4.10.0 | Affichage de pages web en WebView système |
| `shared_preferences` | ^2.3.0 | Persistance locale des raccourcis (JSON) |
| `flutter_secure_storage` | ^9.0.0 | Stockage chiffré des mots de passe (AES / Keystore Android) |
| `package_info_plus` | ^8.0.0 | Lecture de la version applicative depuis pubspec.yaml |
| `encrypt` | ^5.0.0 | Chiffrement AES-256-CBC |
| `crypto` | ^3.0.0 | Dérivation de clé PBKDF2-HMAC-SHA256 |
| `share_plus` | ^10.0.0 | Partage du fichier d'export via la feuille Android |
| `path_provider` | ^2.0.0 | Dossier temporaire pour l'écriture du fichier d'export |
| `file_picker` | ^8.0.0 | Sélection du fichier à l'import |
| `url_launcher` | ^6.0.0 | Ouverture des liens intent:// et navigation externe dans le navigateur système |

### Dépendances de développement

| Package | Version | Rôle |
|---|---|---|
| `flutter_launcher_icons` | ^0.14.0 | Génération automatique des icônes Android dans toutes les résolutions |

---

## Architecture

```
lib/
├── main.dart                      # Point d'entrée
├── models/
│   └── raccourci.dart             # Modèle de données
├── services/
│   ├── storage_service.dart       # Couche persistance
│   └── export_service.dart        # Chiffrement / déchiffrement export
└── screens/
    ├── home_screen.dart           # Écran principal
    └── webview_screen.dart        # Écran de navigation web
```

L'architecture suit un pattern simple à trois couches :

- **Modèle** : `Raccourci` — données brutes
- **Service** : `StorageService` — lecture/écriture persistante
- **Écrans** : `HomeScreen` et `WebViewScreen` — interface utilisateur

---

## Description des fichiers

### `lib/main.dart`

Point d'entrée de l'application. Instancie un `MaterialApp` avec :
- Thème Material 3, couleur principale bleue
- Bannière debug désactivée
- Écran d'accueil : `HomeScreen`

### `lib/models/raccourci.dart`

Modèle `Raccourci` avec les champs suivants :

| Champ | Type | Description |
|---|---|---|
| `id` | `String` | Identifiant unique (timestamp en ms) |
| `nom` | `String` | Nom affiché sur la carte |
| `url` | `String` | URL complète de la page web |
| `login` | `String?` | Identifiant de connexion (optionnel) |

Le mot de passe n'est **pas** stocké dans le modèle : il est géré séparément par `StorageService` via `flutter_secure_storage`, indexé par l'`id` du raccourci.

Expose `fromJson()` et `toJson()` pour la sérialisation. `login` est omis du JSON si `null`.

### `lib/services/storage_service.dart`

Couche d'accès aux données, deux backends :

Méthode supplémentaire :
- `effacerTout()` → `Future<void>` : vide la clé SharedPreferences et appelle `FlutterSecureStorage.deleteAll()`

**`SharedPreferences`** — raccourcis (données non sensibles)
- Clé : `'raccourcis'`, format JSON
- `charger()` → `Future<List<Raccourci>>`
- `sauvegarder(List<Raccourci>)` → `Future<void>`

**`FlutterSecureStorage`** — mots de passe (chiffrés)
- Clé : `'pwd_<id>'` pour chaque raccourci
- `chargerMotDePasse(id)` → `Future<String?>`
- `sauvegarderMotDePasse(id, motDePasse)` → `Future<void>`
- `supprimerMotDePasse(id)` → `Future<void>`

### `lib/services/export_service.dart`

Gère le chiffrement et le déchiffrement des sauvegardes. Les deux méthodes publiques s'exécutent dans un isolate Dart (`Isolate.run`) pour ne pas bloquer l'UI pendant la dérivation de clé.

**Format du fichier exporté** — JSON, extension `.lncr` :
```json
{ "v": 1, "salt": "<base64>", "iv": "<base64>", "data": "<base64>" }
```
Le champ `data` contient le JSON chiffré :
```json
{ "raccourcis": [...], "passwords": { "<id>": "<mdp>", ... } }
```

**Chiffrement** (`chiffrer`) :
1. Salt et IV aléatoires (16 octets chacun, `Random.secure`)
2. Clé AES-256 dérivée via PBKDF2-HMAC-SHA256 (100 000 itérations, implémentation manuelle avec `package:crypto`)
3. Chiffrement AES-256-CBC (`package:encrypt`)

**Déchiffrement** (`dechiffrer`) :
Inverse les étapes ci-dessus. Toute erreur (passphrase incorrecte, fichier corrompu) lève une `FormatException`.

### `lib/screens/home_screen.dart`

Écran principal de l'application. Gère :

- **Chargement** des raccourcis au démarrage (`initState`)
- **Affichage** en grille (3 colonnes) ou en liste, basculable via l'AppBar
- **Favicon** récupéré via l'API DuckDuckGo : `https://icons.duckduckgo.com/ip3/<host>.ico`
- **Icône cadenas** sur les tuiles dont le raccourci a un `login` associé
- **CRUD** raccourcis :
  - Appui simple → charge le mot de passe sécurisé puis ouvre `WebViewScreen`
  - Appui long → feuille modale (`showModalBottomSheet`) avec options **Modifier** et **Supprimer**
  - Bouton `+` (FAB) → formulaire d'ajout/modification
- **Formulaire d'ajout/modification** (`_ouvrirFormulaire`) — `AlertDialog` avec :
  - Champs obligatoires : **Nom** et **URL**
  - Champs optionnels : **Identifiant** et **Mot de passe** (masqué par défaut, avec bouton toggle visibilité)
  - Si identifiant + mot de passe renseignés → `sauvegarderMotDePasse` ; sinon → `supprimerMotDePasse`
- **Menu ⋮** (`PopupMenuButton`) dans l'AppBar :
  - **Exporter** → demande une passphrase → collecte tous les mots de passe → appelle `ExportService.chiffrer` → écrit un fichier `.lncr` dans le dossier temporaire → partage via `Share.shareXFiles`
  - **Réorganiser** → active `_modeReorganisation` : AppBar gris-bleu avec bouton "Terminer", FAB masqué, corps remplacé par `ReorderableListView` avec poignées ≡. À chaque déplacement, la liste est mise à jour et persistée via `_sauvegarder()`.
  - **Importer** → sélection de fichier (`FilePicker`) → demande une passphrase → appelle `ExportService.dechiffrer` → dialog de choix :
    - **Remplacer** : `effacerTout()` puis sauvegarde des données importées
    - **Ajouter** : fusion avec les données existantes — nouveaux IDs générés, noms en doublon suffixés `(2)`, `(3)`…
- **Bouton "À propos"** (icône `info_outline`) → `showAboutDialog` Flutter natif avec nom, version (`v n.m`) et mention légale
- **Callback `onCredentialsSaved`** passé à `WebViewScreen` : met à jour le `login` du raccourci en mémoire et persiste la liste

### `lib/screens/webview_screen.dart`

Écran de navigation web. Paramètres :

| Paramètre | Type | Description |
|---|---|---|
| `raccourciId` | `String` | ID du raccourci, utilisé pour le stockage du mot de passe |
| `nom` | `String` | Titre affiché dans l'AppBar |
| `url` | `String` | URL chargée au démarrage |
| `login` | `String?` | Identifiant enregistré (injection automatique) |
| `motDePasse` | `String?` | Mot de passe enregistré (injection automatique) |
| `onCredentialsSaved` | `Function(String, String)?` | Callback appelé quand l'utilisateur accepte de sauvegarder |

**Gestion des erreurs SSL** :
Le `NavigationDelegate` inclut `onSslAuthError: (error) => error.proceed()` pour accepter les certificats non reconnus par Android (ex. autorité non incluse dans le trust store Android). Cela permet d'afficher les sites dont la chaîne de certificats est invalide aux yeux du WebView système.

**Injection automatique** (`_injecterIdentifiants`) :
Déclenchée à chaque `onPageFinished`. Si `login` et `motDePasse` sont fournis, un script JS cherche le champ `input[type=password]` et le champ login précédent. S'ils sont présents, il injecte les valeurs via les setters natifs (`HTMLInputElement.prototype.value`) avec dispatch des événements `input` et `change` (compatibilité React/Vue), puis soumet le formulaire après 600 ms selon la priorité suivante :
1. Bouton `[type=submit]` dans le `closest('form')` du champ mot de passe
2. Bouton `[type=submit]` ou `input[type=submit]` n'importe où dans le document
3. Événement `submit` dispatché sur le `<form>`

Seuls les champs **visibles** sont pris en compte (`offsetParent !== null`), ce qui évite de remplir des champs cachés (tokens CSRF, inputs `type=hidden`…) présents sur les pages post-connexion. Dès qu'une injection réussit (champ mot de passe visible trouvé et rempli), `_injectionEffectuee` passe à `true` et les appels suivants deviennent des no-ops : l'injection ne se produit donc que sur la première page qui présente réellement un formulaire de connexion visible.

**Capture des identifiants** (`_injecterCapture`) :
Déclenchée à chaque `onPageFinished`. Injecte un script JS qui :
1. Attache un listener `blur` sur chaque `input[type=password]` trouvé
2. Attache un listener `submit` (phase capture) sur tous les `<form>` présents
3. Surveille les formulaires ajoutés dynamiquement via `MutationObserver` (SPA)
4. À la perte de focus ou à la soumission, extrait login + mot de passe et les envoie via le channel `CredentialCapture` → stockés dans `_identifiantsEnAttente`
5. Expose `window.__captureManuelle()` pour une lecture immédiate des champs via le channel `CredentialSaveNow`
6. Envoie `FormDetected` si au moins un champ mot de passe est présent (affiche le bouton clé dans l'AppBar)

**Sauvegarde** :
Deux canaux déclenchent la proposition de sauvegarde :
- `CredentialCapture` → `_stockerIdentifiantsEnAttente()` : stocke les identifiants sans dialog. À la prochaine navigation (`onPageFinished`), si `_identifiantsEnAttente` est non nul, `_proposerSauvegarde()` est appelé (connexion confirmée).
- `CredentialSaveNow` → `_proposerSauvegardeDepuisMessage()` → `_proposerSauvegarde()` : dialog immédiate (capture manuelle via bouton clé).

`_proposerSauvegarde()` ne propose la sauvegarde que si les identifiants diffèrent de ceux déjà enregistrés. En cas d'acceptation, persiste le mot de passe via `StorageService` et appelle `onCredentialsSaved`.

**Bouton clé** (`_captureManuelle`) :
Visible dans l'AppBar quand `_formulaireConnexionDetecte` est vrai (formulaire encore présent) **ou** quand `_identifiantsEnAttente` est non nul (formulaire soumis, sauvegarde en attente). Tente d'abord une capture JS directe ; si les champs sont vides (formulaire déjà soumis), utilise les identifiants en attente.

---

## Flux de données

```
SharedPreferences        FlutterSecureStorage
      ↓ charger()               ↓ chargerMotDePasse()
      └──────────┬──────────────┘
            StorageService
                 ↓ List<Raccourci> + motDePasse
            HomeScreen (state)
                 ↓ tap
            WebViewScreen
            ↙                      ↘
  _injecterIdentifiants          _injecterCapture
  (JS → auto-login               (JS → écoute blur / submit)
   sur chaque page avec               ↓ CredentialCapture channel
   champ password)              _stockerIdentifiantsEnAttente
                                      ↓ prochaine page
                                 _proposerSauvegarde
                                      ↓ dialog
                           StorageService.sauvegarderMotDePasse()
                           onCredentialsSaved() → HomeScreen

  Bouton clé AppBar → _captureManuelle
      ↓ CredentialSaveNow channel  ou  _identifiantsEnAttente
      → _proposerSauvegarde → dialog
```

---

## Comportement des cookies et sessions

La `webview_flutter` utilise la **WebView système Android**. Les cookies sont persistés nativement par l'OS dans le répertoire de données de l'application. Un utilisateur connecté à un site reste connecté lors des prochaines ouvertures — dans ce cas, `onPageFinished` s'exécute sur la page post-connexion (dashboard), aucun champ mot de passe n'est trouvé, et les scripts n'ont aucun effet.

---

## Versionnement

La version est définie dans `pubspec.yaml` au format `n.m.0+build` :
- `n` : incrémenté pour les modifications importantes
- `m` : incrémenté pour les modifications mineures
- `.0` : patch figé à 0 (contrainte Flutter, non affiché)

L'affichage dans l'UI supprime le `.0` final via `version.replaceAll(RegExp(r'\.0$'), '')`.

L'historique des changements est maintenu dans `CHANGELOG.md` à la racine du projet.

---

## Pistes d'évolution

- Groupes / catégories de raccourcis
- Bouton de partage d'URL depuis la WebView
- Titre dynamique de la WebView (titre de la page en cours)

---

## Icône application

Le fichier source est `doc/icon.svg` (1024 × 1024) : éclair blanc avec lueur sur fond dégradé bleu (`#42A5F5` → `#1565C0`), coins arrondis (`rx="220"`).

Le PNG de référence `doc/icon.png` est exporté depuis le SVG (via `svgexport`). C'est ce fichier qui est utilisé par `flutter_launcher_icons`.

La configuration est déclarée dans `pubspec.yaml` :

```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "doc/icon.png"
```

Pour régénérer les icônes Android après modification du SVG :

```bash
# 1. Exporter le SVG en PNG
npx svgexport doc/icon.svg doc/icon.png 1024:1024

# 2. Regénérer toutes les résolutions Android
dart run flutter_launcher_icons
```

Les fichiers générés se trouvent dans `android/app/src/main/res/mipmap-*/`.

---

## Script de build — `build_release.bat`

Le script `build_release.bat` à la racine du projet automatise l'ensemble du cycle de release :

1. Copie `doc/catalogue.json` → `assets/catalogue.json` (catalogue embarqué)
2. Build APK release via Flutter
3. Copie l'APK dans `U:\Info-Developpement\GitHub\Sesame\apk\sesame.apk`
4. Synchronise `lib/`, `assets/`, `doc/` (y compris les `.sesame`) vers `sources/` du dépôt GitHub local via `sync_github.py`
5. `git add -A` + `git commit` + `git push`

**Lancement** depuis PowerShell ou tout terminal VS Code :
```
./build_release
```

**Note importante — `call flutter`**  
`flutter` est lui-même un fichier `.bat`. Dans un script `.bat`, appeler un autre `.bat` sans le mot-clé `call` transfère l'exécution définitivement : le script appelant ne reprend jamais la main. Le script utilise donc `call flutter build apk --release` pour que les étapes 3 à 5 s'exécutent bien après le build.

**Catalogue embarqué**  
Éditer `doc/catalogue.json` pour modifier le catalogue par défaut. Le build le copie automatiquement dans `assets/` avant de compiler.

**Fichiers `.sesame`**  
Les fichiers catalogue à distribuer (ex. `kleber_college.sesame`) se placent dans `doc/` et sont versionnés sur GitHub à chaque build.

---

## Commandes utiles

```bash
# Lancer en mode debug sur Android
flutter run

# Build APK release (préférer build_release.bat)
flutter build apk --release

# Mettre à jour les dépendances
flutter pub upgrade

# Vérifier les dépendances obsolètes
flutter pub outdated
```
