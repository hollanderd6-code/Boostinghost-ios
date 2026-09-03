# Boostinghost iOS — paquet de handoff

Dépôt : `hollanderd6-code/Boostinghost-ios`
Backend : `hollanderd6-code/lcc-booking-manager` (branche `main`) — inchangé, consommé en HTTPS.
Maquettes : `App iOS - Aujourd'hui.dc.html` (10 écrans, ids 1a → 9b) et `Architecture iOS.dc.html`.

## Décisions déjà prises — ne pas les rouvrir

- **iOS 26 minimum, sans fallback.** Liquid Glass exige A13+ (iPhone 11 / SE 2 et plus récents). Pas de second jeu de composants.
- **SF Pro et SF Symbols.** Les maquettes utilisent Material Symbols comme substituts ; la correspondance est dans `01-design-tokens.md`.
- **Quatre onglets** : Aujourd'hui, Calendrier, Messages, Gestion. Pas de « Plus ».
- **Mon compte** est une feuille modale ouverte par le rond aux initiales, pas un onglet.
- **Le verre pour le chrome, l'opaque pour le contenu.** Barres, feuilles et boutons flottants en verre ; cartes de liste quasi opaques. Une exception assumée : la zone de signature est blanc opaque.
- **Réservations + Revenus fusionnent** dans l'onglet Calendrier, deux vues.
- **Le livret d'accueil n'est plus un formulaire** : c'est une vue de trois blocs de la fiche logement.
- **La barre d'onglets se construit à partir des droits**, sur le modèle de la carte page → permission de `public/js/bh-layout.js` (lignes 162-174).

## Ordre de travail

1. `00-backend-tickets.md` — les tickets serveur. T1 et T5 étaient des faux problèmes. **T2 est écrit** : `T2-aujourdhui-routes.js` + `06-ticket-T2.md`. Restent T3 et T4, tous deux petits.
2. `01-design-tokens.md` — couleurs, type, matériaux, symboles, contraste.
3. `02-architecture.md` — structure Xcode, auth, Keychain, barre dérivée des droits.
4. `03-api-contracts.md` — les routes du cœur de l'app (auth, messages, reporting, logements).
5. `04-routes-relevees.md` — les routes des écrans Séjours, Propriétaires, Contrats et Ménage, plus l'écriture de la fiche logement. **Contient une correction importante : le sens de la signature de contrat.**
6. `05-auth-implementation.md` — la connexion, le Keychain et Face ID. Tout existe côté serveur.
7. `06-ticket-T2.md` + `T2-aujourdhui-routes.js` — la route du jour, code compris. **Va dans le dépôt backend, pas ici.**
8. `07-ticket-changer-de-compte.md` — modale sélecteur de compte ; mécanisme des comptes délégants individuels **à relever dans `server.js` avant de spécifier l'écran**.
9. `screens/` — un fichier par écran, dans l'ordre d'usage.

## Règle de fidélité

Les valeurs des maquettes (hex, tailles, rayons, espacements) sont normatives. Là où une maquette et ce document divergent, ce document gagne : il a été relu après coup.

Ce qui n'est **pas** décidé est marqué `À TRANCHER` dans le fichier concerné. Ne pas inventer de réponse.
