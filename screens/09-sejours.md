# 09 — Séjours

Maquette : `8a`. Sources : `deposits.html` (cautions, Stripe), `factures.html`.

L'argent des voyageurs : empreintes de caution et factures de séjour. À ne pas mélanger avec Propriétaires — ce sont deux mondes comptables distincts, et c'est leur mélange qui a fait de `clients.html` une page de 315 Ko.

## Structure

**Barre de navigation** : sur-titre « 1 à restituer · 2 factures à envoyer », grand titre « Séjours ». En pied : segmenté « Cautions · 4 » / « Factures · 2 ».

1. **Total des empreintes** — carte héro : « EMPREINTES EN COURS », montant 32/semibold, « sur N séjours · aucune retenue ce mois ».
2. **Une caution à restituer** — carte terracotta avec filet vertical. Nom du voyageur 18/semibold, « logement · partie hier 11 h », montant à droite. Ligne d'état : « À restituer — délai dépassé de 1 jour ». Deux actions : « Restituer » en vert plein, « Retenir » en verre.
   Une caution n'a qu'un moment critique — le départ passé, quand il faut décider. **C'est la seule ligne qui porte des boutons.**
3. **Les empreintes en cours** — carte de lignes calmes : nom, « logement · départ le N », montant et « empreinte prise » en `#1F6B4C` alignés à droite.
4. **« FACTURES VOYAGEURS »** — brouillons avec bouton « Envoyer », puis « Toutes les factures » avec le total.

Le délai de restitution vient du logement (`deposit_release_days`). « Délai dépassé » se calcule à partir de la date de départ plus ce délai — pas d'une valeur fixe.

Routes : **`04-routes-relevees.md`, section 2.** « Restituer » = `POST /api/deposits/:id/release`, « Retenir » = `POST /api/deposits/:id/capture`. Le vocabulaire technique du code (capture / release) ne doit pas apparaître à l'écran.
