import pytest

from pyEFI.cli import parse_proxies

def test_none():
    assert parse_proxies(None) is None

@pytest.mark.parametrize("proxies,expected", [
    (["small:18"], {"small": 18}),
    (["small:24", "medium:48"], {"small": 24, "medium": 48})
])
def test_normal(proxies, expected):
    assert parse_proxies(proxies) == expected

@pytest.mark.parametrize("proxies,expected", [
    (["huge:112"], {}),
    (["huge:100", "jumbo:200"], {}),
    (["small:18", "huge:112"], {"small": 18}),
    (["giant:150", "small:24", "huge:100", "medium:48", "jumbo:200"], {"small": 24, "medium": 48})
])
def test_too_large(proxies, expected):
    assert parse_proxies(proxies) == expected

@pytest.mark.parametrize("proxies", [
    ["foo:bar"],
    ["foo:bar", "asdf:qwerty"]
])
def test_invalid(proxies):
    print(proxies)
    with pytest.raises(SystemExit) as e:
        parse_proxies(proxies)
    assert e.type == SystemExit
    assert e.value.code == 1
