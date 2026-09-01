# 07 — Ménage

Maquette : `7a`. Sources : `cleaning.html`, `cleaning-tasks.html`, `historique-menage.html`.

## Le parti pris

Un ménage se mesure en **créneau**, pas en tâche : entre le départ et l'arrivée suivante. C'est la seule information qui dit s'il est en retard. Une liste de tâches sans créneau ne permet pas de décider quoi faire d'abord.

## Structure

**Barre de navigation** : `chevron.left`, sur-titre « 2 aujourd'hui · 1 à valider », grand titre « Ménage », rond vert `plus`. En pied : segmenté Aujourd'hui / Semaine / Historique.

1. **Un ménage serré** — carte terracotta, filet vertical 4px, badge « SERRÉ ». Logement 18/semibold, « groupe · intervenante ». Puis la **jauge de créneau** : heure de départ, barre 6px, heure d'arrivée. La barre se remplit selon l'avancement, en `#A8452A` quand le créneau est entamé sans avoir commencé. Ligne d'état en `#A8452A`/semibold : « Pas commencé · 6 h de créneau ». Deux actions : « Appeler Camila » en vert plein, « Checklist » en verre.
2. **Un ménage large** — même carte, sans filet ni couleur, badge vert « LARGE ». Jauge en `#2E8B62`, borne droite « demain » quand aucune arrivée ne suit. État en gris : « En cours · aucune arrivée avant demain 15 h ».
3. **« À VALIDER »** — ménages terminés avec photos : logement, « Terminé hier 14 h 20 · 6 photos », bouton « Valider ».
4. **« INTERVENANTS »** — une ligne par personne : rond d'initiale, nom, « assignée par défaut · sous-compte actif ». Puis « Envoyer le récap du jour », `message`.

Le classement est celui du risque : serré d'abord, large ensuite, à valider après. Pas l'ordre alphabétique ni l'ordre des identifiants.

## Côté intervenant

Deux voies, déjà en place : un **récap par SMS**, ou un **sous-compte dédié** avec `can_view_cleaning`, ou les deux. Un sous-compte n'ayant que ce droit n'a pas de barre d'onglets : il arrive directement sur cet écran, sans les sections Intervenants ni « Envoyer le récap ».

L'assignation automatique existe déjà côté serveur : la personne de ménage régulière du logement est affectée à chaque nouveau ménage. L'app ne fait que l'afficher, avec la possibilité de la changer ponctuellement.
