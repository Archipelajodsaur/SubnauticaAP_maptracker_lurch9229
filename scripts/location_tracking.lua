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

local function crater_position_icon_coords(value)
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

local function crater_location_icon_coords(value)
    local placement = crater_position_icon_coords(value)
    if placement ~= nil then
        return placement
    end

    if type(value) == "table" then
        for _, reporter_value in pairs(value) do
            placement = crater_position_icon_coords(reporter_value)
            if placement ~= nil then
                return placement
            end
        end
    end

    return nil
end

local function location_markers(value)
    local placement = crater_position_icon_coords(value)
    if placement ~= nil then
        return {
            {
                id = "player",
                map = placement.map,
                x = placement.x,
                y = placement.y,
                visible = placement.visible,
                label = type(value.label) == "string" and value.label or nil,
                debug = placement.debug,
            },
        }
    end

    if type(value) ~= "table" then
        return nil
    end

    local markers = {}
    for reporter_id, reporter_value in pairs(value) do
        if type(reporter_id) == "string" and reporter_id ~= "" then
            local reporter_placement = crater_position_icon_coords(reporter_value)
            if reporter_placement ~= nil then
                table.insert(markers, {
                    id = reporter_id,
                    map = reporter_placement.map,
                    x = reporter_placement.x,
                    y = reporter_placement.y,
                    visible = reporter_placement.visible,
                    label = type(reporter_value.label) == "string" and reporter_value.label or nil,
                    debug = reporter_placement.debug,
                })
            end
        end
    end

    return #markers > 0 and markers or nil
end

LOCATION_TRACKING = {
    api_version = 1,
    location_setting_key = "LivePosition_{team}_{player}",
    location_icon_coords = crater_location_icon_coords,
}

local watched_position_key = nil
local player_marker_id = "player"
local player_marker_icon_path = "images/ui/live-player.png"

local function json_string(value)
    return '"' .. value:gsub('[%z\1-\31\\"]', function(character)
        local escapes = {
            ['\\'] = '\\\\',
            ['"'] = '\\"',
            ['\b'] = '\\b',
            ['\f'] = '\\f',
            ['\n'] = '\\n',
            ['\r'] = '\\r',
            ['\t'] = '\\t',
        }
        return escapes[character] or string.format("\\u%04x", string.byte(character))
    end) .. '"'
end

local function player_marker_label()
    if Archipelago ~= nil
        and type(Archipelago.PlayerNumber) == "number"
        and Archipelago.GetPlayerAlias ~= nil then
        local succeeded, alias = pcall(Archipelago.GetPlayerAlias, Archipelago, Archipelago.PlayerNumber)
        if succeeded and type(alias) == "string" and alias ~= "" then
            return alias
        end
    end

    return "Player"
end

local function marker_label(value)
    if type(value) == "table" and type(value.label) == "string" and value.label ~= "" then
        return value.label
    end

    return player_marker_label()
end

local function set_coordinate_overlay(value)
    if Tracker == nil or Tracker.FindObjectForCode == nil then
        return
    end

    local display = Tracker:FindObjectForCode("live_coordinates")
    if display == nil or display.SetOverlay == nil then
        return
    end

    local placement = crater_position_icon_coords(value)
    if placement ~= nil then
        display:SetOverlay(string.format("X: %.1f   Y: %.1f   Z: %.1f", value.x, value.y, value.z))
        return
    end

    if type(value) ~= "table" then
        display:SetOverlay("Position unavailable")
        return
    end

    local markers = location_markers(value)
    local source_count = markers ~= nil and #markers or 0

    if source_count == 0 then
        display:SetOverlay("Position unavailable")
    else
        display:SetOverlay(string.format("%d live position source%s", source_count, source_count == 1 and "" or "s"))
    end
end

local active_markers = {}

local function remove_marker(marker_id, map)
    Tracker:UiHint("MapMarker " .. map, '{"id":' .. json_string(marker_id) .. ',"remove":true}')
end

local function set_marker(marker_id, placement, label)
    Tracker:UiHint(
        "MapMarker " .. placement.map,
        string.format(
            '{"id":%s,"x":%.6f,"y":%.6f,"appearance":{"type":"icon","path":"%s","size":16},"label":%s}',
            json_string(marker_id),
            placement.x,
            placement.y,
            player_marker_icon_path,
            json_string(label)
        )
    )
end

local function set_player_markers(value)
    if Tracker == nil or Tracker.UiHint == nil then
        return
    end

    local next_markers = {}
    local placement = crater_position_icon_coords(value)
    if placement ~= nil and placement.visible == true then
        next_markers[player_marker_id] = placement.map
        set_marker(player_marker_id, placement, marker_label(value))
    else
        local markers = location_markers(value)
        if markers ~= nil then
            for _, marker in ipairs(markers) do
                if marker.visible == true then
                    local marker_id = player_marker_id .. "-" .. marker.id
                    next_markers[marker_id] = marker.map
                    set_marker(marker_id, marker, marker.label or player_marker_label())
                end
            end
        end
    end

    for marker_id, map in pairs(active_markers) do
        if next_markers[marker_id] == nil then
            remove_marker(marker_id, map)
        end
    end
    active_markers = next_markers
end

local function set_player_position(value)
    set_coordinate_overlay(value)
    set_player_markers(value)
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
    set_player_position(nil)

    if watched_position_key == nil then
        return
    end

    Archipelago:SetNotify({watched_position_key})
    Archipelago:Get({watched_position_key})
end

local function on_position_value(key, value)
    if key == watched_position_key then
        set_player_position(value)
    end
end

set_player_position(nil)

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
