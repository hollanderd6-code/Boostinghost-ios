# Authentification — rien à construire côté serveur

Relevé le 1er septembre 2026 dans `public/login.html`, `public/js/auth-manager.js` et `sub-accounts-middleware.js`.

**Le ticket T1 est annulé.** La route à jeton que je proposais existe déjà, et l'app web Capacitor fait déjà exactement ce dont l'app iOS a besoin — Face ID compris. Il n'y a pas une ligne de Node à écrire.

---

## Les routes qui existent

```
POST /api/auth/login              { email, password }  → { token, user, redirect? }
POST /api/sub-accounts/login      { email, password }  → { token, subAccount }
GET  /api/auth/verify             Bearer               → 200 | 401
POST /api/auth/refresh-faceid     Bearer               → { token }   jeton 90 jours
POST /api/auth/magic-link         { email }            → 200
GET  /api/auth/magic-link/verify?token=…               → { token, user }
```

Le jeton est un JWT signé avec `process.env.JWT_SECRET`, vérifié par `authenticateAny` (`sub-accounts-middleware.js`). Un jeton de sous-compte porte `{ subAccountId, type: 'sub_account' }` ; un jeton de compte principal porte l'objet utilisateur.

**Deux durées de vie**, et c'est important : le jeton de connexion vaut environ **7 jours**, celui de `refresh-faceid` vaut **90 jours**. Le second est fait pour la reconnexion biométrique — c'est celui que l'app doit garder au Keychain.

---

## Le flux réel, à reproduire tel quel

`login.html` essaie les deux comptes en séquence, car l'utilisateur ne sait pas s'il est un compte principal ou un sous-compte :

1. `POST /api/auth/login`. Si `res.ok && data.token` → compte principal. `data.user` contient le profil.
2. Sinon `POST /api/sub-accounts/login`. Si `res.ok && data.token` → sous-compte. **`data.subAccount.permissions`** contient les droits — c'est ce que `sub-account-guard.js` lit ensuite (`subData.permissions`).
3. Les deux échouent → afficher l'erreur du second appel, sinon celle du premier, sinon « Email ou mot de passe incorrect. »
4. Après succès : `POST /api/auth/refresh-faceid` avec le jeton fraîchement obtenu, et garder le jeton 90 jours qu'il renvoie. Si l'appel échoue, garder le jeton de connexion.

**Les permissions arrivent donc dans la réponse de connexion.** Aucun second appel n'est nécessaire pour construire la barre d'onglets — ce que je réclamais dans T1 est déjà là, simplement sous un autre nom.

---

## Ce que l'app doit faire

```swift
struct Session {
    let token: String          // jeton 90 j si refresh-faceid a répondu, sinon 7 j
    let isSubAccount: Bool
    let permissions: [String: Bool]?   // nil pour un compte principal = tout autorisé
    let displayName: String
}

func signIn(email: String, password: String) async throws -> Session {
    // 1 — compte principal
    if let main: MainLogin = try? await api.post("/api/auth/login", ["email": email, "password": password]) {
        let token = await refreshedToken(main.token)
        return Session(token: token, isSubAccount: false, permissions: nil, displayName: main.user.name)
    }
    // 2 — sous-compte
    let sub: SubLogin = try await api.post("/api/sub-accounts/login", ["email": email, "password": password])
    let token = await refreshedToken(sub.token)
    return Session(token: token, isSubAccount: true,
                   permissions: sub.subAccount.permissions,
                   displayName: sub.subAccount.name)
}

// Le jeton 90 j vaut mieux que celui de 7 j pour la reconnexion Face ID.
func refreshedToken(_ token: String) async -> String {
    (try? await api.post("/api/auth/refresh-faceid", auth: token).token) ?? token
}
```

### Au lancement

```
Keychain vide                       → écran de connexion
Keychain rempli                     → GET /api/auth/verify
  200                               → MainTabView
  401                               → purger le Keychain, écran de connexion
  404 / 5xx / réseau indisponible   → NE PAS purger, entrer quand même
```

Ce dernier point vient du code web, commentaire à l'appui : « Un 404 / 5xx / cold-start ne doit pas déconnecter une session valide. » Le serveur est sur Render et démarre à froid. **Purger le jeton sur autre chose qu'un 401 déconnecte l'utilisateur pour rien.**

### Face ID

L'app native actuelle vérifie la biométrie **avant** d'entrer, jamais après. À reprendre : `LAContext` d'abord, puis lecture du jeton, puis `verify`.

Un cas traité par le web et à ne pas oublier : si le jeton biométrique est expiré, la biométrie réussit mais `verify` répond 401. Il faut alors effacer le jeton, masquer le bouton Face ID, et afficher « Votre session a expiré. Reconnectez-vous pour réactiver Face ID. » — pas une erreur générique.

### Keychain plutôt que Preferences

Le web utilise `Capacitor Preferences`. En natif, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` est le bon niveau : le jeton ne quitte pas l'appareil et ne part pas dans les sauvegardes iCloud.

---

## Lien de connexion par mail

`POST /api/auth/magic-link` puis `GET /api/auth/magic-link/verify?token=…`. Le web l'offre sous « Recevoir un lien de connexion par email ».

`À TRANCHER` : l'app iOS le propose-t-elle ? Cela implique de gérer un lien universel qui rouvre l'app avec le jeton. Utile si tu oublies souvent ton mot de passe, superflu sinon — la maquette `8b` ne le montre pas.
