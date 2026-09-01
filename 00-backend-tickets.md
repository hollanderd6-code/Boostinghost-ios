# Cinq tickets backend

Repo `lcc-booking-manager`, branche `main`.

**Mise à jour du 1er septembre, après relevé du code : il n'en reste que trois, et un seul est bloquant.** T1 et T5 étaient des faux problèmes — détail ci-dessous.

---

## T1 — ~~`POST /api/auth/token`~~ **ANNULÉ, rien à faire**

Je supposais que le backend n'authentifiait que par cookie de session. C'est faux : `POST /api/auth/login` renvoie déjà un JWT, `POST /api/sub-accounts/login` fait de même pour les sous-comptes en incluant les permissions, `GET /api/auth/verify` valide un jeton, et `POST /api/auth/refresh-faceid` en délivre un de 90 jours pour la reconnexion biométrique.

L'app web Capacitor fait déjà tout ce dont l'app iOS a besoin, Face ID compris.

**Aucune ligne de Node à écrire.** Le flux à reproduire côté Swift est décrit dans `05-auth-implementation.md`.

---

## T2 — `GET /api/aujourdhui/etats` — **CODE ÉCRIT, prêt à déposer**

Le fichier `T2-aujourdhui-routes.js` contient la route complète, et `06-ticket-T2.md` explique les trois causes du bug des sept arrivées. À déposer dans `routes/aujourdhui-routes.js` du dépôt backend.

Ce qui suit est la spécification d'origine, conservée pour référence.

### Spécification

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

Trois endroits à toucher, pas un :
1. la colonne dans `sub_account_permissions` ;
2. la table `permissionMapping` de `sub-accounts-middleware.js` — sans entrée là, `requirePermission` cherche une colonne qui n'existe pas et refuse tout ;
3. l'écran Équipe & accès, pour pouvoir cocher le droit.

Le droit arrive ensuite tout seul dans `subAccount.permissions` à la connexion.

---

## T5 — ~~`can_view_calendar` vs `can_view_reservations`~~ **FAUX PROBLÈME**

Ce n'est pas une incohérence, c'est une traduction volontaire. `sub-accounts-middleware.js` porte une table `permissionMapping` qui convertit les noms du front vers les colonnes de la base :

```
can_view_reservations  → can_view_calendar
can_manage_cleaning    → can_assign_cleaning
can_view_conversations → can_view_messages
can_mark_read          → can_view_messages
can_generate_booking_messages → can_send_messages
```

`can_view_calendar` est la colonne réelle ; `can_view_reservations` est l'alias côté front. Les deux sont corrects.

**Conséquence pour l'app :** elle reçoit les **noms de colonnes** dans `subAccount.permissions`, donc elle doit tester `can_view_calendar`, pas `can_view_reservations`. La correspondance de la barre d'onglets est corrigée dans `02-architecture.md`.

Rien à faire côté serveur.
