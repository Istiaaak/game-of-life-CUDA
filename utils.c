#include <stdio.h>
#include <stdlib.h>
#include <windows.h>

#include "utils.h"

// Taille de la grille
int grid[GRID_SIZE][GRID_SIZE];
int nextGrid[GRID_SIZE][GRID_SIZE];

// Initialisation aléatoire de la grille
void initGrid() {
    for (int i = 0; i < GRID_SIZE; i++) {
        for (int j = 0; j < GRID_SIZE; j++) {
            grid[i][j] = rand() % 2;
        }
    }
}

// Charger un motif initial dans la grille
void loadPattern(int pattern) {
    // Initialiser la grille à 0
    for (int i = 0; i < GRID_SIZE; i++) {
        for (int j = 0; j < GRID_SIZE; j++) {
            grid[i][j] = 0;
        }
    }

    // Coordonnées de départ pour chaque motif
    int startX = GRID_SIZE / 2;
    int startY = GRID_SIZE / 2;

    if (pattern == 1) { // Blinker
        grid[startX][startY - 1] = 1; grid[startX][startY] = 1; grid[startX][startY + 1] = 1;

    } else if (pattern == 2) { // Block
        grid[startX][startY] = 1; grid[startX][startY + 1] = 1;
        grid[startX + 1][startY] = 1; grid[startX + 1][startY + 1] = 1;

    } else if (pattern == 3) { // Eater 1
        grid[startX][startY] = 1; grid[startX][startY + 1] = 1;
        grid[startX-1][startY]=1; grid[startX-2][startY]=1;
        grid[startX-3][startY-1] =1;
        grid[startX-3][startY-2] =1;
        grid[startX-2][startY-2] =1;

    } else if (pattern == 4) { // Glider
        grid[startX][startY] = 1; grid[startX][startY + 1] = 1;
        grid[startX-1][startY + 1] = 1; grid[startX-2][startY + 1] = 1;
        grid[startX-1][startY - 1] = 1;

    } else if (pattern == 5) { // Herschel
        grid[startX + 1][startY - 1] = 1;
        grid[startX][startY - 1] = 1; grid[startX][startY] = 1; grid[startX][startY + 1] = 1;
        grid[startX - 1][startY - 1] = 1; grid[startX +1][startY + 1] =1;
        grid[startX + 2][startY + 1] = 1;

    } else if (pattern == 6) { // Switch Engine
        grid[startX][startY - 1] = 1; grid[startX][startY] = 1; grid[startX][startY + 1] = 1;
        grid[startX-1][startY]=1; grid[startX-1][startY -3]=1;
        grid[startX-2][startY-4] =1;
        grid[startX-3][startY-3] =1; grid[startX-3][startY-1] =1;
    }
}

// Afficher la grille
void displayGrid() {
    printf("\033[H"); // Déplace le curseur au coin supérieur gauche
    for (int i = 0; i < GRID_SIZE; i++) {
        for (int j = 0; j < GRID_SIZE; j++) {
            if (grid[i][j] == 1) {
                printf("O "); // Cellule vivante
            } else {
                printf(". "); // Cellule morte
            }
        }
        printf("\n");
    }
    fflush(stdout);
    Sleep(delay / 1000); 
}

// Compte les voisins vivants d'une cellule
int countNeighbors(int x, int y) {
    int count = 0;
    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            if (i == 0 && j == 0) continue;
            int nx = (x + i + GRID_SIZE) % GRID_SIZE; 
            int ny = (y + j + GRID_SIZE) % GRID_SIZE;
            count += grid[nx][ny];
        }
    }
    return count;
}

// Applique les règles du jeu de la vie
void applyRules() {
    for (int i = 0; i < GRID_SIZE; i++) {
        for (int j = 0; j < GRID_SIZE; j++) {
            int neighbors = countNeighbors(i, j);
            if (grid[i][j]) {
                nextGrid[i][j] = (neighbors == 2 || neighbors == 3) ? 1 : 0;
            } else {
                nextGrid[i][j] = (neighbors == 3) ? 1 : 0;
            }
        }
    }
}

// Mis à jour de la grille
void updateGrid() {
    for (int i = 0; i < GRID_SIZE; i++) {
        for (int j = 0; j < GRID_SIZE; j++) {
            grid[i][j] = nextGrid[i][j];
        }
    }
}
