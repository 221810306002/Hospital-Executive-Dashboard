"""
build_dashboard.py

Injects dashboard/kpi_data.json directly into template.html so the
resulting index.html can be opened straight from the file system (no
local web server needed to dodge fetch()/CORS issues with file:// URLs).

Usage:
    python dashboard/build_dashboard.py
"""

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATE_PATH = os.path.join(HERE, "template.html")
DATA_PATH = os.path.join(HERE, "kpi_data.json")
OUTPUT_PATH = os.path.join(HERE, "index.html")


def main():
    with open(DATA_PATH) as f:
        data = json.load(f)

    with open(TEMPLATE_PATH) as f:
        template = f.read()

    output = template.replace("__KPI_DATA__", json.dumps(data))

    with open(OUTPUT_PATH, "w") as f:
        f.write(output)

    print(f"Built {OUTPUT_PATH} ({len(output):,} bytes)")


if __name__ == "__main__":
    main()
