# 04 — Messages

Maquette : `3a`. Route : `GET /api/chat/conversations`, plus T3 pour le brouillon.

## Structure

**Barre de navigation en verre** :
- sur-titre : « 3 non lus · 2 à reprendre » — les deux chiffres qui demandent quelque chose ;
- grand titre : « Messages » ;
- à droite : recherche et rond d'initiales ;
- en pied : **trois filtres** en verre — « Tous », « Non lus · N », « À reprendre · N ». Le troisième prend le fond or `rgba(251,243,226,.85)` et le texte `#8A5B14`.

Correspondance des filtres, sans invention :
```
Tous           tout
Non lus        unread_count > 0
À reprendre    escalated == true
```
« À reprendre » signifie que l'assistant n'a pas su répondre et a passé la main. C'est déjà ce qui déclenche la notification propriétaire côté serveur.

## Ligne de conversation

Carte rayon 22, padding 15/16. À l'intérieur, une rangée :

- **Rond d'initiales** 46×46. Fond `#DCE8E1` / texte `#0E3B2E` par défaut ; fond `#FBEAE4` / texte `#A8452A` si la conversation est escaladée.
- **Colonne** :
  - rangée haute : nom 16.5/semibold, horodatage 12.5, et un point ø9 si non lu — `#A8452A` si escaladée, `#0E3B2E` sinon ;
  - ligne de contexte 12.5 : « logement · arrive aujourd'hui 16 h · Booking » ;
  - extrait sur deux lignes maximum, 14, `#3E4A44`. Un message de l'hôte est préfixé « Vous : » ;
  - **pastille** si `escalated` : `sparkles` + « L'IA a passé la main », fond or, texte `#8A5B14`.

Une conversation lue s'atténue : carte `rgba(255,255,255,.50)`, nom en 500 et `#3E4A44`, extrait en gris atténué. Pas de point.

Si `ai_disabled`, ajouter un marqueur discret « IA en pause » — l'hôte doit savoir qu'aucune réponse automatique ne partira.

## Comportement

- Tap → fil de conversation. `POST /api/chat/mark-read/:id` à l'ouverture.
- Un tap sur la pastille ouvre le fil **avec le brouillon déjà dans le champ de saisie**, modifiable. C'est ce que T3 rend possible ; sans T3, la pastille ouvre le fil sans brouillon.
- Tri : `last_message_time` décroissant. Les escaladées ne remontent pas artificiellement — le filtre est là pour ça.
