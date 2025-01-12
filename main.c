#include <stdio.h>
#include <time.h>
#include "utils.h"

int delay = 100000; // Délai entre chaque génération (en ms)

int main() {
    int choice;

    // Choix du motif initial
    printf("Sélectionnez un motif initial :\n");
    printf("1. Blinker\n");
    printf("2. Block\n");
    printf("3. Eater 1\n");
    printf("4. Glider\n");
    printf("5. Herschel\n");
    printf("6. Switch Engine\n");
    printf("7. Random\n");
    printf("Votre choix : ");
    scanf("%d", &choice);

    if (choice == 7) {
        initGrid(); // Grille aléatoire
    } else {
        loadPattern(choice); // Charger un motif
    }

    // Chronométrage
    clock_t start = clock(); // Démarrer le chronomètre

    // Mode séquentiel (CPU)
    for (int gen = 0; gen < GENERATIONS; gen++) {
        applyRules();
        //displayGrid();  
        updateGrid();
    }

    clock_t end = clock(); // Arrêter le chronomètre

    // Calcul du temps écoulé
    double elapsed_time = ((double)(end - start)) / CLOCKS_PER_SEC;
    printf("Temps d'exécution pour %d générations : %.2f secondes\n", GENERATIONS, elapsed_time);

    return 0;
}
