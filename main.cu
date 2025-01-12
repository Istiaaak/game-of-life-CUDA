#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#include <stdio.h>
#include <stdlib.h>
#include <curand_kernel.h>

#if defined(_WIN32) || defined(_WIN64)
#include <windows.h> // Pour Sleep
#else
#include <unistd.h> // Pour usleep
#endif




// Fonction pour calculer les voisins vivants
__device__ int countAliveNeighbors(const bool* grid, int x, int y, int width, int height) {
    int count = 0;
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            int nx = (x + dx + width) % width;
            int ny = (y + dy + height) % height;
            count += grid[ny * width + nx];
        }
    }
    return count;
}


__global__ void loadPatternKernel(bool* grid, int width, int height, int pattern) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height) return;

    // Indices centraux pour placer le motif
    int centerX = width / 2;
    int centerY = height / 2;

    // Réinitialisation de toute la grille
    grid[y * width + x] = 0;

    // Placement du motif à partir du centre (uniquement les threads nécessaires)
    if (pattern == 1) { // Blinker
        if ((x == centerX && y == centerY - 1) ||
            (x == centerX && y == centerY) ||
            (x == centerX && y == centerY + 1)) {
            grid[y * width + x] = 1;
        }
    } else if (pattern == 2) { // Block
        if ((x == centerX && y == centerY) ||
            (x == centerX && y == centerY + 1) ||
            (x == centerX + 1 && y == centerY) ||
            (x == centerX + 1 && y == centerY + 1)) {
            grid[y * width + x] = 1;
        }
    } else if (pattern == 3) { // Eater 1
        if ((x == centerX && y == centerY) ||
            (x == centerX && y == centerY + 1) ||
            (x == centerX - 1 && y == centerY) ||
            (x == centerX - 2 && y == centerY) ||
            (x == centerX - 3 && y == centerY - 1) ||
            (x == centerX - 3 && y == centerY - 2) ||
            (x == centerX - 2 && y == centerY - 2)) {
            grid[y * width + x] = 1;
        }
    } else if (pattern == 4) { // Glider
        if ((x == centerX && y == centerY) ||
            (x == centerX && y == centerY + 1) ||
            (x == centerX - 1 && y == centerY + 1) ||
            (x == centerX - 2 && y == centerY + 1) ||
            (x == centerX - 1 && y == centerY - 1)) {
            grid[y * width + x] = 1;
        }
    } else if (pattern == 5) { // Herschel
        if ((x == centerX + 1 && y == centerY - 1) ||
            (x == centerX && y == centerY - 1) ||
            (x == centerX && y == centerY) ||
            (x == centerX && y == centerY + 1) ||
            (x == centerX - 1 && y == centerY - 1) ||
            (x == centerX + 1 && y == centerY + 1) ||
            (x == centerX + 2 && y == centerY + 1)) {
            grid[y * width + x] = 1;
        }
    } else if (pattern == 6) { // Switch Engine
        if ((x == centerX && y == centerY - 1) ||
            (x == centerX && y == centerY) ||
            (x == centerX && y == centerY + 1) ||
            (x == centerX - 1 && y == centerY) ||
            (x == centerX - 1 && y == centerY - 3) ||
            (x == centerX - 2 && y == centerY - 4) ||
            (x == centerX - 3 && y == centerY - 3) ||
            (x == centerX - 3 && y == centerY - 1)) {
            grid[y * width + x] = 1;
        }
    }
}

// Kernel simple
__global__ void simpleKernel(bool* currentGrid, bool* nextGrid, int width, int height) {

    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height) return;

    // Calcul des voisins vivants avec la fonction précédente
    int neighbors = countAliveNeighbors(currentGrid, x, y, width, height);

    // Appliquer les règles du jeu
    bool currentCell = currentGrid[y * width + x];
    nextGrid[y * width + x] = (currentCell && (neighbors == 2 || neighbors == 3)) ||
                              (!currentCell && neighbors == 3);
}

__global__ void sharedMemoryKernel(bool* currentGrid, bool* nextGrid, int width, int height) {
    extern __shared__ bool sharedGrid[];

    int threadX = threadIdx.x;
    int threadY = threadIdx.y;

    int blockX = blockIdx.x * blockDim.x;
    int blockY = blockIdx.y * blockDim.y;

    int globalX = blockX + threadX;
    int globalY = blockY + threadY;

    int localX = threadX + 1;
    int localY = threadY + 1;

    int sharedWidth = blockDim.x + 2; // Largeur avec bordures

    // Charger les cellules locales dans la mémoire partagée
    if (globalX < width && globalY < height) {
        sharedGrid[localY * sharedWidth + localX] = currentGrid[globalY * width + globalX];
    } else {
        sharedGrid[localY * sharedWidth + localX] = 0;
    }

    // Charger les bordures (gauche, droite, haut, bas)
    if (threadX == 0 && globalX > 0) {
        sharedGrid[localY * sharedWidth] = currentGrid[globalY * width + globalX - 1];
    }
    if (threadX == blockDim.x - 1 && globalX < width - 1) {
        sharedGrid[localY * sharedWidth + localX + 1] = currentGrid[globalY * width + globalX + 1];
    }
    if (threadY == 0 && globalY > 0) {
        sharedGrid[localX] = currentGrid[(globalY - 1) * width + globalX];
    }
    if (threadY == blockDim.y - 1 && globalY < height - 1) {
        sharedGrid[(localY + 1) * sharedWidth + localX] = currentGrid[(globalY + 1) * width + globalX];
    }

    // Synchronisation des threads
    __syncthreads();

    // Calculer les voisins vivants
    if (globalX < width && globalY < height) {
        int neighbors = countAliveNeighbors(sharedGrid, localX, localY, sharedWidth, sharedWidth);

        // Appliquer les règles
        bool currentCell = sharedGrid[localY * sharedWidth + localX];
        nextGrid[globalY * width + globalX] = (neighbors == 3 || (neighbors == 2 && currentCell));
    }
}


__global__ void initializeGridKernel(bool* grid, int width, int height, unsigned int seed) {
    int globalX = blockIdx.x * blockDim.x + threadIdx.x; // Calcul de l'indice global
    int globalY = blockIdx.y * blockDim.y + threadIdx.y;
    int index = globalY * width + globalX;

    if (globalX < width && globalY < height) {
        // Utilisation d'un seed unique pour générer des nombres pseudo-aléatoires
        curandState state;
        curand_init(seed, index, 0, &state);

        // Initialiser chaque cellule à 0 ou 1
        grid[index] = curand(&state) % 2;
    }
}




void saveIterations(bool** iterations, int generationCount, int width, int height) {
    FILE* outFile = fopen("iterations.txt", "w");
    if (!outFile) {
        printf("Erreur : impossible de creer le fichier\n");
        return;
    }

    for (int gen = 0; gen < generationCount; ++gen) {
        fprintf(outFile, "Generation %d:\n", gen);
        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                fprintf(outFile, "%d", iterations[gen][y * width + x] ? 1 : 0);
            }
            fprintf(outFile, "\n");
        }
        fprintf(outFile, "\n");
    }

    fclose(outFile);
    printf("Les iterations ont ete sauvegardees dans 'iterations.txt'\n");
}


// Fonction d'affichage de la grille avec contours et délai
void displayGrid(bool* grid, int width, int height, int delayMs) {
    #if defined(_WIN32) || defined(_WIN64)
        system("cls");
    #else
        system("clear");
    #endif

    printf("+");
    for (int x = 0; x < width * 2; x++) printf("-");
    printf("+\n");

    for (int y = 0; y < height; y++) {
        printf("|");
        for (int x = 0; x < width; x++) {
            printf(grid[y * width + x] ? "O " : ". ");
        }
        printf("|\n");
    }

    printf("+");
    for (int x = 0; x < width * 2; x++) printf("-");
    printf("+\n");

    #if defined(_WIN32) || defined(_WIN64)
        Sleep(delayMs);
    #else
        usleep(delayMs * 1000); // Convertir en microsecondes
    #endif
}


int main() {
    int gridWidth = 128;
    int gridHeight = 128;
    int generations = 100;
    int frameDelay = 100;
    int tileSize = 2;

    // Demander à l'utilisateur de configurer les paramètres
    printf("Configurer les paramètres :\n");
    printf("Largeur de la grille (par defaut 128) : ");
    scanf("%d", &gridWidth);
    printf("Hauteur de la grille (par defaut 128) : ");
    scanf("%d", &gridHeight);
    printf("Nombre de generations (par defaut 100) : ");
    scanf("%d", &generations);
    printf("Delai entre les generations en ms (par defaut 100) : ");
    scanf("%d", &frameDelay);
    printf("Taille des blocs pour la memoire partagee (par defaut 2) : ");
    scanf("%d", &tileSize);

    bool* h_grid = (bool*)malloc(gridWidth * gridHeight * sizeof(bool));
    bool* h_newGrid = (bool*)malloc(gridWidth * gridHeight * sizeof(bool));
    bool* d_grid;
    bool* d_newGrid;

    cudaMalloc(&d_grid, gridWidth * gridHeight * sizeof(bool));
    cudaMalloc(&d_newGrid, gridWidth * gridHeight * sizeof(bool));

    int choice, pattern = 0;
    int displayChoice;

    // Configuration globale des dimensions de blocs et de grille
    dim3 blockSize(16, 16);
    dim3 gridSize((gridWidth + blockSize.x - 1) / blockSize.x, 
                  (gridHeight + blockSize.y - 1) / blockSize.y);

    // Demander à l'utilisateur de choisir entre une grille aléatoire ou un motif
    printf("Choisissez une option pour initialiser la grille :\n");
    printf("1 - Grille aleatoire\n");
    printf("2 - Charger un motif predefini\n");
    printf("3 - Mesurer les temps d'execution des kernels\n");
    scanf("%d", &choice);

    if (choice == 1) {
        unsigned int seed = time(NULL);
        initializeGridKernel<<<gridSize, blockSize>>>(d_grid, gridWidth, gridHeight, seed);
        cudaDeviceSynchronize();
    } else if (choice == 2) {
        printf("Choisissez un motif :\n");
        printf("1 - Blinker\n");
        printf("2 - Block\n");
        printf("3 - Eater 1\n");
        printf("4 - Glider\n");
        printf("5 - Herschel\n");
        printf("6 - Switch Engine\n");
        scanf("%d", &pattern);

        loadPatternKernel<<<gridSize, blockSize>>>(d_grid, gridWidth, gridHeight, pattern);
        cudaDeviceSynchronize();
    } else if (choice == 3) {
        // Initialisation de la grille avec des valeurs aléatoires avant les mesures
        unsigned int seed = time(NULL);
        initializeGridKernel<<<gridSize, blockSize>>>(d_grid, gridWidth, gridHeight, seed);
        cudaDeviceSynchronize();

        cudaEvent_t start, stop;
        float elapsedTimeSimple = 0.0f, elapsedTimeShared = 0.0f;

        cudaEventCreate(&start);
        cudaEventCreate(&stop);

        printf("Mesure du kernel simple :\n");
        cudaEventRecord(start);
        for (int gen = 0; gen < generations; gen++) {
            simpleKernel<<<gridSize, blockSize>>>(d_grid, d_newGrid, gridWidth, gridHeight);
            cudaDeviceSynchronize();

            bool* temp = d_grid;
            d_grid = d_newGrid;
            d_newGrid = temp;
        }
        cudaEventRecord(stop);
        cudaEventSynchronize(stop);
        cudaEventElapsedTime(&elapsedTimeSimple, start, stop);
        printf("Temps total du kernel simple : %.2f ms\n", elapsedTimeSimple);

        printf("Mesure du kernel avec memoire partagee : \n");
        int sharedMemorySize = (tileSize + 2) * (tileSize + 2) * sizeof(bool);
        cudaEventRecord(start);
        for (int gen = 0; gen < generations; gen++) {
            sharedMemoryKernel<<<gridSize, blockSize, sharedMemorySize>>>(d_grid, d_newGrid, gridWidth, gridHeight);
            cudaDeviceSynchronize();

            bool* temp = d_grid;
            d_grid = d_newGrid;
            d_newGrid = temp;
        }
        cudaEventRecord(stop);
        cudaEventSynchronize(stop);
        cudaEventElapsedTime(&elapsedTimeShared, start, stop);
        printf("Temps total du kernel avec memoire partagee : %.2f ms\n", elapsedTimeShared);

        cudaEventDestroy(start);
        cudaEventDestroy(stop);

        cudaFree(d_grid);
        cudaFree(d_newGrid);
        free(h_grid);
        free(h_newGrid);
        return 0;

    } else {
        printf("Option invalide. Arrêt du programme.\n");
        free(h_grid);
        free(h_newGrid);
        cudaFree(d_grid);
        cudaFree(d_newGrid);
        return -1;
    }

    printf("Voulez-vous afficher la grille ? (1: Oui, 0: Non)\n");
    scanf("%d", &displayChoice);

    bool** iterations = NULL;
    int generationCount = 0;

    if (displayChoice == 1) {
        for (int gen = 0; gen < generations; gen++) {
            cudaMemcpy(h_grid, d_grid, gridWidth * gridHeight * sizeof(bool), cudaMemcpyDeviceToHost);
            displayGrid(h_grid, gridWidth, gridHeight, frameDelay);
            simpleKernel<<<gridSize, blockSize>>>(d_grid, d_newGrid, gridWidth, gridHeight);
            cudaDeviceSynchronize();

            bool* temp = d_grid;
            d_grid = d_newGrid;
            d_newGrid = temp;
        }
    } else {
        iterations = (bool**)malloc(generations * sizeof(bool*));
        for (int i = 0; i < generations; i++) {
            iterations[i] = (bool*)malloc(gridWidth * gridHeight * sizeof(bool));
        }

        for (int gen = 0; gen < generations; gen++) {
            cudaMemcpy(h_grid, d_grid, gridWidth * gridHeight * sizeof(bool), cudaMemcpyDeviceToHost);
            memcpy(iterations[gen], h_grid, gridWidth * gridHeight * sizeof(bool));

            simpleKernel<<<gridSize, blockSize>>>(d_grid, d_newGrid, gridWidth, gridHeight);
            cudaDeviceSynchronize();

            bool* temp = d_grid;
            d_grid = d_newGrid;
            d_newGrid = temp;

            generationCount++;
        }

        saveIterations(iterations, generationCount, gridWidth, gridHeight);

        for (int i = 0; i < generations; i++) {
            free(iterations[i]);
        }
        free(iterations);
    }

    cudaFree(d_grid);
    cudaFree(d_newGrid);
    free(h_grid);
    free(h_newGrid);

    return 0;
}
