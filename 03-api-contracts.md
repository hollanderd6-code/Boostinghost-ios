# Contrats d'API

Base : `https://lcc-booking-manager.onrender.com`
En-tête : `Authorization: Bearer <jwt>` sur tout ce qui suit.
Mode agence : ajouter `?agency=all` (voir `02-architecture.md`).

Les routes marquées **À CONSTRUIRE** sont les tickets T1 et T2.

---

## Authentification

### `POST /api/auth/token` — **À CONSTRUIRE (T1)**
Voir `00-backend-tickets.md`.

---

## Aujourd'hui

### `GET /api/aujourdhui/etats` — **À CONSTRUIRE (T2)**
Voir `00-backend-tickets.md`. Alimente l'écran 02 en un seul appel, plus le bloc « ménages du jour ».

---

## Messages

### `GET /api/chat/conversations`
Filtres optionnels : `?status=`, `?property_id=`.

Champs réellement renvoyés (relevés dans `routes/chat_routes.js`) :

```
id, user_id, property_id, status, escalated, escalated_at, ai_disabled,
onboarding_completed, is_verified, platform, guest_name, guest_email, guest_phone,
guest_first_name, guest_last_name, reservation_start_date, reservation_end_date,
channex_booking_id, unique_token, pin_code, photos_token, last_message_at, created_at,
property_name, property_color,
guest_country, guest_language, guest_city, occupancy_adults, occupancy_children,
amount_total, amount_rooms, amount_taxes, amount_cleaning, ota_commission, host_payout,
days_breakdown, currency,
unread_count, last_message, last_message_time,
guest_display_name, guest_initial
```

Correspondance avec l'écran 04 :
```
non lu           unread_count > 0
à reprendre      escalated == true
IA en pause      ai_disabled == true
extrait          last_message
horodatage       last_message_time
badge plateforme platform (normalisé, cf. 01-design-tokens)
nom affiché      guest_display_name
```
`draft_reply` s'ajoute avec T3.

### `GET /api/chat/messages/:conversationId`
```
messages[]: id, conversation_id, sender_type, sender_name, message,
            is_read, is_bot_response, is_auto_response,
            created_at, read_at, delivered_at
conversation: id, guest_display_name, guest_initial, guest_phone
```
`sender_type` : `guest` | `owner` | `property`. `is_bot_response` / `is_auto_response` distinguent l'assistant de l'hôte — à traiter visuellement, un message auto n'est pas un message de Marc.

### `POST /api/chat/send`
`{ conversation_id, message, sender_type: "owner", sender_name, photo_data? }`

`photo_data` accepte un base64 `data:image/…`. Pour une réservation directe sans app voyageur, le serveur relaie automatiquement par mail (Brevo) et SMS — l'app n'a rien à faire.

### `POST /api/chat/mark-read/:conversationId`
À appeler à l'ouverture d'un fil.

### `POST /api/chat/toggle-ai/:conversationId`
Renvoie `{ success, ai_disabled }`. Réactiver l'IA remet `escalated` à `FALSE` côté serveur.

---

## Calendrier — vue Revenus

### `GET /api/reporting?year=&month=&property_id=`
`month` et `property_id` optionnels.

```
year
summary: totalGrossRevenue, totalNetRevenue, totalOwnerRevenue, totalConcierge,
         totalOtaCommission, totalCleaningFee, totalTouristTax,
         totalBookings, totalNights, avgNightsPerBooking
monthly[]      série 12 mois
platforms[]    répartition par plateforme
byProperty[]   détail par logement
```

L'écran 03 n'affiche que : `totalGrossRevenue`, `totalNetRevenue`, `totalConcierge`, `totalOwnerRevenue`, `totalBookings`, `totalNights`, `totalOtaCommission`, la moyenne par nuit (calculée), `platforms` et les quatre premiers de `byProperty`. Le comparateur, le score de rentabilité et les tableaux mensuels restent sur le web.

Le web fait un second appel sans `month` pour garder le graphe annuel. L'app n'a pas de graphe annuel : un seul appel suffit.

---

## Logements

### `GET /api/properties`
`{ properties: [{ id, name, ... }] }`

Champs de la fiche, relevés du formulaire web : `name`, `internal_name`, `address`, `arrival_time`, `departure_time`, `deposit_amount`, `deposit_release_days`, `capacity`, `bedrooms`, `beds`, `bathrooms`, `base_price`, `weekend_price`, `cleaning_fee`, `tourist_tax`, `concierge_commission`, `airbnb_commission`, `booking_commission`, majorations par plateforme, `min_nights`, `welcome_url`, `access_code`, `access_instructions`, `wifi_name`, `wifi_password`, `photo`, `amenities` (JSON), `house_rules` (JSON), `practical_info` (JSON : `parking_details`, poubelles, commerces, transports), prestations payantes, ménage régulier, Q&R IA, faits mémorisés, raccourcis messages.

`amenities`, `house_rules` et `practical_info` arrivent **soit en objet, soit en chaîne JSON** — le serveur fait un `typeof === 'string' ? JSON.parse` avant usage. Le décodeur Swift doit tolérer les deux.

Écriture de la fiche : **`04-routes-relevees.md`, section 1.** C'est du `multipart/form-data` en camelCase, pas du JSON.

---

## Séjours et propriétaires

Routes non relevées en détail. Pages web de référence : `deposits.html` (cautions, Stripe), `factures.html` (factures séjour), `clients.html` (propriétaires, éditeur, attestation, débours), `contrat.html` + `signer-contrat.html`, `factures-proprietaires.html`.

Relevés : **`04-routes-relevees.md`, sections 2 et 3.**

---

## Envoi de mail

`sendEmailViaBrevo` est injecté dans les routes serveur. Le PDF de contrat signé passe par là : l'app envoie le PNG de signature, le serveur produit et expédie le PDF. Pas de génération de PDF côté app.
