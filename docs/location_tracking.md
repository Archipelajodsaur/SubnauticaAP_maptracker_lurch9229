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

PopTracker also watches the same DataStorage key for the connected team and player. It requests
the current value on connect, subscribes to later updates, and uses the `MapMarker Crater` UI hint
to keep live markers at projected image coordinates. New publishers store a dictionary keyed by an
anonymous per-installation reporter ID, so multiple installations connected to one AP slot can
appear simultaneously. Each entry contains raw XYZ and may include a `label`; the pack displays
that label when present, otherwise it falls back to the connected player's Archipelago alias.
Existing publishers that store one direct XYZ object remain supported.

Every marker uses PopTracker's JSON hint format with a 16px `images/ui/live-player.png` icon (a
portable 🤿-style diving mask over a white circle). The pack removes markers whose reporter entry
is no longer present. The coordinate readout shows raw XYZ for legacy one-position values and the
number of live sources for reporter dictionaries.

Dynamic map markers require the `feat/map-marker-mvp` PopTracker build or PopTracker 0.36.0 and
newer. The `UiHint` call is guarded so older PopTracker versions continue to load the pack and
show the coordinate readout without a marker.

Run `python3 tests/test_crater_projection.py` from the pack root to verify the projection against
the 39 authored Crater landmarks. If a Lua CLI is available, run
`lua tests/test_location_tracking.lua` to exercise the exported resolver directly.
