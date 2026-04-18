# Sésame

Application Android Flutter permettant d'enregistrer des raccourcis vers vos sites web favoris et de les ouvrir en un seul appui, avec connexion automatique optionnelle.

---

## Fonctionnalités

- **Raccourcis web** — ajoutez, modifiez, supprimez et réorganisez vos sites favoris
- **Navigateur intégré** (WebView) — les sites s'ouvrent directement dans l'application
- **Connexion automatique** — enregistrez identifiant et mot de passe pour une connexion transparente, même sur les portails à plusieurs étapes (ex. ENT avec page de sélection de profil)
- **Capture d'identifiants** — détecte la soumission d'un formulaire de connexion et propose de sauvegarder les identifiants
- **Mémorisation de session** — reste connecté entre les visites
- **Vue grille / liste** — basculez l'affichage d'un appui
- **Réorganisation par glisser-déposer** — triez vos raccourcis à la main
- **Export / Import chiffré** — sauvegardez vos raccourcis dans un fichier `.lncr` chiffré (AES-256, PBKDF2) et restaurez-les sur un autre appareil
- **Catalogues en ligne** — importez des raccourcis prêts à l'emploi depuis un catalogue hébergé sur GitHub

---

## Captures d'écran

*(à venir)*

---

## Installation

### Prérequis

- [Flutter SDK](https://flutter.dev/docs/get-started/install) ≥ 3.11
- Android SDK / Android Studio
- Un appareil Android ou émulateur

### Lancer en développement

```bash
cd sources
flutter pub get
flutter run
```

### Compiler l'APK

```bash
flutter build apk --release
```

### APK prête à l'emploi

Un fichier `apk/sesame.apk` est disponible à la racine du dépôt pour une installation directe sur Android.

---

## Structure du dépôt

```
Sesame/
├── apk/
│   └── sesame.apk                 # APK release prête à l'emploi
├── catalogues/                    # Catalogues de raccourcis hébergés
│   ├── index.json                 # Index des catalogues disponibles
│   ├── kleber_college.catalogue   # Catalogue Collège Kléber
│   └── kleber_lycee.catalogue     # Catalogue Lycée Kléber
├── docs/                          # Documentation et ressources web
│   ├── confidentialite.html       # Politique de confidentialité
│   ├── installer.html             # Guide d'installation
│   ├── doc_developpeur.md         # Notes de développement
│   ├── doc_utilisateur.md         # Guide utilisateur
│   ├── icon.svg                   # Icône source (SVG)
│   └── icon.png                   # Icône exportée (PNG 1024×1024)
├── outils/                        # Scripts de maintenance
│   ├── check_catalogues.py        # Vérification des liens des catalogues
│   ├── lancer_verification.py     # Lancement automatique + envoi mail
│   └── rapports/                  # Rapports générés (ignorés par git)
├── sources/                       # Sources Flutter
│   ├── lib/
│   │   ├── main.dart              # Point d'entrée de l'application
│   │   ├── models/
│   │   │   └── raccourci.dart     # Modèle de données d'un raccourci
│   │   ├── screens/
│   │   │   ├── home_screen.dart   # Écran principal (grille / liste de raccourcis)
│   │   │   └── webview_screen.dart# Navigateur intégré avec injection de credentials
│   │   └── services/
│   │       ├── storage_service.dart   # Persistance locale (shared_preferences + secure storage)
│   │       └── export_service.dart    # Export / import chiffré (.lncr)
│   ├── android/                   # Configuration Android native
│   ├── pubspec.yaml               # Dépendances Flutter
│   └── CHANGELOG.md              # Historique des versions
├── LICENSE
└── README.md
```

---

## Formats de fichiers

| Extension | Usage |
|-----------|-------|
| `.lncr` | Sauvegarde chiffrée des raccourcis et identifiants utilisateur (AES-256, PBKDF2) |
| `.catalogue` | Catalogue de raccourcis prêts à l'emploi (JSON, importable dans l'application) |

---

## Dépendances principales

| Package | Rôle |
|---------|------|
| `webview_flutter` | Navigateur intégré |
| `flutter_secure_storage` | Stockage chiffré des mots de passe |
| `shared_preferences` | Persistance des raccourcis et préférences |
| `encrypt` + `crypto` | Chiffrement AES-256 / PBKDF2 pour l'export |
| `file_picker` | Sélection du fichier à l'import |
| `share_plus` | Partage du fichier exporté |
| `package_info_plus` | Lecture du numéro de version |
| `url_launcher` | Ouverture externe dans le navigateur système |

---

## Sécurité

- Les mots de passe sont stockés via `flutter_secure_storage` (Keystore Android)
- Les fichiers d'export `.lncr` sont chiffrés en AES-256 avec une clé dérivée via PBKDF2
- Sans la passphrase, le contenu du fichier exporté est illisible

---

## Changelog

Voir [CHANGELOG.md](sources/CHANGELOG.md).

---

## Licence

[MIT](LICENSE) — © 2026 jbil-kebir
