# Guide utilisateur — Lanceur

## À quoi sert Lanceur ?

Lanceur est votre page d'accueil personnelle sur Android. Il vous permet d'enregistrer les sites web que vous consultez le plus souvent et de les ouvrir en un seul appui, directement dans l'application.

---

## Écran principal

Au lancement, vous voyez vos raccourcis affichés sous forme de **grille** ou de **liste**.

- Chaque raccourci affiche le **logo du site** (favicon) et son **nom**.
- L'icône en haut à droite permet de **basculer entre la vue grille et la vue liste**.

---

## Ouvrir un site

Appuyez simplement sur un raccourci pour ouvrir le site dans le navigateur intégré.

---

## Ajouter un raccourci

1. Appuyez sur le bouton **+** (en bas à droite de l'écran).
2. Saisissez un **nom** (ex. : "Ma banque") et l'**adresse du site** (ex. : `https://monsite.fr`).
3. Si vous le souhaitez, renseignez votre **identifiant** et **mot de passe** dans les champs optionnels. L'application se connectera alors automatiquement à chaque visite.
4. Appuyez sur **Valider**.

Le raccourci apparaît immédiatement dans votre liste.

---

## Modifier ou supprimer un raccourci

**Appuyez longuement** sur un raccourci pour afficher le menu d'options :

- **Modifier** — changez le nom ou l'URL.
- **Supprimer** — supprime définitivement le raccourci.

---

## Navigation dans le navigateur intégré

Lorsqu'un site est ouvert, une barre de navigation apparaît en haut :

| Bouton | Action |
|---|---|
| **X** (croix) | Ferme le site et revient à l'accueil |
| **Flèche gauche** | Revient à la page précédente (apparaît seulement si possible) |
| **Icône refresh** | Recharge la page en cours |

---

## Connexion aux sites

### Connexion automatique

Si vous avez enregistré un identifiant et un mot de passe (via le formulaire d'ajout ou lors d'une visite précédente), l'application les **renseigne et soumet le formulaire automatiquement** à chaque ouverture du site.

Cela fonctionne même si le site affiche une **page intermédiaire** avant la page de connexion (sélection du profil, portail d'établissement…) : l'application attend la page qui contient réellement les champs de saisie.

### Mémorisation de session

L'application **mémorise votre session** : une fois connecté, vous restez connecté lors des prochaines visites, sans avoir à retaper vos identifiants.

### Sauvegarder des identifiants lors d'une connexion manuelle

Si vous saisissez vos identifiants directement sur le site, l'application détecte la soumission du formulaire et vous propose de les **sauvegarder** sur la page suivante (connexion confirmée). Appuyez sur **Sauvegarder** pour que la connexion soit automatique lors des prochaines visites, ou **Non** pour ignorer.

Vous pouvez aussi appuyer sur l'**icône clé** qui apparaît dans la barre du haut dès qu'un formulaire de connexion est détecté. Elle reste disponible après la soumission du formulaire tant que la sauvegarde n'a pas encore été confirmée.

> Ces identifiants sont stockés de manière chiffrée sur votre appareil.

---

## Réorganiser les raccourcis

1. Appuyez sur le menu **⋮** en haut à droite, puis **Réorganiser**.
2. L'écran passe en mode réorganisation : les raccourcis s'affichent en liste avec une poignée ≡ à droite.
3. **Maintenez appuyé** sur un raccourci et **glissez-le** à la position souhaitée.
4. Appuyez sur **Terminer** pour valider et revenir à l'écran normal.

---

## Exporter et importer ses raccourcis

### Exporter

1. Appuyez sur le menu **⋮** en haut à droite, puis **Exporter**.
2. Saisissez une **passphrase** (mot de passe de chiffrement) et confirmez.
3. Partagez le fichier `.lncr` généré via l'application de votre choix (Drive, mail, WhatsApp…).

> Le fichier est chiffré : sans la passphrase, son contenu est illisible.

### Importer

1. Appuyez sur le menu **⋮**, puis **Importer**.
2. Sélectionnez le fichier `.lncr` dans le gestionnaire de fichiers.
3. Saisissez la passphrase utilisée lors de l'export.
4. Choisissez comment importer :
   - **Remplacer** — efface tous les raccourcis existants et les remplace par ceux du fichier.
   - **Ajouter** — fusionne avec les raccourcis existants. Si un nom est identique, un numéro est ajouté automatiquement (ex. : "Ma banque (2)").

## Questions fréquentes

**Le logo du site ne s'affiche pas.**
Si l'icône du site n'est pas disponible, une icône générique est affichée à la place. Cela n'affecte pas le fonctionnement du raccourci.

**J'ai supprimé un raccourci par erreur.**
La suppression est définitive. Vous devrez recréer le raccourci via le bouton **+**.

**Le site ne se charge pas.**
Vérifiez votre connexion internet. Vous pouvez aussi appuyer sur l'icône **refresh** pour réessayer.
