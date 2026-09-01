# 01 — Connexion

Maquette : `8b`. Route : T1.

## Structure

Pas de barre de navigation, pas de barre d'onglets. Contenu centré verticalement, marge horizontale 26.

1. **Marque** — carré 66×66, rayon 20, `#0E3B2E`, « B » 30/bold blanc, ombre `0 12px 30px rgba(14,59,46,.32)`. Sous le carré : « Boostinghost » 27/bold et « Gérez vos logements depuis votre poche » 14.5 en gris atténué. Espace de 34 avant la carte.
2. **Carte en verre** — rayon 28, padding 22, verre franc (voir matériaux). Contient :
   - libellé « ADRESSE E-MAIL » 11.5/bold +0.09em, puis champ rayon 15, fond `rgba(255,255,255,.78)`, ombre interne `inset 0 1px 3px rgba(20,32,27,.05)`, texte 16 ;
   - libellé « MOT DE PASSE », même champ, texte masqué 18 avec interlettrage 0.16em, plus `eye.slash` à droite ;
   - bouton « Se connecter » pleine largeur, `#0E3B2E`, rayon 16, padding vertical 16, 16.5/semibold blanc ;
   - « Utiliser Face ID » en ligne, `faceid` + texte 15.5/semibold vert, centré, marge haute 15.
3. **« Mot de passe oublié ? »** 15/semibold vert, centré, 22 sous la carte.
4. **Pied** — « Boostinghost 3.2 · CGU · Confidentialité » 12.5 gris atténué, ancré en bas à 26.

Les halos de fond sont plus larges qu'ailleurs (ø400 / ø380) : l'écran est vide, le verre a besoin de matière.

## Comportement

- Le bouton reste inactif tant que les deux champs ne sont pas remplis ; il ne montre pas d'erreur avant le premier envoi.
- Pendant l'appel, le libellé du bouton devient un indicateur d'activité — pas de superposition modale.
- `401` → message sous la carte, en `#A8452A` 13.5, et le champ mot de passe se vide. Pas d'alerte système.
- Réseau indisponible → « Pas de connexion » au même endroit, le mot de passe est conservé.
- « Utiliser Face ID » n'apparaît qu'à partir de la seconde ouverture, quand un jeton existe au Keychain.
- Succès : jeton au Keychain, `AuthStore` rempli, transition vers `MainTabView` en fondu.

Un sous-compte utilise le même écran. C'est le `permissions` de la réponse qui décide ensuite de la barre d'onglets.
