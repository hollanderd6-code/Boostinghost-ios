# 10 — Mon compte

Maquette : `2a`. Source : `settings-account.html`, `sub-account.html`, `help.html`.

**Feuille modale**, ouverte par le rond aux initiales de n'importe quelle barre de navigation. Pas un onglet.

## Structure

L'écran du dessous reste visible derrière le verre, comme les feuilles iOS 26 : la couche d'aperçu est **découpée au bord de la feuille** (`top: 34`, `overflow: hidden`) pour ne pas passer derrière la barre d'état.

- **En-tête en verre** : poignée 38×5, « Mon compte » 30/bold, « Fermer » 16.5/semibold vert à droite.
- **Carte de profil** : rond d'initiales 52×52, nom 18.5/semibold, « Formule Agence · 26 logements », chevron.
- **Groupe 1** — Abonnement et factures · Mon équipe et accès (4 personnes) · Comptes gérés (3 délégations) · Plateformes connectées (**2 actives**, en `#0E3B2E`/semibold : c'est la seule valeur du groupe qui signale un état, pas un décompte).
- **Groupe 2** — Ménage et prestataires (5 intervenants) · Messages automatiques (17 modèles) · Notifications.
- **Groupe 3** — Aide et tutoriels · Nous écrire (Réponse sous 2 h).
- **« Se déconnecter »** — carte pleine largeur, texte centré 16.5/semibold `#A8452A`.
- **Pied** : « Boostinghost 3.2 · CGU · Confidentialité » 12.5, centré.

Les valeurs à droite des lignes sont en `#5E6B63` — jamais plus clair, c'est le seuil de contraste.

## Ce qui vient s'y ranger

Depuis Messages : **modèles de messages et statut SMS**. Le logement devient un filtre à l'intérieur, ce qui supprime le doublon avec la fiche logement.
Depuis les paramètres web : profil & entreprise, paiements & Stripe, équipe & accès, notifications, abonnement.
Depuis `factures.html` : les **réglages** de facturation seulement — numérotation, mentions légales, TVA, coordonnées. Les factures elles-mêmes restent dans Séjours.
Depuis `help.html` : le support.

## Sous-compte

`sub-account-guard.js` ferme `settings-account.html` et `help.html` à tous les sous-comptes (`BLOCKED_PAGES`), sans exception. Pour un sous-compte, cette feuille se réduit donc à la carte de profil et à « Se déconnecter ». Ni réglages, ni support.
