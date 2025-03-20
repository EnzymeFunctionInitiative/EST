
cat <<JSON > /tmp/user_filter.json
[
    {
        "name": "bacteria",
        "operator": "OR",
        "conditions": [
            {
                "field": "domain",
                "value": "Bacteria"
            }
        ]
    }
]
JSON


