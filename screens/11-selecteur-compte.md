# 11 — Sélecteur de compte

Source web : modale « Changer de compte » dans `bh-layout.js`.
Routes : `GET /api/agency/delegations` · `POST /api/agency/switch`.

**Feuille modale**, ouverte depuis la ligne « Comptes gérés » de la feuille
Mon compte (écran 10). Le rond aux initiales ouvre Mon compte — pas ce sélecteur
directement.

---

## Les deux mécanismes, mutuellement exclusifs

### 1 · Tous les comptes — `?agency=all`

Aucun changement de jeton. L'app ajoute `?agency=all` à chaque appel réseau.
Le jeton Keychain courant reste intact.

### 2 · Un compte délégant précis — jeton `agency_access`

```
POST /api/agency/switch   { targetUserId: String }
→  jeton agency_access valable 24 h
```

Ce jeton remplace temporairement le jeton actif. Il est utilisé **sans**
`?agency=all` : le serveur sait à quel périmètre répondre grâce au jeton lui-même.

---

## Contrats d'API (relevés)

### `GET /api/agency/delegations`

Réponse plate, non enveloppée :

```json
{
  "canActAsAgent": true,
  "iManage": [
    {
      "id": "...",
      "userId": "...",
      "name": "...",
      "email": "...",
      "propertyCount": 5,
      "permissions": { ... },
      "acceptedAt": "..."
    }
  ],
  "myDelegates": [ ... ]
}
```

**`iManage`** = les comptes que ce compte gère. C'est cette liste qui alimente
le sélecteur. Tous les éléments sont acceptés (la requête filtre déjà) ; pas de
champ `status`.

**`myDelegates`** = l'inverse (les agents qui accèdent à mon compte). Non utilisé
dans cette vue.

**`canActAsAgent`** : si `false`, le compte n'a pas le droit de basculer. La ligne
« Comptes gérés » n'est pas affichée dans Mon compte.

**403** : la route renvoie 403 pour un sous-compte. Traité silencieusement comme
`canActAsAgent = false`.

### `POST /api/agency/switch`

Corps : `{ "targetUserId": "<userId de la délégation>" }`

Réponse :

```json
{
  "success": true,
  "token": "<agency_access JWT valable 24 h>",
  "permissions": { ... },
  "managedUser": { "id": "...", "name": "...", "email": "..." }
}
```

Erreurs 403 possibles : sous-compte, plan non-agence, délégation introuvable.

### Pas de route de sortie

Le retour à « Mon compte » se fait uniquement en restaurant le jeton d'origine
depuis le Keychain (`jwt_origin`).

---

## Stratégie Keychain — ne pas reproduire le bug web

Le web ne restaure pas le jeton d'origine quand on quitte le mode délégant. L'app
corrige ce comportement en maintenant deux clés distinctes :

| Clé Keychain | Contenu |
|---|---|
| `jwt` | jeton actif utilisé par tous les appels |
| `jwt_origin` | jeton d'origine, sauvegardé avant le switch délégant ; **absent** hors mode délégant |

**Sélection « Mon compte » ou « Tous les comptes »** (depuis le mode délégant) :
restaurer `jwt_origin` dans `jwt`, supprimer `jwt_origin`, effacer le jeton du
`APIClient`.

**Sélection d'un compte délégant** (depuis n'importe quel mode) :
si `jwt_origin` est absent, copier `jwt` dans `jwt_origin` ; appeler
`/api/agency/switch` ; sauvegarder le nouveau jeton dans `jwt`.

**Sélection d'un compte délégant différent** (switch→switch sans repasser par
Mon compte) : `jwt_origin` est déjà là — ne pas l'écraser, sinon on perdrait le
vrai jeton d'origine.

### Expiration du jeton agency_access (24 h)

Au lancement, si `GET /api/auth/verify` répond 401 alors que `jwt_origin` est
présent dans le Keychain : restaurer automatiquement `jwt_origin` dans `jwt`,
supprimer `jwt_origin`, replacer le contexte sur « Mon compte », et re-vérifier.

---

## Structure de la feuille

**En-tête en verre** : poignée 36×4, « Changer de compte » 20/semibold centré.

**Trois sections, dans cet ordre :**

### Section 1 — Compte personnel

Une seule ligne :

```
Rond d'initiales 40×40 (#DCE8E1 / texte #0E3B2E)
"Mon compte"  18/semibold  #14201B
sous-titre : nom du compte connecté  #5E6B63
                                               ✓  (si contexte actif)
```

Tap → restaure le jeton d'origine + ferme la feuille.

### Section 2 — Vue globale

Une seule ligne :

```
Icône building.2  fond #DCE8E1  texte #0E3B2E
"Tous les comptes"  18/semibold
sous-titre : "Vue agence complète"  #5E6B63
                                               ✓  (si contexte actif)
```

Tap → `agencyContext = .allAccounts` + ferme la feuille. Pas de changement de jeton.

### Section 3 — Comptes délégants

Intertitre capitales « COMPTES DÉLÉGANTS » (11.5/bold, `#5E6B63`).

Une ligne par délégation (`iManage`), dans l'ordre renvoyé par l'API :

```
Rond d'initiales (initiales du compte délégant)
Nom du compte délégant  16/semibold
sous-titre : "N logements"  #5E6B63
                                               ✓  (si contexte actif)
```

Tap → `POST /api/agency/switch`, spinner sur la ligne pendant le call, autres
lignes à 40 % d'opacité, fermeture automatique après succès.

Si `canActAsAgent == false` ou si `iManage` est vide, la section 3 est absente.

---

## États

**Switch en cours** : spinner sur la ligne sélectionnée, autres lignes à 40 %
d'opacité, impossible de toucher une autre ligne.

**Erreur sur `/switch`** : message inline sous la liste :
« Impossible de basculer sur ce compte. Vérifiez votre connexion. »

---

## Indicateur de contexte dans la barre de navigation

Quand `agencyContext == .delegating`, le fond du rond aux initiales passe en
terracotta `#A8452A`, le texte en blanc. C'est le seul indicateur visible dans
les quatre onglets.

---

## Visibilité de la ligne « Comptes gérés » dans Mon compte

La ligne « Comptes gérés » n'est affichée dans Mon compte (écran 10) que si
`canActAsAgent == true` (résultat de `GET /api/agency/delegations`).

`fetchDelegations()` est appelé à l'ouverture de la feuille Mon compte et son
résultat est mémorisé dans `AuthStore`.

---

## Ce qui reste ouvert

1. Wiring du `agencyAll` dans chaque ViewModel (Today, Calendar, Messages, Manage)
   pour que `?agency=all` suive `authStore.agencyContext == .allAccounts`.
2. Bannière « Session agence expirée — retour à Mon compte » à afficher en overlay
   global quand le 401 + restore est déclenché au lancement.
