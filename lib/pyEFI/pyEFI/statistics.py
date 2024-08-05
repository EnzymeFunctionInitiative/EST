
def compute_conv_ratio(node_count: int, edge_count: int) -> float:
    """
    Compute the convergence ratio of the full network

    Parameters
    ----------
        node_count
            The number of nodes in the network
        
        edge_count
            The number of edges in the network

    Returns
    -------
        The convergence ratio, 0 < conv_ratio <= 1
    """
    num = edge_count * 2.0
    nom = float(node_count * (node_count - 1))
    if num > nom and nom != 0.0:
        raise ValueError(f"Number of edges {int(num)} is impossible for number of nodes (max is {int(nom)})")
    else:
        try:
            conv_ratio =  num / nom
        except ZeroDivisionError:
            conv_ratio = 0
        return conv_ratio