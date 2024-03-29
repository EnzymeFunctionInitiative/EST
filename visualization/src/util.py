"""
Utilities and helper functions
"""

def parse_proxies(proxies: list[str] | None) -> dict[str, int] | None:
    """
    Convert ["key1:value1", "key2:value2",...] into {"key1": value1, "key2": value2, ...}

    Will exit on parse failure.

    Parameters:
    ---
        proxies (list[str]) - list of "key:value" proxy pairs from argparse option

    Returns:
    ---
        None if proxies is None, dict of string keys and int values otherwise
    """
    if proxies == None:
        return None
    sizes = {}
    for proxy in proxies:
        components = proxy.split(":")
        if len(components) != 2:
            print(f"Proxy '{proxy}' is not in KEY:VALUE format")
            exit(1)
        else:
            alias, dpi = components
            try:
                dpi = int(dpi)
                if dpi > 96:
                    print(f"DPI for '{alias}' is > 96, not adding to proxy list")
                else:
                    sizes[alias] = dpi
            except ValueError:
                print(f"Could not parse '{dpi}' for size '{alias}' as int")
                exit(1)
    return sizes
