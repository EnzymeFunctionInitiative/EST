import pytest

from pyEFI.statistics import compute_conv_ratio

@pytest.mark.parametrize("node_count,edge_count,expected", [
    (1,1,0.0),
    (5,2,0.2),
    (9825, 17582, 0.0003643152564006929),
    (12,12,1.0)
])
def test_normal_cases(node_count: int, edge_count: int, expected: float):
    assert compute_conv_ratio(node_count, edge_count) - expected < .00001

def test_unconnected():
    assert compute_conv_ratio(131,0) == 0.0

def test_impossible_network():
    with pytest.raises(ValueError) as e:
        cr = compute_conv_ratio(5,11)
        print(cr)
    assert e.type == ValueError