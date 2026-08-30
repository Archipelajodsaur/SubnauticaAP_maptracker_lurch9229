-- Run from the pack root with: lua tests/test_location_tracking.lua

local fixtures = dofile("tests/location_tracking_fixtures.lua")

local overlay = nil
local requested_keys = nil
local notified_keys = nil
local handlers = {}
local ui_hints = {}

Tracker = {
    FindObjectForCode = function(_self, code)
        if code ~= "live_coordinates" then
            return nil
        end
        return {
            SetOverlay = function(_item, value)
                overlay = value
            end,
        }
    end,
    UiHint = function(_self, name, value)
        table.insert(ui_hints, {name = name, value = value})
    end,
}

Archipelago = {
    TeamNumber = 2,
    PlayerNumber = 7,
    GetPlayerAlias = function(_self, slot)
        assert(slot == 7, "marker label requested the wrong player alias")
        return "Diver \"Blue\""
    end,
    AddClearHandler = function(_self, _name, callback) handlers.clear = callback end,
    AddRetrievedHandler = function(_self, _name, callback) handlers.retrieved = callback end,
    AddSetReplyHandler = function(_self, _name, callback) handlers.updated = callback end,
    Get = function(_self, keys) requested_keys = keys end,
    SetNotify = function(_self, keys) notified_keys = keys end,
}

dofile("scripts/location_tracking.lua")

local function assert_close(actual, expected, name)
    assert(math.abs(actual - expected) < 0.000001,
        string.format("%s: expected %.6f, got %.6f", name, expected, actual))
end

assert(LOCATION_TRACKING.api_version == 1)
assert(LOCATION_TRACKING.location_setting_key == "LivePosition_{team}_{player}")
assert(type(LOCATION_TRACKING.location_markers) == "function")
assert(LOCATION_TRACKING.location_icon_coords == nil,
    "the unified API exposes one marker resolver")

for _, fixture in ipairs(fixtures.valid) do
    local markers = LOCATION_TRACKING.location_markers(fixture.value)
    assert(#markers == 1, fixture.name .. ": expected one marker")
    local marker = markers[1]
    assert(marker.id == "player", fixture.name .. ": legacy marker has the wrong ID")
    assert(marker.map == fixture.expected.map, fixture.name .. ": unexpected map")
    assert_close(marker.x, fixture.expected.x, fixture.name .. " x")
    assert_close(marker.y, fixture.expected.y, fixture.name .. " y")
    assert(marker.visible == true, fixture.name .. ": expected visible marker")
    assert(marker.debug.world_y == fixture.value.y, fixture.name .. ": depth was not retained")
end

assert(#LOCATION_TRACKING.location_markers(nil) == 0,
    "nil input must not produce markers")

for _, value in ipairs(fixtures.invalid) do
    assert(#LOCATION_TRACKING.location_markers(value) == 0,
        "malformed or non-finite input must not produce markers")
end

assert(overlay == "Position unavailable", "display must start without stale coordinates")
assert(#ui_hints == 0, "no marker should be created before a position arrives")

handlers.clear({})
assert(requested_keys[1] == "LivePosition_2_7", "clear handler requested the wrong key")
assert(notified_keys[1] == "LivePosition_2_7", "clear handler watched the wrong key")
assert(#ui_hints == 0, "clear handler must not create a marker")

local hint_count = #ui_hints
handlers.retrieved("OtherKey", {x = 1, y = 2, z = 3})
assert(overlay == "Position unavailable", "unrelated DataStorage keys must be ignored")
assert(#ui_hints == hint_count, "unrelated DataStorage keys must not move the marker")

local function most_recent_hint(marker_id)
    for index = #ui_hints, 1, -1 do
        if ui_hints[index].value:find('"id":"' .. marker_id .. '"', 1, true) then
            return ui_hints[index]
        end
    end
    return nil
end

local exported_reporters = LOCATION_TRACKING.location_markers({
    desktop = {x = -1, y = 2.25, z = 3, label = "Desktop"},
    laptop = {x = 842.34, y = -127.76, z = -416.24},
})
assert(#exported_reporters == 2,
    "exported resolver must return every reporter")
assert(exported_reporters[1].id == "desktop" and exported_reporters[2].id == "laptop",
    "reporter markers must have deterministic IDs and order")
assert(exported_reporters[1].label == "Desktop", "exported reporter label was lost")
assert(exported_reporters[2].label == nil, "missing labels must remain optional")
assert_close(exported_reporters[1].x, 399.8, "exported desktop marker x")
assert_close(exported_reporters[2].y, 483.248, "exported laptop marker y")

-- Previous publishers write one direct coordinate object. Keep rendering that
-- form while new publishers write a reporter-ID keyed dictionary.
handlers.retrieved("LivePosition_2_7", {x = 842.34, y = -127.76, z = -416.24})
assert(overlay == "X: 842.3   Y: -127.8   Z: -416.2", "retrieved coordinates were formatted incorrectly")
assert(most_recent_hint("player").name == "MapMarker Crater", "marker update targeted the wrong map")
assert(most_recent_hint("player").value == '{"id":"player","x":568.468000,"y":483.248000,"appearance":{"type":"icon","path":"images/ui/live-player.png","size":16},"label":"Diver \\"Blue\\""}',
    "retrieved coordinates produced the wrong marker position")

handlers.updated("LivePosition_2_7", {
    desktop = {x = -1, y = 2.25, z = 3, label = "Desktop"},
    laptop = {x = 842.34, y = -127.76, z = -416.24},
}, nil)
assert(overlay == "2 live position sources", "multi-reporter coordinate display was formatted incorrectly")
assert(most_recent_hint("player").value == '{"id":"player","remove":true}',
    "legacy marker must be removed when reporters are identified")
assert(most_recent_hint("player-desktop").value == '{"id":"player-desktop","x":399.800000,"y":399.400000,"appearance":{"type":"icon","path":"images/ui/live-player.png","size":16},"label":"Desktop"}',
    "configured reporter label was not used")
assert(most_recent_hint("player-laptop").value == '{"id":"player-laptop","x":568.468000,"y":483.248000,"appearance":{"type":"icon","path":"images/ui/live-player.png","size":16},"label":"Diver \\"Blue\\""}',
    "unlabeled reporter must use the player alias")

handlers.updated("LivePosition_2_7", {desktop = {x = 0 / 0, y = 2, z = 3}}, nil)
assert(overlay == "Position unavailable", "invalid coordinate updates must clear the display")
assert(most_recent_hint("player-desktop").value == '{"id":"player-desktop","remove":true}',
    "invalid coordinate updates must remove the reporter marker")
assert(most_recent_hint("player-laptop").value == '{"id":"player-laptop","remove":true}',
    "missing reporter markers must be removed")

-- A host that implements the common contract must own the DataStorage and
-- marker lifecycle. The compatibility path must stay entirely inert there.
LOCATION_TRACKING_HOST = true
handlers = {}
requested_keys = nil
notified_keys = nil
ui_hints = {}
overlay = "not touched by the native host path"
dofile("scripts/location_tracking.lua")

assert(next(handlers) == nil, "native hosts must not receive legacy AP handlers")
assert(requested_keys == nil and notified_keys == nil,
    "native hosts must not create legacy DataStorage requests")
assert(#ui_hints == 0, "native hosts must not receive legacy UI hints")
assert(overlay == "not touched by the native host path",
    "native hosts must not initialize the legacy coordinate overlay")

print("location_tracking.lua: all fixtures passed")
