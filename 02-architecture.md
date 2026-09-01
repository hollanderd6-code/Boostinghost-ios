# Architecture de l'app

## Cible

iOS 26.0 minimum. Swift 6, SwiftUI. Aucune dépendance externe : `URLSession`, `Security` (Keychain), `LocalAuthentication`, `PDFKit`.

## Structure du projet

```
Boostinghost/
  BoostinghostApp.swift        point d'entrée, choix Login / MainTabView
  Core/
    APIClient.swift            URLSession, Bearer, décodage, erreurs
    AuthStore.swift            @Observable — session, permissions, déconnexion
    KeychainStore.swift        lecture/écriture du jeton
    Endpoints.swift            URLs typées
    Formatters.swift           montants, heures, dates
  Design/
    Palette.swift              les couleurs de 01-design-tokens
    Materials.swift            GlassChrome, GlassCard, arête spéculaire
    Typography.swift           styles nommés
    Components/
      GlassNavBar.swift        barre haute : sur-titre + grand titre + actions
      GlassTabBar.swift        barre flottante, construite depuis les droits
      SegmentedGlass.swift     sélecteur de vue (Planning/Revenus, filtres)
      ListCard.swift           carte de contenu, lignes + séparateurs
      StatusPill.swift          pastille d'état
      SectionLabel.swift       intertitre capitales
  Features/
    Auth/                      01-connexion
    Today/                     02-aujourdhui
    Calendar/                  03-calendrier (Planning + Revenus)
    Messages/                  04-messages
    Manage/
      ManageHub/               05-gestion-hub
      Properties/              06-logements (liste + fiche 9 blocs)
      Cleaning/                07-menage
      Owners/                  08-proprietaires-contrats (+ signature)
      Stays/                   09-sejours
    Account/                   10-mon-compte
  Models/                      Conversation, Property, Reservation, Report…
```

Un dossier par écran, avec sa `View`, son `ViewModel` (`@Observable`) et ses sous-vues. Pas de vue partagée entre features autre que `Design/Components`.

## Authentification

1. Au lancement, `KeychainStore` cherche le jeton.
2. Absent → écran de connexion. Présent → `MainTabView`, et une requête de contrôle en tâche de fond.
3. `POST /api/auth/token` (T1) renvoie jeton, `is_sub_account` et `permissions`. Le jeton va au Keychain avec `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, le reste dans `AuthStore`.
4. Toute requête porte `Authorization: Bearer <token>`.
5. Un `401` vide le Keychain et ramène à la connexion, sans alerte : l'écran de connexion est le message.
6. Face ID / Touch ID protège la relecture du jeton à partir de la seconde ouverture (`LocalAuthentication`). Un échec biométrique ne déconnecte pas, il redemande le mot de passe.

## Barre d'onglets dérivée des droits

Un compte principal voit les quatre onglets. Un sous-compte ne voit que ceux dont il a le droit :

```
Aujourd'hui  can_view_reservations   (cf. T5)
Calendrier   can_view_reservations
Messages     can_view_messages
Gestion      can_view_properties | can_view_cleaning | can_view_owners | can_view_invoices
```

Gestion n'affiche que les entrées autorisées ; si une seule l'est, le tap ouvre directement le sous-écran au lieu du sommaire.

**Sous trois onglets, pas de barre d'onglets.** Une intervenante ménage n'ayant que `can_view_cleaning` arrive directement sur l'écran Ménage. Une barre à un seul onglet est un bouton inutile en bas de l'écran.

**Le rond aux initiales se vide pour un sous-compte.** `sub-account-guard.js` ferme `settings-account.html` et `help.html` à tous les sous-comptes (`BLOCKED_PAGES`). La feuille Mon compte se réduit alors au nom et à « Se déconnecter ».

L'édition suit le même principe : `can_send_messages`, `can_edit_properties`, `can_manage_cleaning`, `can_manage_deposits`, `can_manage_smart_locks`. Un droit de lecture sans droit d'écriture masque les boutons d'action, il ne les désactive pas.

## Mode agence

Le web ajoute `?agency=all` aux appels quand `bh_agency_view` vaut `all`, et le compte peut basculer sur un compte délégué. `À TRANCHER` : est-ce que la version 1 embarque le mode agence, ou seulement le compte propre ? Le mode agence bloque aussi Mon compte et le support côté web.

## Réseau

Base : `https://lcc-booking-manager.onrender.com`

Un seul `APIClient` `actor`. Décodage `Codable` avec `convertFromSnakeCase`. Les montants arrivent parfois en chaîne : les décoder en `Double?` tolérant (le serveur fait déjà `parseFloat` sur certaines routes, pas toutes).

Pas de cache disque en version 1. Rafraîchissement au `pull-to-refresh` et au retour au premier plan.

`À TRANCHER` : Socket.io alimente le temps réel côté web (`new_message`, `messages_read`). En version 1, un rafraîchissement à l'ouverture de l'onglet Messages suffit-il, ou faut-il le direct ?

## Notifications

`services/notifications-service.js` envoie déjà du Firebase, et `push-notifications-handler.js` route les types vers les pages web. La correspondance à reprendre :

```
new_message  → Messages, conversation ciblée
cleaning     → Ménage, checklist ciblée
deposits     → Séjours
invoices     → Propriétaires
défaut       → Aujourd'hui
```

`À TRANCHER` : APNs direct ou Firebase, sachant que le serveur parle déjà Firebase.
