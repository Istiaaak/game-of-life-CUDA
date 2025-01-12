#ifndef GAME_H
#define GAME_H

#define GRID_SIZE 4096
#define GENERATIONS 10000


extern int grid[GRID_SIZE][GRID_SIZE];
extern int nextGrid[GRID_SIZE][GRID_SIZE];
extern int delay;

void initGrid();
void loadPattern(int pattern);
void displayGrid();
void applyRules();
void updateGrid();

#endif