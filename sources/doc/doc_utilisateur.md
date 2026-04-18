# Guide utilisateur — Sésame

## À quoi sert Sésame ?

Sésame est votre page d'accueil personnelle sur Android. Il vous permet d'enregistrer les sites web que vous consultez le plus souvent et de les ouvrir en un seul appui, directement dans l'application, avec connexion automatique.

---

## Accès sécurisé

### Code d'accès

Au premier lancement, Sésame vous demande de créer un **code d'accès à 6 chiffres**. Ce code est obligatoire : il protège l'accès à vos raccourcis et identifiants enregistrés.

À chaque démarrage de l'application, ce code vous est demandé avant d'accéder à l'écran principal.

### Déverrouillage par biométrie

Si votre appareil dispose d'un capteur d'empreinte digitale, Sésame propose automatiquement de déverrouiller l'application par empreinte. Le code d'accès reste toujours disponible en alternative.

### Codes de secours

Lors de la création de votre code d'accès, Sésame génère **8 codes de secours** à usage unique. **Sauvegardez-les impérativement** : sur papier, dans un gestionnaire de mots de passe, ou par tout autre moyen sûr.

Chaque code de secours permet de réinitialiser votre code d'accès une seule fois.

### Code oublié

Si vous avez oublié votre code d'accès :

1. Après 5 tentatives échouées, le lien **"Code oublié ?"** apparaît sous le clavier.
2. Appuyez dessus pour ouvrir la feuille de récupération.
3. **Option A — code de secours** : saisissez l'un de vos codes de secours. Sésame vous permet alors de définir un nouveau code d'accès et génère de nouveaux codes de secours.
4. **Option B — réinitialisation** : si vous n'avez plus de codes de secours, vous pouvez effacer complètement l'application. **Toutes les données sont perdues définitivement.** Un fichier de sauvegarde `.lncr` vous permettra de les restaurer si vous en avez un.

> **Nota** : Sésame ne connaît pas votre code. Personne ne peut le récupérer à votre place.

---

## Écran principal

Au déverrouillage, vous voyez vos raccourcis affichés sous forme de **grille** ou de **liste**.

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
| **Icône navigateur** | Ouvre la page courante dans le navigateur Android |

### Sites protégés par mot de passe (authentification HTTP)

Certains sites ou pages sont protégés par un accès restreint au niveau du serveur (`.htpasswd`). Sésame affiche automatiquement une boîte de dialogue vous demandant un identifiant et un mot de passe, exactement comme le ferait un navigateur standard.

Si des identifiants sont déjà enregistrés pour ce raccourci, les champs sont pré-remplis.

### Ouverture des fichiers (PDF, documents…)

Lorsqu'un lien pointe vers un fichier que le navigateur ne peut pas afficher directement (PDF, document Word, Excel…), Sésame le télécharge automatiquement et l'ouvre dans l'application appropriée installée sur votre appareil (visionneuse PDF, application Office…).

Un indicateur "Téléchargement en cours…" s'affiche pendant le transfert. Si le fichier est sur un site sur lequel vous êtes connecté, les identifiants de session sont transmis automatiquement — le fichier est accessible sans nouvelle saisie de mot de passe.

### Liens vers des services de stockage cloud (Google Drive, Proton Drive…)

| Service | Comportement |
|---|---|
| **Google Drive** | Téléchargement direct et ouverture dans la visionneuse PDF |
| **Proton Drive, OneDrive, Dropbox, Box, SharePoint** | Ouverture dans le navigateur Android |

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

### Séparateurs

En mode réorganisation, appuyez sur le **+** dans la barre du haut pour insérer un séparateur. Il apparaît en bas de la liste — glissez-le à l'endroit voulu pour diviser vos raccourcis en groupes visuels. Pour le supprimer, appuyez sur l'icône **corbeille** à sa gauche.

---

## Catalogues en ligne

Les catalogues en ligne sont des listes de raccourcis prêts à l'emploi, publiés et mis à jour par l'administrateur de l'application.

### Importer un catalogue

1. Appuyez sur le menu **⋮**, puis **Catalogues en ligne**.
2. L'application télécharge la liste des catalogues disponibles.
3. Chaque carte affiche le nom, la description et le nombre de raccourcis.
4. Appuyez sur un catalogue pour l'ouvrir.
5. Sélectionnez les raccourcis à ajouter (les raccourcis déjà présents sont grisés).
6. Appuyez sur **Ajouter** pour les intégrer à votre liste.

### Mise à jour d'un catalogue

Lorsqu'une nouvelle version d'un catalogue est disponible, la carte affiche le badge **"Mise à jour"**. Appuyez dessus et importez les nouveaux raccourcis exactement comme lors du premier import.

### Mode hors-ligne

Si vous n'avez pas de connexion Internet, la liste des catalogues s'affiche à partir du dernier téléchargement connu. Le contenu des catalogues eux-mêmes n'est pas mis en cache : une connexion est nécessaire pour les ouvrir.

---

## Exporter et importer ses raccourcis

### Exporter

1. Appuyez sur le menu **⋮** en haut à droite, puis **Exporter**.
2. Saisissez une **passphrase** (mot de passe de chiffrement) et confirmez.
3. Partagez le fichier `.lncr` généré via l'application de votre choix (Drive, mail, WhatsApp…).

> Le fichier est chiffré : sans la passphrase, son contenu est illisible.

> **Conseil** : conservez un fichier `.lncr` à jour comme sauvegarde de secours. C'est le seul moyen de restaurer vos données en cas de réinitialisation de l'application.

### Importer

1. Appuyez sur le menu **⋮**, puis **Importer**.
2. Sélectionnez le fichier `.lncr` dans le gestionnaire de fichiers.
3. Saisissez la passphrase utilisée lors de l'export.
4. Choisissez comment importer :
   - **Remplacer** — efface tous les raccourcis existants et les remplace par ceux du fichier.
   - **Ajouter** — fusionne avec les raccourcis existants. Si un nom est identique, un numéro est ajouté automatiquement (ex. : "Ma banque (2)").

---

## Questions fréquentes

**Le logo du site ne s'affiche pas.**
Si l'icône du site n'est pas disponible, une icône générique est affichée à la place. Cela n'affecte pas le fonctionnement du raccourci.

**J'ai supprimé un raccourci par erreur.**
La suppression est définitive. Vous devrez recréer le raccourci via le bouton **+**.

**Le site ne se charge pas.**
Vérifiez votre connexion internet. Vous pouvez aussi appuyer sur l'icône **refresh** pour réessayer.

**J'ai oublié ma passphrase d'export.**
La passphrase est connue de vous seul. Sans elle, le fichier `.lncr` est inaccessible.
