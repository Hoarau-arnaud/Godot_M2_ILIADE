# Rapport — Simulation multi-agents spatiale sous Godot

## 1. Objectif du projet

Le projet consiste à réaliser sous **Godot 4.7.2** une simulation 3D de systèmes multi-agents dans un environnement spatial.

L'objectif est d'observer comment plusieurs agents autonomes se déplacent, perçoivent leur environnement, évitent des dangers et réagissent à d'autres agents. Le projet est développé progressivement afin de conserver un modèle simple, compréhensible et facile à présenter.

À terme, la simulation devra comporter au moins **4 types d'agents** et mettre en évidence au moins **un phénomène émergent**.

---

## 2. État actuel du projet

### Milestone 1 — Fondation

Le premier milestone a mis en place :

- 10 chasseurs bleus autonomes ;
- des astéroïdes de plusieurs tailles ;
- un environnement spatial 3D ;
- un mouvement autonome sur X, Y et Z ;
- séparation, cohésion et alignement entre chasseurs ;
- détection et évitement des obstacles ;
- collision réelle avec destruction du chasseur ;
- compteur de vaisseaux vivants et de morts.

### Milestone 2 — Mouvement, espacement, graphismes et caméra

Le deuxième milestone a amélioré :

- le mouvement relatif avant/arrière des chasseurs ;
- l'espacement entre les chasseurs ;
- l'anticipation des obstacles ;
- la prise en compte de plusieurs menaces proches ;
- les hitboxes ;
- le modèle visuel des chasseurs ;
- la variété et la rotation des astéroïdes ;
- le décor spatial ;
- une caméra de suivi et une caméra libre orbitale.

Validation historique du M2 avec la seed `20261012` :

- **10 survivants sur 10 après 90 secondes** ;
- distance moyenne au voisin le plus proche : **11,41 m** ;
- rapprochement minimal ponctuel : **5,52 m**.

La survie est donc actuellement le comportement normal, tout en conservant la possibilité d'une collision réelle dans une situation difficile.

### Milestone 3 — Regroupement et champ continu

Le troisième milestone ajoute :

- un regroupement autonome sans leader ni place attribuée ;
- une récupération locale jusqu'à **50 m**, lorsqu'un chasseur a peu de voisins proches ;
- un champ d'astéroïdes renouvelé devant les chasseurs et nettoyé derrière tous les survivants ;
- six configurations : rocher isolé, paire décalée, paire horizontale, paire verticale, groupe décalé, gros rocher avec deux petits compagnons ;
- trois difficultés automatiques selon la distance : facile avant **500 m**, intermédiaire jusqu'à **1 100 m**, difficile ensuite ;
- l'affichage de la distance, de la difficulté, de l'espacement moyen et de la dispersion, actualisé toutes les **0,4 seconde**.

Les astéroïdes sont des **obstacles de l'environnement et non des agents**. À la fin de M3, BlueShip était le seul type d'agent implémenté. Les graphismes et les commandes de caméra du M2 sont conservés.

Validation M3 sous Godot 4.7.2, seed `20261012`, pas fixe de 1/60 seconde, sans warning ni erreur :

| Résultat | 90 secondes | 300 secondes |
|---|---:|---:|
| Survivants / morts | 10 / 0 | 10 / 0 |
| Distance parcourue | 949,02 m | 3 167,86 m |
| Difficulté finale | 2 | 3 |
| Astéroïdes actifs au maximum | 29 | 40 |
| Configurations créées / supprimées | 27 / 16 | 92 / 79 |

Sur les 90 premières secondes, la distance moyenne au voisin le plus proche vaut **11,04 m**, le rapprochement minimal **6,71 m** et la dispersion maximale **23,96 m**. Aucun chasseur isolé au-delà du rayon normal de 32 m n'est observé. Les agents continuent d'avancer et le champ se renouvelle.

Après cinq minutes, il reste **29 astéroïdes actifs**, sous le plafond de **72**. Le nombre total de nœuds atteint au plus **620**. Le temps moyen de calcul par tick en mode headless reste proche de **0,48 ms** dans les deux fenêtres mesurées en difficulté 3. Cette mesure ne représente pas les FPS du rendu.

Les tests vérifient également les six configurations, leur reproduction avec la même graine, les seuils de difficulté, le nettoyage derrière un retardataire et l'absence de références invalides après suppression. Les tests de collisions réelles, de caméra et de mouvement du M2 restent valides.

---

### Milestone 4 — Drone de patrouille et difficulté au clavier

M4 ajoute le deuxième véritable agent, **PatrolDrone**, avec **deux drones verts** qui suivent leur propre route. Ils perçoivent leur waypoint, les astéroïdes locaux et les chasseurs très proches. Leurs décisions changent leur trajectoire ; ils ne poursuivent pas les BlueShip.

Les chasseurs anticipent désormais les croisements avec les drones à partir de leurs vitesses relatives. Les drones effectuent aussi un évitement léger à proximité d'un chasseur. Un contact réel reste possible : le BlueShip peut être détruit, tandis que le drone est considéré plus robuste. Un drone qui touche un astéroïde explose et Main le remplace après quelques secondes.

Les touches **0 / 1 / 2 / 3** permettent de reprendre le mode automatique ou de choisir facile, intermédiaire et difficile. Le changement concerne les nouvelles configurations d'astéroïdes ; celles déjà présentes restent en place. Le HUD indique **AUTO / MANUEL** et le nombre de drones actifs. Les statistiques et la caméra continuent à observer uniquement le groupe bleu.

Validation M4 sous Godot 4.7.2, seed `20261012`, pas fixe de 1/60 seconde, sans warning ni erreur :

| Résultat, 90 secondes | AUTO | MANUEL difficile dès le départ |
|---|---:|---:|
| BlueShip vivants / morts | 10 / 0 | 10 / 0 |
| Drones actifs / détruits | 2 / 0 | 2 / 0 |
| Distance parcourue | 948,98 m | 947,74 m |
| Difficulté finale | 2 | 3 |
| Astéroïdes actifs maximum | 29 | 38 |
| Ticks-agent de réaction à un drone | 432 | 231 |

Un tick-agent est un pas de simulation où un chasseur anticipe un danger mobile. Ce chiffre n'est pas un nombre certain de collisions évitées. En AUTO, l'espacement moyen vaut **10,96 m**, le rapprochement minimal **6,71 m**, la dispersion maximale **23,96 m**, sans chasseur isolé. En difficile manuel, l'espacement final vaut **11,26 m** et la dispersion finale **22,89 m**.

Le test de croisement contrôlé conserve le chasseur vivant, avec une distance minimale de **6,49 m**. Le stress avec perception désactivée confirme une destruction réelle. La patrouille est reproductible et change de waypoint. Les touches clavier, les états, l'évitement d'un astéroïde, la séparation entre flocking et danger mobile ainsi que les remplacements passent les tests. Les contrôles de caméra et le regroupement M3 restent valides.

Le test AUTO de **300 secondes** atteint **3 168,16 m**, niveau 3 : **9 chasseurs vivants, 1 mort, 2 drones actifs**. Aucun drone n'est détruit ; un est retiré loin derrière et remplacé. Le maximum observé est de **46 astéroïdes** et **688 nœuds**, avec un calcul moyen proche de **0,54 ms par tick headless**. La survie sur une longue durée n'est donc pas garantie. Le rendu et le drone vert en gros plan sont vérifiés visuellement.

### Milestone 5 — Fondation de combat

BlueShip peut maintenant tirer sur un **agent hostile devant lui**, si la situation est sûre. PatrolDrone devient le premier hostile destructible, avec **4 points de vie**. Les astéroïdes restent des obstacles indestructibles, jamais des cibles. Aucun troisième agent n'est ajouté.

Le tir est séparé du déplacement : le chasseur ne poursuit pas la cible et ne tourne pas pour viser. Le projectile cyan part du nez, sa direction est estimée une seule fois dans le cône frontal, puis il vole tout droit. Une cible derrière un rocher ne provoque pas de tir. L'évitement et la séparation critique restent prioritaires.

Pour améliorer la lisibilité de la démonstration, le HUD affiche uniquement le nombre de chasseurs détruits. Les autres métriques restent utilisées en interne pour les tests et l'étude.

Le nombre cible d'hostiles vaut **1 / 2 / 3** selon le niveau facile / intermédiaire / difficile. Le système de remplacement après 5 secondes est conservé. La zone de vol est un peu plus large, sans mur invisible, et la caméra continue à suivre les chasseurs bleus.

Validation sous Godot 4.7.2, seed `20261012`, pas fixe de 1/60 seconde, sans warning ni erreur :

| Résultat, 90 secondes | MANUEL 3, test principal | AUTO |
|---|---:|---:|
| BlueShip vivants / morts | 10 / 0 | 10 / 0 |
| Distance / difficulté finale | 950,12 m / 3 | 949,21 m / 2 |
| Drones actifs / créés | 3 / 5 | 2 / 3 |
| Drones détruits par tirs | 2 | 1 |
| Tirs / impacts hostiles | 9 / 8 | 4 / 4 |
| Réussite approximative | 88,89 % | 100,00 % |
| Astéroïdes actifs maximum | 38 | 28 |
| Espacement moyen | 11,66 m | 10,96 m |
| Dispersion maximale | 35,00 m | 23,92 m |

Aucun chasseur isolé n'est observé dans ces deux parcours. Les résultats viennent du scénario normal ; ils n'imposent pas une survie de 10/10. Les taux de réussite portent sur un petit nombre de tirs.

Les tests contrôlés vérifient le refus des amis, des rochers, des cibles derrière ou trop latérales, la portée, la priorité de sécurité et la ligne de vue. Quatre impacts enlèvent les quatre HP du drone, produisent une explosion et un seul score, puis Main le remplace. Un laser traverse la zone d'un BlueShip sans le blesser et s'arrête sur un astéroïde sans le modifier. La comparaison avec et sans combat montre un écart de trajectoire de **0,000000 m**, avec neuf tirs.

Les tests de navigation et caméra restent valides. Le parcours AUTO de **300 secondes** atteint **3 164,92 m**, niveau 3, avec **8 chasseurs vivants, 2 morts, 3 drones actifs**, au plus **47 astéroïdes** et **684 nœuds**. Ces morts réelles sont conservées dans les résultats. Le rendu du bolt et du HUD est vérifié visuellement.

## 3. Agents et environnement actuels

### Agent 1 — Chasseur bleu

Le chasseur bleu est **le premier des deux types d'agents** actuellement implémentés.

Il peut :

- avancer dans l'espace ;
- monter et descendre ;
- se déplacer vers la gauche ou la droite ;
- accélérer ou ralentir légèrement par rapport au groupe ;
- détecter ses voisins ;
- retrouver un voisin éloigné encore visible dans sa portée de récupération ;
- détecter les obstacles ;
- anticiper la trajectoire d'un drone proche ;
- détecter un hostile frontal et tirer si la situation est sûre ;
- modifier sa trajectoire pour éviter une collision.

Son déplacement est obtenu par la combinaison de règles locales simples :

- **wander 3D** : mouvement autonome naturel ;
- **séparation** : conserver une distance avec les autres chasseurs ;
- **cohésion** : rester dans la même zone générale que le groupe ;
- **alignement** : suivre approximativement la direction des voisins ;
- **évitement** : contourner les obstacles détectés ;
- **récupération locale** : revenir doucement vers un voisin visible entre 32 et 50 m quand moins de deux voisins sont proches.

Aucune formation géométrique précise n'est imposée.

### Combat de l'Agent 1

Le chasseur perçoit les dangers, les agents de **`hostile_agents`** devant lui et leur ligne de vue. Ses priorités sont :

1. éviter un danger ;
2. conserver une distance sûre avec les autres chasseurs ;
3. tirer sur un hostile visible si la cadence le permet ;
4. continuer son déplacement collectif.

La perception de combat porte à **60 m**, le tir à **44 m**, dans un cône de **6° de chaque côté** du nez. Les tirs sont espacés d'environ **0,6 à 0,8 seconde**, avec des décalages individuels reproductibles. Le laser vole à **60 m/s**, disparaît après **3 secondes** au maximum et retire **un point de vie**.

Les astéroïdes ne sont pas des cibles. Les PatrolDrone sont les premiers hostiles destructibles. Aucun BlueShip ne poursuit directement une cible ; le combat ne modifie pas les règles de vol.

### Agent 2 — Drone de patrouille

Le drone vert suit des points de passage 3D renouvelés au cours du vol. Son couloir est défini à son apparition, puis reste indépendant du centre des BlueShip.

Il perçoit :

- son waypoint courant ;
- les astéroïdes dans une portée de **44 m** ;
- les chasseurs à moins de **10 m**.

Il peut avancer, monter, descendre, changer de côté, ralentir légèrement, changer de waypoint et éviter un danger. Sa vitesse de base vaut **9,2 ou 9,8 m/s**, avec une petite variation. Une nouvelle cible se trouve **55 m plus loin**, avec des décalages X/Y autour du couloir.

Main vise **un, deux ou trois drones actifs** selon le niveau. Un drone détruit ou à plus de **120 m derrière tous les chasseurs** est remplacé après **5 secondes**, à **100–145 m devant le premier chasseur**, dans une position vérifiée sans rocher trop proche. Il peut y avoir momentanément moins de drones pendant le délai. Aucun drone n'est téléporté pendant sa patrouille et aucun ne choisit un chasseur à poursuivre.

Le drone rejoint **`hostile_agents`** et possède **4 HP**. `take_damage(amount)` diminue ses points de vie. À zéro HP par tir, il explose, émet un seul signal de destruction et disparaît ; Main ajoute un ennemi détruit. Un retrait ou une collision du drone avec un rocher ne rapporte pas de score de tir. Le drone ne tire pas encore.

### Obstacles de l'environnement — Astéroïdes

Les astéroïdes ne sont **pas considérés comme des agents** dans le modèle actuel.

Ils constituent des éléments de l'environnement que les chasseurs doivent percevoir et éviter. Ils existent en plusieurs tailles et formes et tournent lentement.

Le champ prépare des configurations jusqu'à 320 m devant le premier chasseur, autour de la position X/Y mesurée du groupe. Une configuration est retirée seulement lorsqu'elle est à plus de 100 m derrière le dernier survivant. La caméra et les chasseurs ne reçoivent aucune consigne de déplacement de ce système.

Le nettoyage protège aussi les drones encore actifs. Les futurs intercepteurs et poseurs de mines restent prévus pour les milestones suivants.

---

## 4. Diagramme d'état — Agent 1

Le diagramme suivant représente le comportement général d'un chasseur sans détailler le code.

```mermaid
stateDiagram-v2
    [*] --> Navigation

    Navigation --> Evitement : danger détecté
    Evitement --> Navigation : danger dépassé, voisins proches
    Evitement --> Regroupement : danger dépassé, voisin éloigné visible
    Navigation --> Regroupement : peu de voisins proches, voisin éloigné visible
    Regroupement --> Navigation : voisins retrouvés
    Regroupement --> Evitement : danger détecté

    Navigation --> Detruit : collision
    Evitement --> Detruit : collision
    Regroupement --> Detruit : collision

    Detruit --> [*]
```

Ces états décrivent la situation du chasseur. Les règles de séparation, cohésion, alignement, wander et récupération sont calculées continuellement. L'évitement prend la priorité en présence d'une menace. Aucun centre global ne sert de destination et aucun agent n'est téléporté.

---

### Décision de combat en parallèle

```mermaid
flowchart LR
    N[Navigation] -->|danger immédiat| E[Évitement]
    E -->|zone sûre| N
    C{Hostile visible devant ?} -->|oui| S{Situation sûre ?}
    S -->|oui| L{Ligne de vue libre ?}
    L -->|oui| T[Tir si cadence prête]
    T --> R[Rechargement]
```

La navigation conserve ses états. Le combat possède seulement **aucune cible**, **cible visible** et **rechargement** ; tirer est une action, pas un nouvel état de déplacement.

### Diagramme d'état — Agent 2

```mermaid
stateDiagram-v2
    [*] --> Patrouille
    Patrouille --> ChangementPoint : waypoint atteint ou dépassé
    ChangementPoint --> Patrouille : nouvelle cible choisie
    Patrouille --> Evitement : danger local détecté
    Evitement --> Patrouille : danger dépassé
    Evitement --> ChangementPoint : waypoint atteint, zone sûre
    Patrouille --> Detruit : HP épuisés ou collision astéroïde
    Evitement --> Detruit : HP épuisés ou collision astéroïde
    ChangementPoint --> Detruit : HP épuisés ou collision astéroïde
    Detruit --> [*]
```

Main peut ensuite faire apparaître un nouveau drone après le délai. Le drone décide selon ses perceptions locales ; le changement de waypoint n'est pas une route animée à l'avance.

## 5. Interaction actuelle entre les agents et leur environnement

```mermaid
flowchart LR
    A[Chasseur bleu] -->|détecte| B[Astéroïde]
    B -->|danger / proximité| A
    A -->|modifie sa trajectoire| C[Évitement 3D]

    A -->|observe| D[Autres chasseurs]
    D -->|position / direction| A

    A --> E[Séparation]
    A --> F[Cohésion]
    A --> G[Alignement]
    A --> H[Récupération locale si voisin éloigné visible]
    A -->|détecte et anticipe un danger mobile| I[PatrolDrone]
    I -->|évitement léger à proximité| A
    I -->|perçoit et évite| B
    A -->|tir frontal si situation sûre| J[Laser bleu]
    J -->|dégâts| I
    B -->|bloque sans subir de dégâts| J
```

---

## 6. Paramètres importants

Le rapport final ne cherchera pas à détailler tout le code. Les paramètres principaux à étudier sont :

- rayon de perception des voisins ;
- distance de séparation ;
- force de séparation ;
- force de cohésion ;
- force d'alignement ;
- rayon de détection des obstacles ;
- force d'évitement ;
- vitesse moyenne des chasseurs ;
- portée de récupération : **50 m**, contre **32 m** pour les voisins normaux ;
- seuil de récupération : moins de **2 voisins proches**, poids **0,8** ;
- espacement des configurations : **56 / 44 / 34 m** selon la difficulté ;
- seuils de progression : **500 / 1 100 m** ;
- horizon de génération : **320 m**, nettoyage : **100 m** derrière tous les survivants, plafond : **72 astéroïdes**.

La séparation douce commence à **11 m** et devient forte sous **7 m**. Ces valeurs validées en M2 sont conservées. La distance mesurée vient de la progression en Z du centre des survivants. L'espacement est la moyenne de leurs distances au voisin vivant le plus proche ; la dispersion est la plus grande distance au centre du groupe.

Pour le drone, les paramètres principaux sont la distance entre waypoints (**55 m**), leur portée d'arrivée (**7 m**), les écarts X/Y (**38 / 24 m**), la portée des astéroïdes (**44 m**) et la distance de sécurité envers les chasseurs (**10 m**). L'évitement léger du drone a un poids de **1,2** ; l'évitement mobile du BlueShip a un poids de **7** avec une anticipation de **3 secondes**.

Les spreads du champ valent maintenant **38 / 26 m**. Avec les configurations d'obstacles, la zone utile habituelle atteint environ **±35–45 m horizontalement et ±20–30 m verticalement**, sans enfermer les agents. Le zoom libre peut atteindre **220 m**. Le score et la cadence pourront être étudiés avec les autres paramètres.

Leur influence sera étudiée avec quelques configurations simples.

---

## 7. Caméra et observation

Deux modes de caméra sont disponibles :

- **Suivi** : la caméra suit automatiquement le groupe ;
- **Libre** : la caméra peut être déplacée autour de la simulation.

Commandes principales :

- **F** : alterner Suivi / Libre ;
- clic droit + souris : orbite ;
- molette : zoom ;
- flèches ou touches de déplacement : translation ;
- PageUp / PageDown : déplacement vertical ;
- **G** ou **Home** : recentrer la caméra sur le groupe.

La caméra sert uniquement à observer la simulation et n'influence pas les agents.

### Choix de difficulté

- **0** : AUTO, niveau selon la distance parcourue, avec les seuils de 500 et 1 100 m ;
- **1** : Facile manuel ;
- **2** : Intermédiaire manuel ;
- **3** : Difficile manuel.

Un retour à AUTO à 800 m reprend le niveau 2. Les obstacles déjà présents restent en place ; le champ se renouvelle selon le mode choisi. Le nombre cible de drones passe à 1 / 2 / 3 selon le niveau. Une baisse de niveau retire le surplus sans score.

---

## 8. Phénomène émergent étudié

Le phénomène émergent principal est le **maintien et la reformation spontanée du groupe**.

Aucune position fixe n'est attribuée aux chasseurs. Chaque agent applique seulement des règles locales. Malgré cela, les chasseurs ont tendance à rester dans une même zone, à se séparer lorsqu'ils sont trop proches, à contourner les obstacles puis à retrouver le groupe.

M4 introduit une première perturbation mobile avec le drone de patrouille. Le phénomène sera étudié plus précisément avec les futurs agents perturbateurs.

Un test M3 commence avec dix chasseurs volontairement dispersés, dont certains n'ont aucun voisin dans les 32 m habituels mais voient encore un membre du groupe à moins de 50 m. En **30 secondes**, la dispersion diminue de **49,00 m à 19,92 m**. L'espacement final vaut **10,82 m**, avec un minimum observé de **7,15 m**. Ils retrouvent la même zone sans finir collés. À 70 m, un chasseur ne reçoit aucune attraction : la récupération reste locale et limitée.

---

## 9. Futurs types d'agents envisagés

Les astéroïdes resteront des obstacles de l'environnement. Le projet vise désormais quatre types d'agents simples à distinguer et à expliquer.

### Agent 3 — Intercepteur hostile

Agent réactif qui patrouille, détecte un chasseur proche, le poursuit pendant un temps limité puis se désengage.

Comportement prévu :

```mermaid
stateDiagram-v2
    [*] --> Patrouille
    Patrouille --> Poursuite : chasseur détecté
    Poursuite --> Desengagement : durée atteinte ou cible perdue
    Desengagement --> Patrouille : zone sûre retrouvée
```

Cet agent introduira une perturbation directement liée au comportement des chasseurs.

### Agent 4 — Bomber / MineLayer

Futur agent plus lent, orange ou violet, qui contrôlera une zone avec des mines ou un projectile lourd. Le dépôt de mines reste l'un des comportements envisagés.

Les mines créées seront des **obstacles de l'environnement**, pas des agents supplémentaires.

Comportement prévu :

```mermaid
stateDiagram-v2
    [*] --> Entree
    Entree --> Deplacement : zone atteinte
    Deplacement --> Depot : point de dépôt atteint
    Depot --> Sortie : mine déposée
    Sortie --> Entree : nouveau passage
```

Les deux futurs agents ajouteront la poursuite active et la modification de l'environnement. Le drone de patrouille, déjà implémenté, apporte la perturbation par trajectoire mobile.

---

## 10. Limites actuelles

La version actuelle comporte plusieurs simplifications :

- champ continu testé pendant cinq minutes, sans recalage de l'origine pour les parcours très longs ;
- évitement local sans planification complète de trajectoire ;
- récupération impossible si tous les membres de l'autre groupe sont au-delà de 50 m ;
- budget borné pouvant retarder la génération si le groupe s'étire exceptionnellement en profondeur ;
- hitboxes simplifiées ;
- obstacles principalement statiques ;
- deux types d'agents pour le moment ;
- anticipation mobile supposant une vitesse constante sur quelques secondes ;
- deux morts réelles observées sur le parcours M5 de cinq minutes ;
- pas d'évitement entre drones et effectif temporairement réduit pendant un remplacement ;
- uniquement le tir frontal BlueShip, sans guidage ;
- approximation initiale de la trajectoire hostile, pouvant rater une manœuvre brusque ;
- aucun tir ennemi, aucune poursuite et aucune bombe BlueShip à ce stade.

Ces limites sont volontaires afin de construire la simulation progressivement.

---

## 11. Planning prévisionnel

### M1 — Fondation ✅
Chasseurs, astéroïdes, espace 3D, comportements de base, collision et HUD.

### M2 — Mouvement, espacement, graphismes et caméra ✅
Mouvement 3D plus naturel, meilleure séparation, évitement renforcé, environnement visuel et caméra libre.

### M3 — Cohésion du groupe, obstacles et difficulté progressive ✅
Récupération locale, espacement conservé, champ continu borné, six configurations d'obstacles, trois difficultés automatiques et mesures du groupe. Tests de 90 et 300 secondes validés.

### M4 — Agent 2 : drone de patrouille ✅
Deux drones autonomes, waypoints renouvelés, perceptions locales, évitement réciproque, collisions et remplacement. Difficulté AUTO/MANUEL par 0/1/2/3, HUD et tests des deux modes sur 90 secondes.

### M5 — Fondation de combat ✅
Tir frontal sûr, ligne de vue, hostile_agents, dégâts PatrolDrone, score, population 1/2/3, espace élargi et validation AUTO / MANUEL 3.

### M6 — Interceptor et tirs ennemis
Ajouter l'Agent 3 rouge : détection, poursuite temporaire, rafales et désengagement.

### M7 — Bomber / MineLayer
Ajouter l'Agent 4 plus lent, avec un rôle de contrôle de zone par projectile lourd ou mines.

### M8 — Scénarios et vagues
Créer les scénarios et des vagues déclenchables pour la démonstration.

### M9 — Bombes BlueShip
Ajouter des bombes limitées avec une zone d'effet plus importante.

### M10 — Étude et finalisation
Comparer les paramètres, états initiaux, difficultés et mesures. Stabilisation, vidéo, rapport final, diagrammes et PowerPoint de 10 minutes.

---

## 12. Questions auxquelles le rapport final devra répondre

Le rapport final devra rester simple et répondre notamment à :

- Quels sont les agents ?
- Que perçoivent-ils ?
- Quelles actions peuvent-ils réaliser ?
- Quels sont leurs comportements ?
- Quel est l'état initial ?
- Quels paramètres sont importants ?
- Comment ces paramètres influencent-ils la simulation ?
- Quel phénomène émergent apparaît ?
- Le modèle est-il robuste aux variations d'états initiaux ?
- Comment la simulation se termine-t-elle ?
- Quels patterns spatiaux ou temporels apparaissent ?
- Quelles sont les limites du modèle ?
- Quelles améliorations seraient possibles ?

Ce document sera mis à jour à chaque milestone.
