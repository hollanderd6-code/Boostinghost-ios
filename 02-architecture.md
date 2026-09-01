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

**Voir `05-auth-implementation.md`** — les routes existent toutes, il n'y a rien à construire côté serveur. En résumé :

1. Deux appels en séquence à la connexion : `/api/auth/login`, puis `/api/sub-accounts/login` en cas d'échec. Les permissions arrivent dans la seconde réponse.
2. `POST /api/auth/refresh-faceid` juste après, pour obtenir un jeton de 90 jours au lieu de 7. C'est celui-là qu'on garde au Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`).
3. Toute requête porte `Authorization: Bearer <token>`.
4. Au lancement : `GET /api/auth/verify`. **Ne purger le Keychain que sur un 401** — un 404, un 5xx ou un démarrage à froid de Render ne doit pas déconnecter une session valide.
5. Face ID **avant** d'entrer, jamais après. Un échec biométrique ne déconnecte pas, il redemande le mot de passe.

## Barre d'onglets dérivée des droits

Un compte principal voit les quatre onglets. Un sous-compte ne voit que ceux dont il a le droit :

Les clés à tester sont les **noms de colonnes**, tels qu'ils arrivent dans `subAccount.permissions` — pas les alias du front (voir T5) :

```
Aujourd'hui  can_view_calendar
Calendrier   can_view_calendar
Messages     can_view_messages
Gestion      can_view_properties | can_view_cleaning | can_view_owners | can_view_invoices
```

Le jeu complet des colonnes existantes, relevé dans `permissionMapping` :

```
can_view_calendar        can_view_messages        can_send_messages
can_delete_messages      can_view_cleaning        can_assign_cleaning
can_view_properties      can_edit_properties      can_delete_properties
can_view_deposits        can_manage_deposits      can_view_invoices
can_manage_invoices      can_view_payments        can_manage_payments
can_view_pricing         can_manage_pricing       can_view_reporting
can_view_debours         can_manage_debours       can_view_smart_locks
can_manage_smart_locks   can_view_welcome_book    can_view_templates
can_manage_templates     can_view_contracts
```

Un compte principal n'a **pas** d'objet de permissions : `permissions == nil` signifie tout autorisé. Ne pas confondre avec un objet vide, qui signifierait l'inverse.

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
