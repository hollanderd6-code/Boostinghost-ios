# Jetons de design

## Couleurs

### Fond
```
Dégradé d'écran   linear 168°  #F5F2EA → #EBE7DC (46%) → #E2DDD0
```
Sous le dégradé, trois halos flous donnent au verre quelque chose à réfracter. **Sans eux le verre retombe en gris translucide** — ils ne sont pas décoratifs.
```
vert       radial rgba(46,139,98,.42)   ø320  haut-droite, blur 18
terracotta radial rgba(168,69,42,.30)   ø330  bas-gauche,  blur 20
vert bas   radial rgba(46,139,98,.34)   ø280  sous la barre d'onglets, blur 20
or         radial rgba(201,161,91,.30)  ø240  milieu-droite, blur 22
```

### Texte
```
Encre          #14201B   titres, valeurs, libellés de ligne
Encre douce    #2C3A33   libellés de bouton secondaire
Corps          #3E4A44   extraits de message
Atténué        #5E6B63   sous-titres, métadonnées, unités
```
**`#5E6B63` est le gris le plus clair autorisé pour du texte** sur le verre clair (4,86:1). Rien de plus clair, quelle que soit la taille. Trois gris ont été retirés des maquettes pour cette raison (#8B958E 2,69:1, #79837B 3,42:1, #6E7A72 3,90:1).

### Marque et états
```
Vert          #0E3B2E   primaire, boutons pleins, onglet actif
Vert clair    #8FD3B4   accent sur fond sombre
Occupé        #2E8B62   points de calendrier, jauges
Occupé foncé  #1F6B4C   texte sur pastille verte
Menthe fond   rgba(46,139,98,.13)
Terracotta    #A8452A   urgence, à traiter, retenue
Terracotta bd rgba(255,222,210,.9)  bordure de carte urgente
Or            #8A5B14   avertissement (texte)
Or clair      #C9A15B   point « ménage à faire »
Or fond       rgba(251,243,226,.9)
Départ        #E8B48A   point de départ
```

### Plateformes
Reprises telles quelles de `public/reporting.html` (`PLATFORM_COLORS`) :
```
Airbnb       #FF5A5F
Booking.com  #003580
Expedia      #FFC72C
Vrbo         #1A5276
Direct       #0E3B2E
Bloqué       #9CA3AF
```
Normalisation à reprendre aussi : `manuel`/`manual`/`direct` → **Direct** ; `block`/`blocked` → **Bloqué**.

## Typographie

SF Pro, police système. Aucune police à embarquer.

```
Grand titre        30 / bold      -0.032em   « Aujourd'hui », « Messages »
Sur-titre          12.5 / semibold           ligne au-dessus du grand titre
Valeur héro        34 / semibold  -0.035em   montants
Titre de ligne     16 – 18 / semibold
Corps              14.5 – 15
Métadonnée         12.5 – 13.5
Intertitre         11.5 / bold    +0.13em    capitales, gris atténué
Étiquette onglet   10.5 / medium
```

## Matériaux Liquid Glass

**Chrome — verre franc.** Barre de navigation, barre d'onglets, feuilles, barre d'action basse.
```
remplissage  dégradé blanc .50 → .30 → .42
flou         44px, saturation 230%, luminosité 1.07
bordure      1px rgba(255,255,255,.50)
arête        inset 0 1.5px 1px rgba(255,255,255,.95)
             inset 0 -1.5px 1px rgba(255,255,255,.45)
ombre        0 14px 38px rgba(20,32,27,.20)
```
En SwiftUI : `.glassEffect(in: .rect(cornerRadius: 30))` sur un conteneur, plus l'arête spéculaire en surcouche. Les quatre bords doivent porter l'arête, pas seulement le haut.

**Contenu — verre épais.** Cartes de liste, blocs de formulaire.
```
remplissage  rgba(255,255,255,.62)   (.66 – .72 pour les cartes héro)
flou         22px, saturation 180%
bordure      1px rgba(255,255,255,.70)
arête        inset 0 1px 0 rgba(255,255,255,.85)
ombre        0 8px 22px rgba(20,32,27,.08)
```

**Opaque.** Un seul cas : la zone de signature, `#FFF` plein. Le trait doit se voir franchement.

## Rayons
```
Feuille (haut)     44        Carte              22
Bloc interne       20        Bouton             15 – 16
Vignette / icône   11 – 13   Puce / filtre      13 – 14
Barre d'onglets    30        Pastille           8 – 10
```

## Cibles tactiles
Minimum 44×44 pt. Les chevrons de ligne sont décoratifs : c'est la ligne entière qui est tappable.

## Material Symbols → SF Symbols

Les maquettes emploient Material Symbols Rounded comme substituts.

| Maquette | SF Symbol |
| --- | --- |
| today | `calendar.day.timeline.left` |
| calendar_month | `calendar` |
| forum | `bubble.left.and.bubble.right` |
| space_dashboard | `square.grid.2x2` |
| search | `magnifyingglass` |
| chevron_right / _left | `chevron.right` / `chevron.left` |
| expand_more | `chevron.down` |
| check_circle | `checkmark.circle.fill` |
| task_alt | `checkmark.circle` |
| error | `exclamationmark.triangle.fill` |
| key | `key.fill` |
| auto_awesome | `sparkles` |
| cleaning_services | `sparkles` |
| login (arrivée) | `arrow.down.right.circle` |
| logout (départ) | `arrow.up.right.circle` |
| block | `nosign` |
| euro | `eurosign.circle` |
| apartment | `building.2` |
| handshake (propriétaires) | `person.2` |
| receipt_long | `doc.text` |
| menu_book | `book` |
| badge | `person.text.rectangle` |
| schedule | `clock` |
| redeem | `gift` |
| explore | `map` |
| checkroom | `list.bullet` |
| hub | `antenna.radiowaves.left.and.right` |
| content_copy | `doc.on.doc` |
| draw | `signature` |
| request_quote | `doc.plaintext` |
| account_balance | `building.columns` |
| payments | `creditcard` |
| sms | `message` |
| mail | `envelope` |
| fingerprint | `faceid` |
| visibility_off | `eye.slash` |
| undo | `arrow.uturn.backward` |
| ios_share | `square.and.arrow.up` |
| add | `plus` |
| more_horiz | `ellipsis` |
| sync | `arrow.triangle.2.circlepath` |
| add_home | `house.badge.plus` |
| local_parking | `parkingsign` |
| delete | `trash` |
| storefront | `storefront` |
| directions_bus | `bus` |
| download | `square.and.arrow.down` |
| description | `doc.text` |

## Formats

Montants : `Intl` français, séparateur d'espace insécable, zéro décimale, suffixe ` €` — `42 380 €`. Reprendre le `fmt` de `reporting.html`.
Heures : `16 h`, `9 h 41` (espace avant et après le h).
Dates : `mardi 1 septembre` en minuscules.
