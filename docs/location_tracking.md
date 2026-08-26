# Live position tracking

The `map_tracker` variant exposes `LOCATION_TRACKING` from `scripts/init.lua` for hosts that
implement the initiative's live-position contract. Normal PopTracker does not call this table,
so it remains inert there. The `items_only` variant does not expose the contract because it does
not load the `Crater` map.

`location_setting_key` is `LivePosition_{team}_{player}`. The host resolves the placeholders and
passes the decoded DataStorage table to `location_icon_coords`.

The resolver accepts only finite numeric `x`, `y`, and `z` Unity world coordinates. It returns
the exact tracker map name `Crater` and source-image pixels:

```text
map_x = 400 + world_x / 5
map_y = 400 - world_z / 5
```

`world_y` is retained as `debug.world_y`, but does not select a map. `CaveNetworks` is a
schematic rather than a global projection, so this MVP deliberately does not classify caves.
Every finite coordinate is returned with `visible = true`, including a coordinate outside the
800×800 Crater image. This lets a host clip or diagnose off-map positions without treating an
otherwise valid player position as missing.

Vanilla PopTracker also watches the same DataStorage key for the connected team and player. It
requests the current value on connect, subscribes to later updates, and displays raw world XYZ to
one decimal place beneath the map. Invalid or unavailable values display `Position unavailable`.
This readout does not attempt to create a dynamic marker in PopTracker.

Run `python3 tests/test_crater_projection.py` from the pack root to verify the projection against
the 39 authored Crater landmarks. If a Lua CLI is available, run
`lua tests/test_location_tracking.lua` to exercise the exported resolver directly.
