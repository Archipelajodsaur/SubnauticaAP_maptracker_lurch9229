# Live position tracking

The `map_tracker` variant exposes `LOCATION_TRACKING` from `scripts/init.lua`. A compatible host
resolves `location_setting_key` (`LivePosition_{team}_{player}`), subscribes to that DataStorage
key, and passes each complete decoded value to `location_markers`. It owns all subscription,
marker creation, updates, and removal. The `items_only` variant does not expose the contract
because it does not load the `Crater` map.

The API is version 1 and has one resolver:

```lua
LOCATION_TRACKING = {
    api_version = 1,
    location_setting_key = "LivePosition_{team}_{player}",
    location_markers = function(value)
        return {
            { id = "reporter-id", map = "Crater", x = 400, y = 400, visible = true },
        }
    end,
}
```

`location_markers` always returns an array. A direct legacy XYZ value produces one marker with ID
`player`; the current reporter-ID dictionary produces one marker for every valid reporter. Invalid
or missing values produce an empty array, allowing the host to remove stale markers. Marker IDs
are stable reporter IDs and are returned in lexical order. Each marker has `id`, `map`, `x`, `y`,
and `visible`; `label` and `debug` are optional.

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

Current publishers store a dictionary keyed by an anonymous per-installation reporter ID, so
multiple installations connected to one AP slot appear simultaneously. Each entry contains raw XYZ
and may include a `label`. Direct XYZ objects from previous publishers remain supported.

For normal PopTracker releases that do not provide a native `LOCATION_TRACKING` host, the pack
retains a compatibility implementation: it watches the same key and renders `MapMarker` UI hints
itself. A native host sets `LOCATION_TRACKING_HOST = true` before loading pack Lua; that disables
the compatibility subscription, coordinate readout updates, and UI hints so only the host owns
live-marker lifecycle. The legacy marker path still requires PopTracker 0.36.0 or newer (or the
`feat/map-marker-mvp` build) for dynamic markers.

Run `python3 tests/test_crater_projection.py` from the pack root to verify the projection against
the 39 authored Crater landmarks. If a Lua CLI is available, run
`lua tests/test_location_tracking.lua` to exercise the unified resolver and both host paths.
