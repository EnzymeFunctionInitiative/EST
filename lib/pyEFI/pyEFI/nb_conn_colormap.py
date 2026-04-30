import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap

def get_nb_conn_colormap():
    """
    Create a custom colormap for matplotlib that matches the previous Perl color ramp. The color
    progression is roughly dark blue -> yellow -> red -> magenta.

    Instead of
        cmap = plt.get_cmap(args.matplotlib_colormap)
    use
        cmap = get_nb_conn_colormap()

    Use it exactly like a built-in colormap.

    Returns
    -------
        LinearSegmentedColormap from matplotlib.colors
    """
    # Define the RGB colors from original Perl code
    # (Matplotlib requires RGB values to be normalized between 0.0 and 1.0)
    perl_colors = [
        (20/255, 50/255, 110/255),   # Dark Blue
        (255/255, 255/255, 0/255),   # Yellow
        (255/255, 50/255, 50/255),   # Red
        (255/255, 10/255, 150/255)   # Magenta
    ]

    # Create the custom colormap
    custom_cmap = LinearSegmentedColormap.from_list("custom_perl_ramp", perl_colors)

    return custom_cmap

