#!/usr/bin/env python3
"""Check the Crater projection against the pack's authored landmark coordinates.

Run from the pack root with: python3 tests/test_crater_projection.py
"""

import json
import re
import statistics
from pathlib import Path


ACCESS_COORDINATES = re.compile(
    r"\[\$canAccess\|(-?\d+(?:\.\d+)?)\|(-?\d+(?:\.\d+)?)\|(-?\d+(?:\.\d+)?)\]"
)


def main() -> None:
    crater_path = Path("locations/Crater.json")
    crater = json.loads(crater_path.read_text())[0]
    x_errors = []
    y_errors = []

    for landmark in crater["children"]:
        map_location = landmark["map_locations"][0]
        if map_location["map"] != "Crater":
            continue

        coordinates = None
        for rule in landmark["sections"][0].get("access_rules", []):
            match = ACCESS_COORDINATES.search(rule)
            if match:
                coordinates = tuple(float(part) for part in match.groups())
                break
        if coordinates is None:
            continue

        world_x, _world_y, world_z = coordinates
        projected_x = 400 + world_x / 5
        projected_y = 400 - world_z / 5
        x_errors.append(abs(projected_x - map_location["x"]))
        y_errors.append(abs(projected_y - map_location["y"]))

    assert len(x_errors) == 39, f"expected 39 usable Crater landmarks, found {len(x_errors)}"
    assert statistics.mean(x_errors) <= 2.1, "Crater X projection no longer fits its landmarks"
    assert statistics.mean(y_errors) <= 1.7, "Crater Y projection no longer fits its landmarks"
    assert max(x_errors) <= 11.0, "Crater X projection has an unexpected landmark outlier"
    assert max(y_errors) <= 8.0, "Crater Y projection has an unexpected landmark outlier"

    print(
        "Crater projection fits 39 landmarks: "
        f"mean absolute error x={statistics.mean(x_errors):.3f}, "
        f"y={statistics.mean(y_errors):.3f}"
    )


if __name__ == "__main__":
    main()
