# Routes relevées — les trois « À TRANCHER » sont fermés

Relevé le 1er septembre 2026 dans `lcc-booking-manager@main`, à partir des appels `fetch` du front web. Les définitions de routes vivent dans `server.js`, qui dépasse la limite de lecture — les URLs et les charges utiles sont donc lues côté client, ce qui est fiable pour l'app puisque c'est exactement ce que le serveur accepte aujourd'hui.

Base : `https://lcc-booking-manager.onrender.com` · `Authorization: Bearer <jwt>` partout.

---

## 1 · Écriture de la fiche logement

**`POST /api/properties`** (création) · **`PUT /api/properties/:id`** (modification)

Attention : **`multipart/form-data`, pas JSON.** Le web construit un `FormData` (à cause de la photo). L'app doit faire pareil.

Clés en **camelCase**, une par champ :

```
name                    obligatoire
internalName            toujours envoyé, même vide (permet d'effacer)
color                   hex, défaut #E67E50
address
arrivalTime             "15:00"
departureTime           "10:00"
depositAmount           nombre
depositReleaseDays      entier
photoUrl                URL existante à conserver
photo                   fichier binaire (nouvelle photo)
welcomeBookUrl
accessCode
wifiName
wifiPassword
accessInstructions
basePrice
weekendPrice
cleaningFee
touristTaxPerNight
conciergePct
airbnbCommissionPct     défaut 3
bookingCommissionPct    défaut 15
maxGuests, bedrooms, beds, bathrooms
icalUrls                chaîne JSON
amenities               chaîne JSON  (voir ci-dessous)
houseRules              chaîne JSON
practicalInfo           chaîne JSON
autoResponsesEnabled    booléen
quickReplies            chaîne JSON  [{ title, text }]  — 5 max
customAutoResponses     chaîne JSON  (Q&R personnalisées)
ownerId                 toujours envoyé, même vide (permet de délier)
```

### `practicalInfo` — c'est le bloc « Le quartier »

```json
{ "parking_details": "", "trash_day": "", "nearby_shops": "", "public_transport": "" }
```

**Exactement les quatre champs de l'écran 06b.** Le découpage en neuf blocs correspond donc déjà à la structure de données ; il n'y a rien à migrer côté serveur.

### `amenities` et `houseRules`

```json
amenities  { "draps": false, "serviettes": false, "cuisine_equipee": false,
             "lave_linge": false, "lave_vaisselle": false, "television": false,
             "parking": false, "climatisation": false, "custom": [] }
houseRules { "animaux": false, "fumeurs": false, "fetes": false,
             "enfants": false, "custom": [] }
```

### Pièges de décodage, vérifiés dans le code

1. **Les lectures mélangent camelCase et snake_case.** Le front fait systématiquement `property.basePrice ?? property.base_price`. Le décodeur Swift doit accepter les deux formes pour chaque champ, sinon la moitié des valeurs arrivent à `nil`.
2. **L'identifiant est `_id` ou `id`** selon les enregistrements : `p._id || p.id` partout dans le web.
3. **`amenities` arrive parfois en tableau, parfois en objet, parfois en chaîne JSON.** Le code de duplication traite le cas tableau, le code de sauvegarde produit un objet. Décoder de façon tolérante.
4. **`practicalInfo` arrive en objet ou en chaîne JSON** — `typeof v === 'string' ? JSON.parse(v) : v`.

### Le reste du logement

```
DELETE /api/properties/:id
PUT    /api/properties/:id/reorder
GET    /api/properties/:property_id/sante        état vendable + causes de blocage
PATCH  /api/properties/:id/markups               majorations par plateforme
POST   /api/properties/:id/regroupement          regroupement OTA (même immeuble)
POST   /api/properties/:id/coherence/repair
```

`/sante` est utile à l'écran 06 : elle dit **pourquoi** un logement ne se vend pas (disponibilités jamais poussées, tarifs absents, Stripe propriétaire inutilisable). C'est exactement ce que la carte « 1 logement à préparer » de l'écran 05 doit afficher.

### Groupes de logements

Persistés en base (table `property_groups`), plus dans le localStorage.

```
GET    /api/property-groups          → { groups: [{ id, name, propertyIds: [] }] }
POST   /api/property-groups          { name, propertyIds }
PUT    /api/property-groups/:id      { name } ou { propertyIds }
DELETE /api/property-groups/:id
```

**Un logement ne peut appartenir qu'à un seul groupe** : le web le retire des autres avant de l'ajouter. À reproduire.

---

## 2 · Cautions et factures de séjour

### Cautions (Stripe)

```
GET  /api/reservations-with-deposits    liste des séjours avec empreinte
GET  /api/reservations-with-payments
GET  /api/payments
POST /api/deposits/:depositId/capture   RETENIR (débite)
POST /api/deposits/:depositId/release   RESTITUER (libère l'empreinte)
GET  /api/stripe/status
GET  /api/stripe/balance
```

Les deux boutons de l'écran 09 tombent exactement sur `capture` et `release`. Le vocabulaire du code est technique (capture / release) ; **ne pas le montrer à l'écran** — « Retenir » et « Restituer ».

`capture` est aussi appelée depuis `cleaning.html`, rattachée à un ticket de maintenance : une retenue suit en général un dégât constaté au ménage. `À TRANCHER` : est-ce que l'app doit permettre de retenir en attachant une photo ou un ticket, comme le web ?

### Factures de séjour (voyageur)

```
POST /api/invoice/create
POST /api/invoice/generate-pdf
GET  /api/invoice/history
GET  /api/invoice/download-by-number/:invoiceNumber
POST /api/invoice/resend
```

Une facture sans numéro est un **brouillon** — le web affiche « Brouillon » quand `invoice_number` est absent ou commence par « Brouillon ». C'est l'état des deux lignes à envoyer de l'écran 09.

---

## 3 · Propriétaires, contrats et signature

### Clients propriétaires

```
GET  /api/owner-clients                      → { clients: [] }
GET  /api/owner-clients/:id
POST /api/owner-clients
PUT  /api/owner-clients/:id
GET  /api/owner-clients/:id/stripe/status
POST /api/owner-clients/:id/stripe/connect
```

Le nom d'affichage dépend du type : `client_type === 'business'` → `company_name`, sinon `first_name + last_name`. Prévoir les deux, avec un repli « Client sans nom ».

### Factures propriétaires

```
GET  /api/owner-invoices
GET  /api/owner-invoices/:id
PUT  /api/owner-invoices/:id
POST /api/owner-invoices/:id/finalize        brouillon → facture numérotée
POST /api/owner-invoices/:id/send
POST /api/owner-invoices/:id/mark-paid
POST /api/owner-invoices/:id/credit-note     avoir
GET  /api/owner-invoices/:id/pdf
```

Les totaux excluent toujours les brouillons, les avoirs et les factures annulées. Reprendre cette règle telle quelle : c'est celle de `clients.html`.

### Débours

```
GET    /api/debours
GET    /api/debours?client_id=X&status=pending
POST   /api/debours
PUT    /api/debours/:id
DELETE /api/debours/:id
PUT    /api/debours/:id/status
```

Les débours en attente d'un client sont rattachés à sa facture lors de la finalisation.

### Attestation fiscale

```
POST /api/attestation/send
```
Le PDF est généré **côté client** en web (jsPDF), avec la signature du prestataire incrustée. Pour l'app, `À TRANCHER` : générer côté app avec PDFKit, ou déplacer la génération côté serveur. La seconde option est préférable — un seul gabarit à maintenir.

### Contrats — **le sens de la signature n'est pas celui que j'avais supposé**

```
GET  /api/contrats?limit=100                 liste
POST /api/contrat/send                       contrat de location (voyageur)
POST /api/mandat/send                        mandat de gestion (propriétaire)
GET  /api/contrats/:id/pdf
POST /api/contrats/:id/resend-sign           renvoyer le lien de signature
GET  /api/contrat/sign/:token                page publique, sans token d'auth
```

**Le flux réel, en trois temps :**

1. **La conciergerie signe la première.** Dans `contrat.html`, un canevas produit `signatureData` en `data:image/png;base64`. Sans elle, l'envoi est refusé (« Veuillez apposer votre signature »).
2. **`POST /api/contrat/send` ou `/api/mandat/send`** part avec le contenu du contrat, `signatureData` et `signatureDate` (ISO). Le serveur envoie **un lien de signature** par mail à l'autre partie.
3. **L'autre partie signe** sur `signer-contrat.html`, atteinte par ce lien. Cette page charge `GET /api/contrat/sign/:token`, affiche **la signature de la conciergerie déjà apposée**, puis recueille la seconde signature. Le PDF final part par mail aux deux.

Statuts, tels qu'affichés par le web :
```
sent     « En attente de signature »
signed   « Signé »
expired  « Expiré »
```

**Conséquence pour l'app.** L'écran de signature (maquette `9b`) est celui de **ta** signature, au moment de préparer le contrat — pas celui d'Hélène. L'app n'a pas à héberger la signature du propriétaire : elle se fait par le lien, sur son propre téléphone. Les maquettes `9a`/`9b` ont été corrigées en conséquence.

Un contrat déjà envoyé n'offre donc que trois actions : voir le PDF, renvoyer le lien, ou attendre.

### Signature — précédent à suivre dans le code

`cleaning-tasks.html` fait déjà exactement ce dont l'app a besoin, sur mobile :
```
signatureData    canvas.toDataURL('image/png')
signature_ip     enregistrée côté serveur à des fins de preuve
signature_data   stockée telle quelle, réaffichée en <img>
```
Même format pour l'app : PNG en base64, horodatage ISO, IP côté serveur. Pas de PDF généré par l'app.

---

## 4 · Ménage — routes complètes (bonus pour l'écran 07)

```
GET    /api/cleaning/assignments
POST   /api/cleaning/assignments
GET    /api/cleaning/default-cleaners
PUT    /api/cleaning/default-cleaner/:propertyId
GET    /api/cleaners
PUT    /api/cleaners/:id
DELETE /api/cleaners/:id
POST   /api/cleaners/:id/regenerate-link
PUT    /api/cleaners/:id/sms-toggle          ← le récap SMS de l'écran 07
GET    /api/cleaning/checklists
GET    /api/cleaning/checklists/:id
PUT    /api/cleaning/checklists/:id/validate
PUT    /api/cleaning/checklists/:id/reject    { notes }
GET    /api/cleaning/templates
POST   /api/cleaning/templates
DELETE /api/cleaning/templates/:id
GET    /api/cleaning/qr/:propertyId
GET    /api/consumables/alerts?status=open
GET    /api/maintenance/tickets
```

Côté intervenant, l'accès se fait **par PIN et sans jeton** : `GET /api/cleaning/tasks/:pin`, `POST /api/cleaning/checklist`, `POST /api/cleaning/photo-upload`. C'est une troisième voie, à côté du sous-compte et du SMS — utile à savoir avant de décider si l'app iOS sert les intervenants.

`validate` et `reject` sont les deux actions de la section « À VALIDER » de l'écran 07. Un rejet demande une note, affichée à l'intervenante.

---

## 5 · Routes transversales

```
GET  /api/user/profile
GET  /api/subscription/status
GET  /api/subscription/features
GET  /api/reservations
GET  /api/blocks
POST /api/sync
GET  /api/notifications/history?limit=50
POST /api/agency/refresh
GET  /api/agency/managed-properties
GET  /api/agency/properties/:delegatorUserId
GET  /api/agency/unified/cleaning
POST /api/translate
GET  /api/chat/conversations/:id/quick-context
POST /api/chat/conversations/:id/send-platform    répondre via Airbnb/Booking
GET  /api/chat/conversations/:id/messages-channex
```

`send-platform` mérite attention pour l'écran 04 : répondre à un voyageur Airbnb ou Booking ne passe pas par `/api/chat/send` mais par cette route, qui pousse le message sur la plateforme via Channex. **Deux boutons d'envoi différents selon `platform`** — à ne pas confondre, sinon le voyageur ne reçoit rien.

`À TRANCHER` : c'est le dernier point de l'écran Messages. Faut-il un choix explicite « répondre sur Airbnb » / « répondre dans BH Guest », ou l'app décide-t-elle seule selon la plateforme ?

---

## Ce qui reste ouvert

1. Retenue de caution avec photo ou ticket de maintenance rattaché, comme le web.
2. Génération du PDF d'attestation fiscale : app ou serveur.
3. Choix du canal de réponse dans Messages (`send-platform` contre `send`).
4. Mode agence en version 1.
5. Temps réel Socket.io en version 1.
6. APNs direct ou Firebase.
```
