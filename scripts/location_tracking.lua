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

local watched_position_key = nil

local function set_coordinate_overlay(value)
    if Tracker == nil or Tracker.FindObjectForCode == nil then
        return
    end

    local display = Tracker:FindObjectForCode("live_coordinates")
    if display == nil or display.SetOverlay == nil then
        return
    end

    if type(value) ~= "table"
        or not is_finite_number(value.x)
        or not is_finite_number(value.y)
        or not is_finite_number(value.z) then
        display:SetOverlay("Position unavailable")
        return
    end

    display:SetOverlay(string.format("X: %.1f   Y: %.1f   Z: %.1f", value.x, value.y, value.z))
end

local function current_position_key()
    if Archipelago == nil
        or type(Archipelago.TeamNumber) ~= "number"
        or type(Archipelago.PlayerNumber) ~= "number"
        or Archipelago.TeamNumber < 0
        or Archipelago.PlayerNumber < 0 then
        return nil
    end

    return string.format("LivePosition_%d_%d", Archipelago.TeamNumber, Archipelago.PlayerNumber)
end

local function on_position_clear(_slot_data)
    watched_position_key = current_position_key()
    set_coordinate_overlay(nil)

    if watched_position_key == nil then
        return
    end

    Archipelago:SetNotify({watched_position_key})
    Archipelago:Get({watched_position_key})
end

local function on_position_value(key, value)
    if key == watched_position_key then
        set_coordinate_overlay(value)
    end
end

set_coordinate_overlay(nil)

if Archipelago ~= nil
    and Archipelago.AddClearHandler ~= nil
    and Archipelago.AddRetrievedHandler ~= nil
    and Archipelago.AddSetReplyHandler ~= nil
    and Archipelago.SetNotify ~= nil
    and Archipelago.Get ~= nil then
    Archipelago:AddClearHandler("live position clear handler", on_position_clear)
    Archipelago:AddRetrievedHandler("live position retrieved handler", on_position_value)
    Archipelago:AddSetReplyHandler("live position update handler", on_position_value)
end
