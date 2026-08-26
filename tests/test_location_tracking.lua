-- Run from the pack root with: lua tests/test_location_tracking.lua

local fixtures = dofile("tests/location_tracking_fixtures.lua")
dofile("scripts/location_tracking.lua")

local function assert_close(actual, expected, name)
    assert(math.abs(actual - expected) < 0.000001,
        string.format("%s: expected %.6f, got %.6f", name, expected, actual))
end

assert(LOCATION_TRACKING.api_version == 1)
assert(LOCATION_TRACKING.location_setting_key == "LivePosition_{team}_{player}")
assert(type(LOCATION_TRACKING.location_icon_coords) == "function")

for _, fixture in ipairs(fixtures.valid) do
    local placement = LOCATION_TRACKING.location_icon_coords(fixture.value)
    assert(placement ~= nil, fixture.name .. ": expected a placement")
    assert(placement.map == fixture.expected.map, fixture.name .. ": unexpected map")
    assert_close(placement.x, fixture.expected.x, fixture.name .. " x")
    assert_close(placement.y, fixture.expected.y, fixture.name .. " y")
    assert(placement.visible == true, fixture.name .. ": expected visible placement")
    assert(placement.debug.world_y == fixture.value.y, fixture.name .. ": depth was not retained")
end

assert(LOCATION_TRACKING.location_icon_coords(nil) == nil,
    "nil input must not produce a placement")

for _, value in ipairs(fixtures.invalid) do
    assert(LOCATION_TRACKING.location_icon_coords(value) == nil,
        "malformed or non-finite input must not produce a placement")
end

print("location_tracking.lua: all fixtures passed")
