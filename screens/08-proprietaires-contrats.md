# 08 — Propriétaires, contrats et signature

Maquettes : `7b` (liste), `9a` (contrat), `9b` (signature).
Sources : `clients.html`, `contrat.html`, `signer-contrat.html`, `factures-proprietaires.html`.

Quatre anciennes pages réunies. Un client d'abord, ses documents ensuite — au lieu de cinq onglets côte à côte.

**Les noms des maquettes sont des exemples.** Aucun vrai client n'a été relevé.

## Liste

**Barre de navigation** : sur-titre « 4 clients · 26 logements », grand titre « Propriétaires », rond vert `plus`.

1. **Alerte de signature** — carte or, `signature` : « 1 contrat en attente de signature », « Envoyé il y a 4 jours ». C'est la seule chose de cet écran qui bloque quelqu'un d'autre, donc elle est en tête.
2. **Les clients** — une carte de lignes : rond d'initiales 42×42, nom 16/semibold, « N logements · zones ». Une pastille or à droite quand quelque chose attend : « facture à envoyer », « contrat non signé ». Rien si tout est en ordre.
3. **« DOCUMENTS »** — quatre lignes transversales : Contrats (« 1 en attente »), Factures propriétaires (« 1 brouillon »), Attestation fiscale, Débours.

## Contrat

**Barre de navigation** : sur-titre « Envoyé il y a 4 jours · non signé », grand titre « Contrat », `square.and.arrow.up` à droite.

1. **Carte du client** — initiales, nom, logements.
2. **Trois chiffres qui engagent**, sortis du corps du texte : commission (en `#0E3B2E`), durée, préavis. Trois blocs `flex: 1` centrés, rayon 18.
3. **Le contrat** — carte rayon 22 sur fond `rgba(255,255,255,.72)`, titre centré en capitales, filet, puis les articles : intertitre 12/bold +0.08em et corps 14.5 `line-height 1.6`. Les articles secondaires sont résumés en une ligne en italique.
4. **Barre d'action basse en verre**, ancrée : bouton « Signer » pleine largeur, et sous lui « Le PDF signé part par mail à Hélène et à toi » en 12.5.

On ne signe pas ce qu'on n'a pas pu lire : le contrat complet reste accessible, ce sont seulement les trois chiffres qui remontent.

## Signature — attention au sens

**C'est la conciergerie qui signe la première**, à la préparation du contrat. Le propriétaire reçoit ensuite un lien par mail et signe depuis son propre téléphone, sur `signer-contrat.html`, où il voit la signature de la conciergerie déjà apposée.

L'app n'héberge donc **que ta signature**. Un contrat déjà envoyé (`status: sent`) n'offre que trois actions : voir le PDF, renvoyer le lien, attendre.

Feuille modale, l'écran du contrat reste visible derrière le verre.

- **Poignée** 38×5, puis « Votre signature » 27/bold et « Annuler » en vert.
- Une phrase : « Signez dans le cadre avec le doigt. Vous pourrez recommencer autant que nécessaire. »
- **Zone de tracé** — hauteur 230, rayon 20, **fond `#FFF` opaque**, bordure `rgba(20,32,27,.10)`, ombre interne. C'est la seule exception au verre de toute l'app : il faut voir le trait franchement. Une ligne de base `rgba(20,32,27,.13)` à 62 du bas, et le nom du signataire en 11.5 gris sous la ligne.
- Sous la zone : « Effacer » avec `arrow.uturn.backward`, et l'horodatage à droite.
- **Bloc mail** : « Un lien de signature partira à <adresse>. Elle verra ta signature déjà apposée et signera à son tour. »
- Bouton « Signer et envoyer », vert plein, inactif tant que rien n'est tracé.

### Implémentation

`Canvas` SwiftUI, points du doigt lissés, export `data:image/png;base64` — **le même format que `cleaning-tasks.html` produit déjà** (`canvas.toDataURL('image/png')`), donc rien à changer côté serveur. Envoi dans `signatureData`, avec `signatureDate` en ISO, à `POST /api/mandat/send` (mandat de gestion) ou `POST /api/contrat/send` (contrat de location). L'IP est enregistrée par le serveur à des fins de preuve. **Aucun PDF généré par l'app.**

Routes et flux exact : **`04-routes-relevees.md`, section 3.**
