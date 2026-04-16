## 1.3
- WebView : injection des identifiants étendue à toutes les pages jusqu'au premier succès (fonctionne désormais avec les portails à page de sélection de profil, ex. ENT)
- WebView : injection limitée aux champs visibles — les champs masqués (tokens CSRF, inputs hidden) sont ignorés pour éviter les faux positifs sur les pages post-connexion
- WebView : bouton clé fonctionnel même après soumission du formulaire (utilise les identifiants capturés en attente)
- WebView : bouton clé affiché tant que des identifiants capturés non encore confirmés sont en attente
- Icône application : éclair blanc sur fond dégradé bleu

## 1.2
- Export chiffré des raccourcis et identifiants (AES-256, PBKDF2, fichier .lncr)
- Import avec choix : remplacer les données existantes ou fusionner (noms en doublon numérotés)
- Nom du fichier d'export modifiable avant partage
- Icônes des raccourcis dans un conteneur arrondi avec fond teinté
- Initiale colorée en fallback quand le favicon est indisponible (couleur dérivée du nom)
- Source des favicons passée à DuckDuckGo (meilleure résolution)
- Vue liste : affichage du domaine à la place de l'URL complète
- Cartes grille plus compactes et mieux proportionnées
- WebView : user-agent Chrome standard (suppression du marqueur WebView Android)
- WebView : gestion des redirections intent:// / market:// (ouverture externe)
- WebView : injection des identifiants limitée au premier chargement
- WebView : bouton "Ouvrir dans le navigateur" dans la barre de navigation
- WebView : page d'erreur avec bouton Réessayer en cas d'échec de chargement
- Réorganisation des raccourcis par glisser-déposer (menu ⋮ → Réorganiser)

## 1.1
- Capture automatique des identifiants saisis manuellement dans la WebView
- Dialog "Sauvegarder les identifiants ?" proposée après soumission d'un formulaire de connexion
- Auto-soumission du formulaire après injection des identifiants enregistrés
- Support des SPA (React, Vue…) via MutationObserver pour les formulaires chargés dynamiquement
- Bouton "À propos" dans la barre de titre avec numéro de version

## 1.0
- Version initiale
- Raccourcis web lancés dans une WebView intégrée
- Stockage sécurisé des mots de passe (flutter_secure_storage)
- Injection automatique des identifiants configurés au chargement de la page
- Vue grille et vue liste commutables
- Favicon des sites affiché dans les tuiles
- Icône cadenas sur les raccourcis associés à des identifiants
- Formulaire d'ajout / modification / suppression de raccourcis
