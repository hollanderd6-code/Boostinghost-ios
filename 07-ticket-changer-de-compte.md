# T6 — Écran « Changer de compte »

Ticket de conception : spécification à compléter avant d'écrire la modale iOS.

---

## Ce que fait la modale web

La modale web (`bh-layout.js`) propose trois niveaux de sélection :

1. **Mon compte** — espace personnel du compte connecté.
2. **Tous les comptes** — vue globale agence, agrégat de tous les logements des comptes délégants.
3. **Liste des comptes délégants individuels** — chaque compte propriétaire dont l'agence gère les biens.

L'option sélectionnée est mémorisée côté web dans la clé `localStorage` `bh_agency_view`.

---

## Paramètre `?agency=all`

La vue globale correspond au paramètre `?agency=all`. Il est accepté — et traité par `getAgencyUserIds` côté serveur — sur au moins les routes suivantes :

- `GET /api/aujourdhui/etats`
- `GET /api/chat/conversations`
- `GET /api/cleaning/assignments`
- et toute autre route qui appelle `getAgencyUserIds` dans `server.js`

`getAgencyUserIds` retourne `[userId]` seul quand le compte n'a aucune délégation acceptée : le paramètre est donc sans effet pour un compte simple.

---

## Comptes délégants individuels — À RELEVER

La sélection d'un compte délégant individuel **ne passe pas par `?agency=all`** ; c'est un mécanisme distinct. Pistes à confirmer dans `server.js` avant de spécifier l'écran :

- Routes `/api/impersonation/*` (préfixe observé côté web).
- Clé `localStorage` `bh_agency_view` : quelle valeur est stockée pour un compte individuel, et quel paramètre ou header cela produit-il dans les requêtes ?

**Ne pas spécifier ni implémenter cette partie avant d'avoir relevé les routes réelles.**

---

## État actuel de l'app

En attendant cet écran, `TodayViewModel` force `agencyAll = true` par défaut. La propriété reste modifiable : c'est elle que le sélecteur pilotera (`true` pour « Tous les comptes », valeur ou header à définir pour un compte individuel).

---

## Ce qui reste à faire avant d'ouvrir l'écran dans Xcode

1. Relever dans `server.js` le mécanisme des comptes délégants individuels (routes `/api/impersonation/*` ou autre).
2. Décider comment la sélection est transmise à chaque appel réseau (header supplémentaire ? paramètre query ? jeton temporaire ?).
3. Écrire la spec écran complète (une fois les points 1 et 2 tranchés).
