# Boostinghost iOS

App iOS native pour la conciergerie Boostinghost. Consomme l'API du dépôt
`hollanderd6-code/lcc-booking-manager` en HTTPS. Aucun code partagé avec lui.

Base API : `https://lcc-booking-manager.onrender.com`

## État du dépôt

Pas encore de code. Ce dépôt contient un paquet de conception à lire **avant**
d'écrire quoi que ce soit :

| Fichier | Contenu |
| --- | --- |
| `README.md` | index, décisions déjà prises, ordre de travail |
| `00-backend-tickets.md` | tickets serveur ; T1 et T5 annulés, T2 écrit |
| `01-design-tokens.md` | couleurs, type, matériaux Liquid Glass, symboles SF |
| `02-architecture.md` | structure Xcode, auth, barre d'onglets dérivée des droits |
| `03-api-contracts.md` | routes du cœur : auth, messages, reporting, logements |
| `04-routes-relevees.md` | routes Séjours, Propriétaires, Contrats, Ménage |
| `05-auth-implementation.md` | connexion, Keychain, Face ID |
| `06-ticket-T2.md` | la route du jour et les trois causes du bug des arrivées |
| `screens/01..10` | une spec par écran, dans l'ordre d'usage |

`T2-aujourdhui-routes.js` est du code **Node destiné au dépôt backend**. Il ne
fait pas partie de l'app iOS et ne doit pas être modifié ici.

## Cible technique

iOS 26.0 minimum, Swift 6, SwiftUI. **Aucune dépendance externe** : `URLSession`,
`Security` (Keychain), `LocalAuthentication`, `PDFKit`. Pas de SPM, pas de
CocoaPods.

iOS 26 est un choix arrêté, pas une valeur par défaut : Liquid Glass l'exige.
Ne pas proposer de fallback pour iOS 18.

## Règles de travail

**Les valeurs de `01-design-tokens.md` sont normatives.** Hex, tailles, rayons,
flous, saturations, opacités : les reprendre exactement. Ne pas arrondir, ne pas
« harmoniser », ne pas remplacer par des constantes système qui paraissent
proches.

**Le gris le plus clair autorisé pour du texte est `#5E6B63`.** Jamais plus
clair, quelle que soit la taille ou le poids. Trois gris ont déjà été retirés des
maquettes pour cause de contraste insuffisant ; ne pas les réintroduire.

**Verre pour le chrome, opaque pour le contenu.** Barres de navigation, barres
d'onglets, feuilles et barres d'action en verre. Cartes de liste quasi opaques.
Une seule exception dans toute l'app : la zone de signature, blanc plein.

**Ne jamais inventer un nom de champ, de route ou de colonne.** Là où un fichier
porte `À TRANCHER`, demander. Les contrats d'API ont été relevés dans le code du
backend, pas devinés ; toute addition doit l'être aussi.

**Un écran à la fois.** S'arrêter après chaque écran pour validation. Ne pas
enchaîner sur le suivant sans accord.

## Périmètre des données : Gestion vs Facturation

**Les données de l'écran Gestion suivent le périmètre agence (`agency=all`)** :
ménage, séjours/cautions, logements/groupes. Ces chiffres couvrent tous les
logements gérés par le compte, y compris ceux des délégants.

**Les données de facturation suivent le compte propre (sans `agency=all`)** :
`GET /api/subscription/status` ne reçoit pas `agency=all`. Pour un compte
agence, `propertiesUsed` vaut 0 même si 26 logements sont gérés — c'est juste
(aucun logement en propre) mais incompréhensible en contexte agence. La règle :
n'afficher le quota `propertiesUsed / propertiesLimit` que si `propertiesUsed > 0`.

## Pièges connus, déjà rencontrés

Le backend **mélange camelCase et snake_case** dans ses réponses. Le front web
fait systématiquement `property.basePrice ?? property.base_price`. Les décodeurs
doivent accepter les deux formes.

L'identifiant d'un logement est **`_id` ou `id`** selon les enregistrements.

`amenities`, `houseRules` et `practicalInfo` arrivent **soit en objet, soit en
chaîne JSON**. Décoder de façon tolérante.

L'écriture de la fiche logement est en **`multipart/form-data`**, pas en JSON,
avec des clés camelCase.

Au démarrage, ne purger le jeton du Keychain **que sur un 401**. Le serveur est
sur Render : un 404, un 5xx ou un démarrage à froid ne doit pas déconnecter une
session valide.

Les permissions d'un sous-compte arrivent sous leurs **noms de colonnes**
(`can_view_calendar`), pas sous les alias du front (`can_view_reservations`).
Un compte principal n'a pas d'objet de permissions : `nil` signifie tout
autorisé, à ne pas confondre avec un objet vide.

Répondre à un voyageur Airbnb ou Booking passe par
`POST /api/chat/conversations/:id/send-platform`, **pas** par `/api/chat/send`.

## Langue

Interface en français. Pas d'anglicismes dans les libellés visibles.
Heures au format `16 h`, `9 h 41`. Montants `42 380 €`, espace insécable, zéro
décimale. Dates en minuscules : `mardi 1 septembre`.

Commentaires et noms de symboles en anglais, comme d'usage en Swift.
