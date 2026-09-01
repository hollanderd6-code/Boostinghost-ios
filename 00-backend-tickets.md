# Cinq tickets backend

Repo `lcc-booking-manager`, branche `main`. Les deux premiers bloquent toute l'app.

---

## T1 — `POST /api/auth/token` (bloquant)

Le web authentifie par cookie de session ; une app native a besoin d'un jeton qu'elle range dans le Keychain.

L'infrastructure JWT existe déjà : `routes/chat_routes.js` vérifie `Bearer` avec `jsonwebtoken` et `process.env.JWT_SECRET`, et `sub-accounts-middleware.js` expose `authenticateAny`. Il manque la route d'émission.

**Requête** `{ email, password }`

**Réponse 200**
```json
{
  "token": "<jwt>",
  "expires_in": 2592000,
  "user": { "id": "...", "email": "...", "name": "Marc Dubois", "plan": "agence" },
  "is_sub_account": false,
  "permissions": null
}
```

Pour un sous-compte : `is_sub_account: true` et `permissions` = l'objet complet des colonnes `can_*` (voir T4/T5). L'app en dérive sa barre d'onglets ; elle ne doit pas avoir à faire un second appel pour savoir quoi afficher.

**Réponse 401** `{ "error": "Identifiants incorrects" }` — message affichable tel quel.

Durée de vie longue (30 jours) plutôt qu'un refresh token : l'app est mono-utilisateur et le Keychain est protégé par la biométrie.

---

## T2 — `GET /api/aujourdhui/etats` (bloquant)

Vue unifiée du jour. Cette route existait sur la branche `refonte-modules` puis a été perdue au reset ; elle est à réécrire proprement.

Elle règle deux bugs constatés : les quatre arrivées affichées au lieu de sept, et les heures de départ absentes.

**Paramètres** `?date=YYYY-MM-DD` (défaut : aujourd'hui), `?agency=all` (optionnel, même convention que les autres routes).

**Réponse**
```json
{
  "date": "2026-09-01",
  "compteurs": { "arrivees": 7, "departs": 2, "a_traiter": 2, "menages": 2 },
  "arrivees": [{
    "reservation_id": "...", "conversation_id": 1234,
    "property_id": "...", "property_name": "AM4",
    "guest_name": "Marc Dupont", "platform": "booking",
    "arrival_time": "16:00", "nights": 2,
    "police_form_signed": false, "codes_sent": false, "blocking": ["fiche_police", "infos_bloquees"]
  }],
  "departs": [{ "…": "…", "departure_time": "11:00" }],
  "menages": [{
    "property_name": "AM4", "cleaner_name": "Camila", "cleaner_phone": "0751006580",
    "window_start": "10:00", "window_end": "16:00", "status": "todo"
  }]
}
```

**`arrival_time` et `departure_time` sont obligatoires** et doivent tomber sur l'heure du **logement** (`properties.arrival_time` / `departure_time`), non sur une valeur par défaut. Un `null` ici casse l'écran Aujourd'hui et l'écran Ménage.

Le comptage doit inclure toutes les plateformes et les réservations directes. Le bug des sept arrivées venait d'une jointure qui perdait les réservations sans `channex_booking_id`.

---

## T3 — Exposer le brouillon hôte dans la liste des conversations

`integrated-chat-handler.js` génère déjà un brouillon Groq à chaque escalade (mode `ownerDraft`, log `✍️ [SUGGESTION] Brouillon prêt pour conv N`). Mais `GET /api/chat/conversations` ne le renvoie pas.

Sans ce champ, la pastille « L'IA a passé la main » ne peut pas ouvrir le fil avec le texte déjà prêt — l'app devrait faire un appel par conversation.

Ajouter au `SELECT` de `routes/chat_routes.js` (~ligne 321) :

```
draft_reply        TEXT | null
draft_generated_at TIMESTAMP | null
```

Vérifier au passage où le brouillon est réellement stocké : aucune colonne `suggested_reply` / `draft_reply` n'apparaît dans le dépôt. `À TRANCHER` : s'il n'est pas persisté, il faut une colonne sur `conversations`.

---

## T4 — Ajouter le droit `can_view_owners`

L'app sépare Propriétaires et Séjours en deux sous-écrans. Or `can_view_invoices` ouvre aujourd'hui à la fois `factures.html` et `clients.html` (`bh-layout.js` lignes 170-171).

- `can_view_invoices` garde les factures séjour et les cautions.
- `can_view_owners` (nouvelle colonne `sub_account_permissions`, défaut `FALSE`) couvre les propriétaires, contrats, factures propriétaires, attestation fiscale, débours.

À ajouter aussi dans l'écran Équipe & accès et dans le payload de T1.

---

## T5 — Trancher `can_view_calendar` vs `can_view_reservations`

Le même droit porte deux noms selon le fichier :

- `can_view_calendar` — `CLAUDE.md`, `enable-message-permissions.js`, `list-subaccounts.js`
- `can_view_reservations` — `public/js/bh-layout.js`, `public/js/sub-account-guard.js`

Vérifier la colonne réelle en base, garder ce nom, et corriger les autres. L'app dérive sa barre d'onglets de ces clés : une faute de frappe masque un onglet entier sans erreur visible.
