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

    
    int neighbors = countAliveNeighbors(currentGrid, x, y, width, height);

    
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

    int sharedWidth = blockDim.x + 2;

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



int main() {
    int generations;
    printf("Entrez le nombre de générations : ");
    scanf("%d", &generations);

    int gridSizes[] = {128, 256, 512, 1024, 2048, 4096, 8192};
    int tileSizes[] = {8, 16, 32, 64, 128};

    bool *d_grid, *d_newGrid;
    cudaMalloc(&d_grid, 1024 * 1024 * sizeof(bool)); // Allocation maximale pour les tests
    cudaMalloc(&d_newGrid, 1024 * 1024 * sizeof(bool));

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    for (int i = 0; i < sizeof(gridSizes) / sizeof(gridSizes[0]); i++) {
        for (int j = 0; j < sizeof(tileSizes) / sizeof(tileSizes[0]); j++) {
            int testGridSize = gridSizes[i];
            int testTileSize = tileSizes[j];

            dim3 blockSize(testTileSize, testTileSize);
            dim3 gridSize((testGridSize + blockSize.x - 1) / blockSize.x, 
                          (testGridSize + blockSize.y - 1) / blockSize.y);
            int sharedMemorySize = (testTileSize + 2) * (testTileSize + 2) * sizeof(bool);

            // Initialisation de la grille
            unsigned int seed = time(NULL);
            initializeGridKernel<<<gridSize, blockSize>>>(d_grid, testGridSize, testGridSize, seed);
            cudaDeviceSynchronize();

            // Mesure du kernel simple
            printf("Test - Grid: %d x %d, Tile: %d x %d\n", testGridSize, testGridSize, testTileSize, testTileSize);
            cudaEventRecord(start);
            for (int gen = 0; gen < generations; gen++) {
                simpleKernel<<<gridSize, blockSize>>>(d_grid, d_newGrid, testGridSize, testGridSize);
                cudaDeviceSynchronize();

                bool* temp = d_grid;
                d_grid = d_newGrid;
                d_newGrid = temp;
            }
            cudaEventRecord(stop);
            cudaEventSynchronize(stop);
            float elapsedTimeSimple;
            cudaEventElapsedTime(&elapsedTimeSimple, start, stop);
            printf("Kernel Simple: %.2f ms\n", elapsedTimeSimple);

            // Mesure du kernel avec mémoire partagée
            cudaEventRecord(start);
            for (int gen = 0; gen < generations; gen++) {
                sharedMemoryKernel<<<gridSize, blockSize, sharedMemorySize>>>(d_grid, d_newGrid, testGridSize, testGridSize);
                cudaDeviceSynchronize();

                bool* temp = d_grid;
                d_grid = d_newGrid;
                d_newGrid = temp;
            }
            cudaEventRecord(stop);
            cudaEventSynchronize(stop);
            float elapsedTimeShared;
            cudaEventElapsedTime(&elapsedTimeShared, start, stop);
            printf("Kernel Mémoire Partagée: %.2f ms\n", elapsedTimeShared);
        }
    }

    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(d_grid);
    cudaFree(d_newGrid);

    return 0;
}