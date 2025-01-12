import matplotlib.pyplot as plt
import matplotlib.animation as animation
import numpy as np

def read_iterations(filename):
    iterations = []
    with open(filename, 'r') as file:
        grid = []
        for line in file:
            line = line.strip()
            if line.startswith("Generation"):
                if grid:
                    iterations.append(np.array(grid, dtype=int))
                    grid = []
            elif line:
                grid.append([int(cell) for cell in line])
        if grid:
            iterations.append(np.array(grid, dtype=int))
    return iterations

def add_borders(grid):
    height, width = grid.shape
    bordered_grid = np.zeros((height + 2, width + 2), dtype=int)
    bordered_grid[1:-1, 1:-1] = grid
    return bordered_grid

def visualize_with_styles(iterations):
    # Ajouter des bordures à chaque grille
    iterations_with_borders = [add_borders(grid) for grid in iterations]

    fig, ax = plt.subplots(figsize=(8, 8))  # Taille de la fenêtre
    ax.set_xticks([])  # Désactiver les ticks sur les axes
    ax.set_yticks([])

    # Couleurs personnalisées pour les cellules vivantes et mortes
    cmap = plt.get_cmap("coolwarm")
    im = ax.imshow(iterations_with_borders[0], cmap=cmap, interpolation="nearest")

    # Ajouter une légende avec l'itération actuelle
    legend = ax.text(
        0.02, 0.95, "", transform=ax.transAxes, fontsize=14, color="black",
        verticalalignment='top', bbox=dict(boxstyle="round", facecolor="white", edgecolor="black")
    )

    def update(frame):
        im.set_array(iterations_with_borders[frame])
        legend.set_text(f"Generation: {frame}")
        return [im, legend]

    ani = animation.FuncAnimation(
        fig, update, frames=len(iterations_with_borders), interval=200, blit=True, repeat=False
    )

    plt.show()

if __name__ == "__main__":
    filename = "iterations.txt"  # Nom du fichier contenant les itérations
    iterations = read_iterations(filename)
    visualize_with_styles(iterations)
