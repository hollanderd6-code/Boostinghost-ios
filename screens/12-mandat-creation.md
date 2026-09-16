# 12 — Création d'un mandat de gestion

Source : `contrat.html` du dépôt backend (assistant web en 5 étapes).
Route d'envoi : `POST /api/mandat/send`.
Pré-remplissage : `GET /api/mandat/last` ou `GET /api/contrats/:id/duplicate-source`.

Ouvert depuis la fiche d'un propriétaire, ou depuis la liste Contrats.
L'écran collecte le mandat, le fait signer par la conciergerie, et l'envoie
au propriétaire qui signera depuis son propre téléphone.

## Pré-remplissage — avant la première étape

Trois sources se cumulent, dans cet ordre :

1. Le profil (`GET /api/user/profile`) remplit les champs conciergerie :
   companyName ← company, companyEmail ← email, companySiret ← siret,
   companyRep ← firstName + lastName, companyAddress ← address +
   postalCode + city, companyLogoUrl ← logoUrl.
   companyPhone, companyLegal, companyFreeTitle et companyFreeValue
   restent à saisir.
   Comme sur le web, un bandeau indique que ces infos viennent du profil
   et propose d'aller les modifier.

2. Le client sélectionné (`GET /api/owner-clients/:id`) remplit
   ownerFirstName, ownerLastName, ownerEmail, ownerAddress, ownerPhone.
   Un client délégué (is_agency_client) ne peut pas recevoir de mandat :
   le mandat appartient au compte propre.

3. Le dernier mandat (`GET /api/mandat/last`) remplit les conditions et
   les honoraires. Si `source` est null, on applique les défauts ci-dessous.
   Une bannière discrète signale le pré-remplissage et permet de repartir
   de zéro.

## Défauts

Relevés dans les `<option selected>` de contrat.html — ce sont les seules
valeurs par défaut existantes, il n'y a aucun stockage serveur.

| Champ | Valeur envoyée |
| --- | --- |
| dureeType | indeterminee |
| preavis | "30" |
| exclusivite | non |
| juridiction | lieu_bien |
| reversement | mensuel |
| tarifPreavis | "60" |
| confidentialite | "5" |
| renouvellement | tacite |
| respPlafond | oui |
| commissionBase | ht |
| tva | franchise |
| checkinTime | 15:00 |
| checkoutTime | 11:00 |
| animals | non |
| smoking | non |
| parties | non |

## Les cinq étapes

Barre de progression en tête, 5 segments. Retour possible à tout moment.
Bouton « Suivant » en barre d'action basse en verre, désactivé tant que
l'étape n'est pas valide.

### 1 — Parties et bien
Bloc conciergerie replié par défaut (pré-rempli, rarement modifié).
Bloc propriétaire : nom, prénom, email, adresse, téléphone.
Bloc bien : adresse, type, capacité, séjour min/max, animaux, fumeur,
fêtes, heures d'arrivée et de départ.

`propType` : appartement · maison · studio · villa · chambre ·
gite (Gîte / Chalet) · autre. Aucun par défaut.
`animals` : non (Non admis, défaut) · oui (Admis) · conditions (Sous conditions).
`smoking` : non (Interdit, défaut) · exterieur (Extérieur seulement) · oui (Autorisé).
`parties` : non (Interdits, défaut) · conditions (Sous conditions) · oui (Autorisés).

Requis : ownerEmail, ownerFirstName, ownerLastName (400 sinon).

### 2 — Missions

⚠️ RÈGLE CRITIQUE : le tableau `missions` envoyé au serveur contient les
LIBELLÉS affichés, pas des identifiants. Le web pousse le texte du label
(contrat.html:3016). Ces chaînes partent telles quelles dans le PDF.
L'app doit envoyer les libellés EXACTS ci-dessous, caractère pour caractère.

Aucune case n'est cochée par défaut. Sept catégories :

**Annonces & visibilité** — Prise de photos / vidéos · Rédaction & diffusion
des annonces · Optimisation du calendrier & tarifs · Gestion des avis &
e-réputation

**Réservations** — Traitement des demandes & confirmations · Messages
pré-arrivée & consignes · Coordination channel manager / PMS · Collecte des
informations voyageurs

**Accueil & départ** — Check-in physique · Check-in autonome · Check-out
physique · État des lieux entrée / sortie

**Ménage & linge** — Ménage de départ · Fourniture & blanchisserie du linge
· Réassort produits d'accueil · Contrôle qualité post-ménage

**Assistance voyageurs** — Support téléphonique & messages · Gestion des
incidents mineurs · Traitement des réclamations · Coordination artisans /
prestataires

**Maintenance & intendance** — Visites de contrôle · Petite maintenance ·
Interventions urgentes · Coordination travaux (sur devis validé)

**Gestion financière & administrative** — Perception des loyers pour le
compte du propriétaire · Perception du dépôt de garantie · Reversements
périodiques & relevés · Encaissement taxe de séjour · Fourniture d'un livret
d'accueil · Rédaction du contrat de location voyageurs

Champ libre : chaque mission personnalisée est ajoutée telle quelle au tableau.

`urgenceLimit` : euros TTC, saisie libre, placeholder 150.

`extrasFacturables` : grille sans catégorie, aucun coché par défaut. Chaque
entrée cochée produit la chaîne `"<libellé> : <prix> € <unité>"` si un prix
est saisi, sinon le libellé seul.
Libellés et unités disponibles :
  Ménage (par_prestation, par_heure, par_nuit, par_m2)
  Linge (par_prestation, par_nuit, par_personne)
  Check-in tardif (par_prestation, par_heure)
  Maintenance (par_prestation, par_heure)
  Déplacement exceptionnel (par_prestation, par_km)
  Shooting photo (par_prestation)
  Urgence WE / jour férié (par_prestation, par_heure)
  Gestion de sinistre (par_prestation, par_heure)
Extras libres : unités par_prestation, par_heure, par_nuit.

### 3 — Honoraires

`remuType` — cinq cartes, aucune sélectionnée au départ :
  commission → % sur revenus
  forfait_mensuel → Forfait mensuel
  forfait_resa → Par réservation
  mixte → Mixte
  carte → À la carte
Les champs dépendants n'apparaissent qu'après le clic :
  commission → commissionRate (%, step 0.5, 0–100), commissionBase
  forfait_mensuel → forfaitMensuel (€/mois, placeholder 200)
  forfait_resa → forfaitResa (€/réservation, placeholder 50)
  mixte → mixteRate (%, placeholder 8), mixteForfait (€/mois, placeholder 100)

`commissionBase` : ht (Sur revenus HT) · ttc (Sur revenus TTC). Défaut : ht.
`tva` : franchise (Auto-entrepreneur, sans TVA) · ht (HT — TVA en sus) ·
        ttc (TTC toutes taxes comprises). Défaut : franchise.
`tarifPreavis` : 30 · 60 (défaut) · 90 jours.
`reversement` : par_resa (À chaque réservation) · hebdo (Hebdomadaire) ·
        mensuel (défaut) · encaissement_direct (Encaissement direct par le
        propriétaire).

### 4 — Conditions

`dureeType` : indeterminee (défaut) · determinee.
Si determinee, afficher dateDebut, dureeMois (3 · 6 · 12 · 24) et
`renouvellement` : tacite (défaut) · expres.

`preavis` : 0 (Aucun préavis) · 15 · 30 (défaut) · 60 · 90 jours.
`exclusivite` : non (Sans exclusivité, défaut) · totale · partielle
        (Exclusivité partielle, sur les plateformes).
`respPlafond` : oui (Oui — limitée aux honoraires perçus, défaut) ·
        non (Non — responsabilité de droit commun).
`juridiction` : domicile_defendeur · lieu_bien (défaut) · commerce
        (Tribunal de commerce, si 2 sociétés).
`confidentialite` : 2 · 5 ans (défaut).
`clausesPersonnalisees` : liste libre.

### 5 — Signature
Récapitulatif : les trois chiffres qui engagent (commission, durée,
préavis) en tête, comme sur la maquette 9a, puis le reste replié.
Zone de signature : voir `08-proprietaires-contrats.md` — feuille modale,
fond `#FFF` opaque, seule exception au verre de toute l'app.
`signatureData` en `data:image/png;base64,...` (préfixe vérifié par le
serveur, sinon la signature est silencieusement ignorée).
`signatureDate` en ISO.
Bouton « Signer et envoyer », inactif tant que rien n'est tracé.
Sous le bouton : « Un lien de signature partira à <ownerEmail>. Il verra ta
signature déjà apposée et signera à son tour. »

## Après l'envoi

`POST /api/mandat/send` renvoie { success, message, contractId }.
Retour à la liste Contrats, le nouveau mandat en tête, état « en attente ».

## À noter

Le serveur ne valide que trois champs. Tout le reste est stocké tel quel
dans `contract_data` — un champ omis est simplement absent du snapshot,
il n'y a pas de piège d'effacement ici.

`clientId` doit être envoyé pour que le mandat se rattache au propriétaire
et alimente la pastille de la liste.

## Format du payload

⚠️ TOUS les champs numériques partent en CHAÎNES, jamais en nombres.
Le web fait `el.value.trim()` sans conversion (contrat.html:2916), et le
serveur stocke le JSONB tel quel. Envoyer un Int ou un Double depuis Swift
produirait un `contract_data` de forme différente de celui du web, pour le
même mandat.
Concerne : preavis, tarifPreavis, confidentialite, dureeMois, urgenceLimit,
commissionRate, forfaitMensuel, forfaitResa, mixteRate, mixteForfait.
