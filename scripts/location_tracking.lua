-- Waystone's live-position contract. PopTracker ignores this global.
--
-- The Crater image is a global X/Z projection. CaveNetworks is a schematic, so
-- this intentionally does not try to infer an underground region from depth.
-- Finite positions outside the image remain visible; hosts may clip or diagnose
-- them without losing a valid game-space position.

local function is_finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function crater_location_icon_coords(value)
    if type(value) ~= "table" then
        return nil
    end

    local world_x = value.x
    local world_y = value.y
    local world_z = value.z

    if not is_finite_number(world_x)
        or not is_finite_number(world_y)
        or not is_finite_number(world_z) then
        return nil
    end

    return {
        map = "Crater",
        x = 400 + world_x / 5,
        y = 400 - world_z / 5,
        visible = true,
        debug = {
            world_y = world_y,
        },
    }
end

LOCATION_TRACKING = {
    api_version = 1,
    location_setting_key = "LivePosition_{team}_{player}",
    location_icon_coords = crater_location_icon_coords,
}
