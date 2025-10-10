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

local error_code = {
    [0x00] = "0 - Other",
    [0x01] = "1 - Bad Room",
    [0x02] = "2 - Player Exists",
    [0x03] = "3 - Bad Monster",
    [0x04] = "4 - Stat Error",
    [0x05] = "5 - Not Ready",
    [0x06] = "6 - No Target",
    [0x07] = "7 - No Fight",
    [0x08] = "8 - No PVP"
}

-- Defining fields
local lurk_type = ProtoField.uint8("lurk.msg_type", "Message Type", base.HEX, message_types)

local message = {
    recipient = ProtoField.string("lurk.message_recipient", "Recipient"),
    sender = ProtoField.string("lurk.message_sender", "Sender"),
    narrator = ProtoField.string("lurk.message_narration", "Narration?"),
    message = ProtoField.string("lurk.message_message", "Message")
}

local changeroom = {
    roomnumber = ProtoField.uint16("lurk.changeroom", "Room Number")
}

local pvp = {
    target = ProtoField.string("lurk.pvp_target", "Target")
}

local error = {
    code = ProtoField.string("lurk.error_code", "Error Code"),
    message = ProtoField.string("lurk.error_message", "Error Message")
}

local accept = {
    action = ProtoField.uint8("lurk.action", "Accepted Action", base.HEX, message_types)
}

local room = {
    roomnumber = ProtoField.uint16("lurk.room_roomnumber", "Room Number"),
    roomname = ProtoField.string("lurk.room_roomname", "Room Name"),
    roomdesc = ProtoField.string("lurk.room_desc", "Room Description")
}

local function setup(buffer, pinfo, tree)
    pinfo.cols.protocol = "LURK"
    local subtree = tree:add(lurk, buffer(), "LURK Protocol Data")
    subtree:add(lurk_type, buffer(0,1))
    return subtree
end

local function handle_message(buffer, pinfo, tree)
    if buffer:len() < minimum_length[0x01] then
        return false
    end

    local subtree = setup(buffer, pinfo, tree)

    subtree:add(message.recipient, buffer(3, 32))
    subtree:add(message.sender, buffer(35, 30))
    if buffer(66,1):uint() == 0x01 then
        subtree:add(message.narrator, buffer(66, 1), "Yes")
    else
        subtree:add(message.narrator, buffer(66, 1), "No")
    end
    subtree:add(message.message, buffer(67,buffer:len()-67))
    return true
end

local function handle_changeroom(buffer, pinfo, tree)
    if buffer:len() < minimum_length[0x02] then
        return false
    end

    local subtree = setup(buffer, pinfo, tree)

    subtree:add(changeroom.roomnumber, buffer(1, 2), buffer(1, 2):le_uint())
    return true
end

local function handle_pvp(buffer, pinfo, tree)
    if buffer:len() < minimum_length[0x04] then
        return false
    end

    local subtree = setup(buffer, pinfo, tree)
    subtree:add(pvp.target, buffer(1,32))
    return true
end

local function handle_error(buffer, pinfo, tree)
    if buffer:len() < minimum_length[0x07] then
        return false
    end

    local subtree = setup(buffer, pinfo, tree)
    subtree:add(error.code, buffer(1, 1), error_code[buffer(1,1):uint()])
    subtree:add(error.message, buffer(4, buffer:len()-4))
    return true
end

local function handle_accept(buffer, pinfo, tree)
    if buffer:len() < minimum_length[0x08] then
        return false
    end

    local subtree = setup(buffer, pinfo, tree)

    subtree:add(accept.action, buffer(1, 1))
    return true
end

local function handle_room(buffer, pinfo, tree)
    if buffer:len() < minimum_length[0x09] then
        return false
    end

    local subtree = setup(buffer, pinfo, tree)

    subtree:add(room.roomnumber, buffer(1, 2), buffer(1, 2):le_uint())
    subtree:add(room.roomname, buffer(3, 32))
    subtree:add(room.roomdesc, buffer(37, buffer:len()-37))
    return true
end

local function handle_small_messages(buffer, pinfo, tree)
    setup(buffer, pinfo, tree)
end

lurk.fields = {
    lurk_type, -- all messages have this one field --
    accept.action,
    message.recipient,
    message.sender,
    message.narrator,
    message.message,
    changeroom.roomnumber,
    pvp.target,
    error.code,
    error.message,
    room.roomnumber,
    room.roomname,
    room.roomdesc
}

function lurk.dissector(buffer, pinfo, tree)
    if buffer:len() < 1 then 
        return false 
    end

    local first_byte = buffer(0,1):uint()
    if (first_byte < 0x01) or (first_byte > 0xe) then
        return false
    end

    if first_byte == 0x01 then
        return handle_message(buffer, pinfo, tree)
    end

    if first_byte == 0x02 then
        return handle_changeroom(buffer, pinfo, tree)
    end

    if first_byte == 0x04 then
        return handle_pvp(buffer, pinfo, tree)
    end

    if first_byte == 0x07 then
        return handle_error(buffer, pinfo, tree)
    end

    if first_byte == 0x08 then
        return handle_accept(buffer, pinfo, tree)
    end

    if (first_byte == 0x09) or (first_byte == 0x0d) then
        return handle_room(buffer, pinfo, tree)
    end

    -- this will be used for now since it is better than nothing for all other messages. --
    handle_small_messages(buffer, pinfo, tree)
    return true
end

lurk:register_heuristic("tcp", lurk.dissector)