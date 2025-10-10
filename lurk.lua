local lurk = Proto("lurk", "LURK")

local message_types = {
    [0x01] = "Message",
    [0x02] = "Change Room",
    [0x03] = "Fight",
    [0x04] = "PVP Fight",
    [0x05] = "Loot",
    [0x06] = "Start",
    [0x07] = "Error",
    [0x08] = "Accept",
    [0x09] = "Room",
    [0x0a] = "Character",
    [0x0b] = "Game",
    [0x0c] = "Leave",
    [0x0d] = "Connection",
    [0x0e] = "Version"
}

-- for checking if the message is too short based on the length --
-- this prevents messages being sent byte by byte to be invalidated. Must have the whole message --
local minimum_length = {
    [0x01] = 67, -- can be much larger than this --
    [0x02] = 3,
    [0x03] = 1,
    [0x04] = 33,
    [0x05] = 33,
    [0x06] = 1,
    [0x07] = 4,
    [0x08] = 2, -- can use message_types map for the second byte --
    [0x09] = 37,
    [0x0a] = 48,
    [0x0b] = 7,
    [0x0c] = 1,
    [0x0d] = 37,
    [0x0e] = 5
}

-- Defining fields
local lurk_type = ProtoField.uint8("lurk.msg_type", "Message Type", base.HEX, message_types)

local accept = {
    action = ProtoField.uint8("lurk.action", "Accepted Action", base.HEX, message_types)
}

local function handle_accept(buffer, pinfo, tree)
    if buffer:len() < minimum_length[0x08] then
        return false
    end

    pinfo.cols.protocol = "LURK"
    local subtree = tree:add(lurk, buffer(), "LURK Protocol Data")
    subtree:add(lurk_type, buffer(0, 1))
    subtree:add(accept.action, buffer(1, 1))
    return true
end

local function handle_small_messages(buffer, pinfo, tree)
    pinfo.cols.protocol = "LURK"
    local subtree = tree:add(lurk, buffer(), "LURK Protocol Data")
    subtree:add(lurk_type, buffer(0, 1))
end

lurk.fields = {
    lurk_type, -- all messages have this one field --
    accept.action
}

function lurk.dissector(buffer, pinfo, tree)
    if buffer:len() < 1 then 
        return false 
    end

    local first_byte = buffer(0,1):uint()
    if (first_byte < 0x01) or (first_byte > 0xe) then
        return false
    end

    if first_byte == 0x08 then
        return handle_accept(buffer, pinfo, tree)
    end

    -- this will be used for now since it is better than nothing for all other messages. --
    handle_small_messages(buffer, pinfo, tree)
    return true
end

lurk:register_heuristic("tcp", lurk.dissector)