# T2 — `GET /api/aujourdhui/etats`

Le code est dans **`T2-aujourdhui-routes.js`**, à déposer tel quel dans `routes/aujourdhui-routes.js` du dépôt **`lcc-booking-manager`** (pas dans le dépôt iOS).

Branchement dans `server.js`, à côté des autres `setup*` :

```js
require('./routes/aujourdhui-routes')(app, pool, authenticateAny, checkSubscription);
```

---

## Les deux bugs, et leur cause

### Quatre arrivées au lieu de sept

L'ancien calcul partait des **conversations** et joignait les réservations sur `channex_booking_id`. C'est le motif qu'on retrouve dans `routes/chat_routes.js` :

```sql
LEFT JOIN reservations r ON (
  (c.channex_booking_id IS NOT NULL AND r.channex_booking_id = c.channex_booking_id)
  OR (c.channex_booking_id IS NULL AND r.property_id = c.property_id AND …)
)
```

Toute réservation **sans** identifiant Channex — les directes, les manuelles, les BHGuest — n'avait pas de conversation à laquelle se raccrocher, donc disparaissait du compte.

La route inverse le sens : **`reservations` mène, `conversations` suit en `LEFT JOIN`.** Une réservation sans conversation reste comptée ; elle porte simplement `conversation_id: null` et un motif de blocage `pas_de_conversation`.

Deuxième cause, plus sournoise : comparer avec `DATE(r.start_date)` sur une colonne `timestamptz` décale le jour de deux heures en été. Une arrivée du 1er septembre à 00 h 30 heure de Paris est le 31 août en UTC. La route utilise `TO_CHAR(…, 'YYYY-MM-DD')`, insensible au fuseau, comme le fait déjà `routes/pricing-engine.js`.

Même problème côté Node : `new Date().toISOString().slice(0,10)` renvoie demain à partir de 22 h heure française. D'où l'`Intl.DateTimeFormat('fr-CA', { timeZone: 'Europe/Paris' })`.

Troisième cause possible, traitée par précaution : `DISTINCT ON (r.uid)`. Deux conversations peuvent pointer le même séjour — une ancienne, une recréée. Sans lui, la réservation est comptée **deux fois**, ce qui peut aussi expliquer un écart dans l'autre sens.

### Aucune heure de départ

Les heures ne viennent d'aucun défaut codé en dur : elles sont lues sur le **logement**, `p.arrival_time` et `p.departure_time`, formatées en `HH:MM`. Ce sont les mêmes colonnes que le formulaire de la fiche écrit (`arrivalTime` / `departureTime`).

Si un logement n'a pas d'heure renseignée, le champ vaut `null` — l'app affiche « heure non renseignée » plutôt qu'une heure fausse. Sur tes 26 logements, ils ont tous 15 h / 10 h ou 15 h / 11 h.

---

## Réponse

```json
{
  "date": "2026-09-01",
  "compteurs": { "arrivees": 7, "departs": 2, "a_traiter": 2 },
  "arrivees": [{
    "reservation_uid": "…", "conversation_id": 1234,
    "property_id": "…", "property_name": "AM4", "property_address": "41 TER rue…",
    "guest_name": "Marc Dupont", "guest_phone": "+336…",
    "platform": "booking", "arrival_time": "16:00", "nights": 2, "guests": 3,
    "amount_total": 186.0, "unread_count": 1,
    "escalated": true, "ai_disabled": false,
    "blocking": ["ia_a_passe_la_main", "message_non_lu"]
  }],
  "departs": [{ "…": "…", "departure_time": "11:00" }]
}
```

### Trois choix à connaître

**`property_name` renvoie le nom interne s'il existe**, sinon le nom public — `COALESCE(NULLIF(p.internal_name,''), p.name)`. C'est la convention du reste du code : sur l'écran, tu veux lire « AM4 », pas « Charmant studio proche gare ».

**Un séjour d'une nuit apparaît dans les deux listes.** Il arrive et part le même jour ; le masquer d'un côté est un bug, pas une simplification.

**`blocking` ne contient que ce qui est prouvé en base** : pas de conversation, IA qui a passé la main, message non lu, code d'accès manquant. Je n'ai pas inventé « fiche police non signée » ni « infos bloquées » : ces états existent probablement dans le flux `checkin.html`, mais je n'ai pas relevé leur table. À compléter quand ce sera fait — les maquettes les montrent, la route ne les invente pas.

---

## Ce que la route ne renvoie pas, volontairement

**Les ménages du jour.** Ils sont sur la maquette `1a`, mais je n'ai pas pu relever les tables du ménage : leurs routes sont définies dans `server.js`, qui dépasse la limite de lecture. Plutôt que de deviner des noms de colonnes, l'app fait un **second appel à `GET /api/cleaning/assignments`**, qui existe déjà et que `cleaning.html` utilise.

Deux appels au lieu d'un, c'est acceptable : ils partent en parallèle et la section Ménage est la dernière de l'écran. Si tu veux les fusionner plus tard, il suffira d'ajouter un bloc `menages` à cette route.

---

## Droits et mode agence

La route reprend exactement les protections des autres : `authenticateAny`, `checkSubscription`, `requirePermission(pool, 'can_view_reservations')` — qui est traduit en `can_view_calendar` par la table de correspondance —, `loadSubAccountData` et `filterByAccessibleProperties`.

Un sous-compte restreint à trois logements ne voit donc que les mouvements de ces trois logements, et les compteurs suivent. Le mode agence fonctionne avec `?agency=all`, comme partout ailleurs.

---

## Vérifier que le bug est corrigé

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://lcc-booking-manager.onrender.com/api/aujourdhui/etats" | jq '.compteurs'
```

Puis compare avec le compte réel dans le calendrier web pour la même journée. Si l'écart persiste, le coupable suivant est le statut : la clause exclut `cancelled`, `canceled` et `annulee`, mais si ta base utilise un autre libellé, il faut l'ajouter. Un `SELECT DISTINCT status FROM reservations` le dira en une seconde.
