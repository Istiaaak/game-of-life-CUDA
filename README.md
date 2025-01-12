# README - Jeu de la Vie GPU/CPU

## Description

Ce projet implémente le **jeu de la vie de Conway** en utilisant à la fois une version séquentiel et une version parallisable grace à CUDA. L'objectif est de comparer les performances entre ces deux implémentations.
## Fonctionnalités

1. **Initialisation de la grille** :
   - Grille aléatoire.
   - Motifs prédéfinis (Blinker, Block, Glider, etc.).
2. **Simulation CPU et GPU** :
   - Calcul des générations sur le CPU (mode séquentiel).
   - Calcul des générations sur le GPU avec des kernels CUDA.
   - Optimisation GPU avec mémoire partagée.
3. **Visualisation Python** :
   - Animation des générations à partir du fichier `iterations.txt`.
   - Affichage des grilles avec des contours et une légende dynamique pour chaque génération.
4. **Modes d'exécution** :
   - Affichage interactif des générations.
   - Sauvegarde des itérations dans un fichier texte.
   - Mesure des temps d'exécution pour comparer les performances CPU et GPU.

## Prérequis

- CUDA Toolkit installé pour la version GPU.
- Un GPU compatible avec CUDA pour la version GPU.
- Compilateur standard (par exemple, `gcc`) pour la version CPU.
- Python 3 avec les bibliothèques `matplotlib` et `numpy` pour la visualisation.

## Fichiers

- `main.cu` : Fichier principal contenant l'implémentation GPU avec CUDA.
- `cuda_test.cu` : Fichier qui permet de tester les tailles des grilles/tuiles comme un Grid Search
- `main.c` : Fichier principal contenant l'implémentation CPU.
- `utils.h` et `utils.c` : Fonctions utilitaires communes pour les versions CPU et GPU (affichage, gestion des motifs, etc.).
- `iterations.txt` : Fichier généré contenant les itérations sauvegardées.
- `viz.py` : Script Python pour animer les itérations sauvegardées.

## Compilation

### Version GPU

```bash
nvcc -o game_of_life_gpu main.cu
nvcc -o test cuda_test.cu
```

### Version CPU

```bash
gcc -o game_of_life_cpu main.c utils.c
```
Les paramètres de base sont : 
- **GRID_SIZE** : 4096
- **GENERATIONS** : 10000


## Exécution

### Version GPU

```bash
./game_of_life_gpu
```

### Version CPU

```bash
./game_of_life_cpu
```

### Visualisation Python

```bash
python ./viz.py
```

## Paramètres configurables

Lors de l'exécution, le programme vous demande de configurer les paramètres suivants :

- **Largeur de la grille** : Taille horizontale de la grille (par défaut : 128).
- **Hauteur de la grille** : Taille verticale de la grille (par défaut : 128).
- **Nombre de générations** : Nombre total de générations à simuler (par défaut : 100).
- **Délai entre générations** : Pause en millisecondes entre chaque génération pour l'affichage (par défaut : 100 ms).
- **Taille des blocs CUDA** : Nombre de threads par bloc (par défaut : 2) pour la version GPU.

## Modes d'exécution

1. **Grille aléatoire** :
   Le programme initialise une grille avec des cellules vivantes et mortes de manière aléatoire.

2. **Motifs prédéfinis** :
   Choisissez parmi les motifs prédéfinis (Blinker, Block, Glider, etc.) pour démarrer la simulation avec un état initial spécifique.

3. **Mesure des temps d'exécution** :

   - Mesure le temps total d'exécution sur le CPU.
   - Mesure le temps total d'exécution des kernels CUDA sur le GPU.


## Résultats

### Comparaison CPU vs GPU

- **Affichage interactif** : Visualisation des générations dans le terminal.
- **Sauvegarde des itérations** : Génération d'un fichier `iterations.txt` contenant l'état de la grille pour chaque génération.
- **Temps d'exécution** : Comparaison des performances


### Animation des itérations

- Les grilles sauvegardées dans `iterations.txt` sont animées avec Python.
- Chaque étape de la simulation est visualisée avec des couleurs et des bordures claires.
- Une légende indique le numéro de génération en temps réel.

