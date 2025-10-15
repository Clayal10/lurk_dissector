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
    [0x01] = 67, -- variable --
    [0x02] = 3,
    [0x03] = 1,
    [0x04] = 33,
    [0x05] = 33,
    [0x06] = 1,
    [0x07] = 4, -- variable --
    [0x08] = 2, -- can use message_types map for the second byte --
    [0x09] = 37, -- variable | also for connection --
    [0x0a] = 48, -- variable --
    [0x0b] = 7, -- variable --
    [0x0c] = 1,
    [0x0d] = 37, -- variable --
    [0x0e] = 5 -- variable --
}

local length_offset = {
    [0x01] = 1,
    [0x07] = 2,
    [0x09] = 35,
    [0x0a] = 46,
    [0x0b] = 5,
    [0x0d] = 35,
    [0x0e] = 3
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

local character = {
    name = ProtoField.string("lurk.character_name", "Name"),
    flags = ProtoField.uint8("lurk.character_flags", "Flags"),
    attack = ProtoField.uint16("lurk.character_attack", "Attack"),
    defense = ProtoField.uint16("lurk.character_defense", "Defense"),
    regen = ProtoField.uint16("lurk.character_regen", "Regen"),
    health = ProtoField.int16("lurk.character_health", "Health"),
    gold = ProtoField.uint16("lurk.character_gold", "Gold"),
    roomnumber = ProtoField.uint16("lurk.character_roomnumber", "Room Number"),
    description = ProtoField.string("lurk.character_description", "Description")
}

local game = {
    points = ProtoField.uint16("lurk.game_points", "Initial Points"),
    limit = ProtoField.uint16("lurk.game_limit", "Stat Limit"),
    description = ProtoField.string("lurk.game_description", "Description")
}

local version = {
    major = ProtoField.uint8("lurk.version_major", "Major Revision"),
    minor = ProtoField.uint8("lurk.version_minor", "Minor Revision"),
    size = ProtoField.uint16("lurk.version_size", "Bytes of Extensions")
}

-- takes a TVB and determines the length of a single message --
local function get_length(buffer)
    local t = buffer(0, 1)
    if t == 0x01 or t == 0x07 or t == 0x9 or t == 0x0a or t == 0x0b or t == 0x0d or t == 0x0e then
        local variable_length = buffer(length_offset[t], 2):le_uint()
        return minimum_length[t] + variable_length
    end
    return minimum_length[t]
end

local function setup(buffer, pinfo, tree)
    pinfo.cols.protocol = "LURK"
    local subtree = tree:add(lurk, buffer(0, get_length(buffer)), message_types[buffer(0, 1):uint()])
    subtree:add(lurk_type, buffer(0,1))
    return subtree
end

local function handle_message(buffer, pinfo, tree)
    if buffer:len() < minimum_length[0x01] then
        return nil, 0, false
    end

    local subtree = setup(buffer, pinfo, tree)
    local message_length = buffer(1, 2):le_uint()
    subtree:add(message.recipient, buffer(3, 32))
    subtree:add(message.sender, buffer(35, 30))
    if buffer(66,1):uint() == 0x01 then
        subtree:add(message.narrator, buffer(66, 1), "Yes")
    else
        subtree:add(message.narrator, buffer(66, 1), "No")
    end

    subtree:add(message.message, buffer(67,message_length))
    return subtree, 67+message_length, true
end

local function handle_changeroom(buffer, pinfo, tree)
    if buffer:len() < minimum_length[0x02] then
        return nil, 0, false
    end

    local subtree = setup(buffer, pinfo, tree)

    subtree:add(changeroom.roomnumber, buffer(1, 2), buffer(1, 2):le_uint())
    return subtree, 3, true
end

local function handle_pvp(buffer, pinfo, tree)
    if buffer:len() < minimum_length[0x04] then
        return nil, 0, false
    end

    local subtree = setup(buffer, pinfo, tree)
    subtree:add(pvp.target, buffer(1,32))
    return subtree, 33, true
end

local function handle_error(buffer, pinfo, tree)
    if buffer:len() < minimum_length[0x07] then
        return nil, 0, false
    end

    local subtree = setup(buffer, pinfo, tree)
    subtree:add(error.code, buffer(1, 1), error_code[buffer(1,1):uint()])
    local message_length = buffer(2, 2):le_uint()
    
    if message_length+4 > buffer:len() then
        pinfo.desegment_len = message_length+4-buffer:len()
        return subtree, buffer:len(), true
    end

    pinfo.desegment_len = 0
    subtree:add(error.message, buffer(4, message_length))
    return subtree, message_length+4, true
end

local function handle_accept(buffer, pinfo, tree)
    if buffer:len() < minimum_length[0x08] then
        return nil, 0, false
    end

    local subtree = setup(buffer, pinfo, tree)

    subtree:add(accept.action, buffer(1, 1))
    return subtree, 2, true
end

local function handle_room(buffer, pinfo, tree)
    if buffer:len() < minimum_length[0x09] then
        return nil, 0, false
    end

    local subtree = setup(buffer, pinfo, tree)

    subtree:add(room.roomnumber, buffer(1, 2), buffer(1, 2):le_uint())
    subtree:add(room.roomname, buffer(3, 32))
    local description_length = buffer(35, 2):le_uint()
    subtree:add(room.roomdesc, buffer(37, description_length))
    return subtree, description_length+37, true
end

local function handle_character(buffer, pinfo, tree)
    if buffer:len() < minimum_length[0x0a] then -- if we do at least 1 message, that is good enough
        return nil, 0, false
    end

    local subtree = setup(buffer, pinfo, tree)
    subtree:add(character.name, buffer(1,32))
    subtree:add(character.flags, buffer(33,1)) -- just displays as a byte --
    subtree:add(character.attack, buffer(34,2), buffer(34,2):le_uint())
    subtree:add(character.defense, buffer(36,2), buffer(36,2):le_uint())
    subtree:add(character.regen, buffer(38,2), buffer(38,2):le_uint())
    subtree:add(character.health, buffer(40,2), buffer(40,2):le_int())
    subtree:add(character.gold, buffer(42,2), buffer(42,2):le_uint())
    subtree:add(character.roomnumber, buffer(44,2), buffer(44, 2):le_uint())
    local description_length = buffer(46,2):le_uint()
    subtree:add(character.description, buffer(48, description_length))
    return subtree, 48+description_length, true
end

local function handle_game(buffer, pinfo, tree)
    if buffer:len() < minimum_length[0x0b] then
        return nil, 0, false
    end

    local subtree = setup(buffer, pinfo, tree)

    subtree:add(game.points, buffer(1, 2):le_uint())
    subtree:add(game.limit, buffer(3, 2):le_uint())
    local description_length = buffer(5, 2):le_uint()
    subtree:add(game.description, buffer(7, description_length))
    return subtree, description_length+7, true
end

local function handle_version(buffer, pinfo, tree)
    if buffer:len() < minimum_length[0x0e] then
        return nil, 0, false
    end

    local subtree = setup(buffer, pinfo, tree)

    subtree:add(version.major, buffer(1,1))
    subtree:add(version.minor, buffer(2,1))
    subtree:add(version.size, buffer(3,2))
    return subtree, 5, true
end

local function handle_small_messages(buffer, pinfo, tree)
    return setup(buffer, pinfo, tree), 1, true
end


lurk.fields = {
    lurk_type, -- all messages have this one field --
    message.recipient,
    message.sender,
    message.narrator,
    message.message,
    changeroom.roomnumber,
    pvp.target,
    error.code,
    error.message,
    accept.action,
    room.roomnumber,
    room.roomname,
    room.roomdesc,
    character.name,
    character.flags,
    character.attack,
    character.defense,
    character.regen,
    character.health,
    character.gold,
    character.roomnumber,
    character.description,
    game.points,
    game.limit,
    game.description,
    version.major,
    version.minor,
    version.size
}

local function dissect(buffer, pinfo, tree)
    local first_byte = buffer(0,1):uint()
    if (first_byte < 0x01) or (first_byte > 0xe) then
        return nil, 0, false
    end
    if first_byte == 0x01 then
        return handle_message(buffer, pinfo, tree)
    end
    if first_byte == 0x02 then
        return handle_changeroom(buffer, pinfo, tree)
    end
    if (first_byte == 0x04) or (first_byte == 0x05) then
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
    if first_byte == 0x0a then
        return handle_character(buffer, pinfo, tree)
    end
    if first_byte == 0x0b then
        return handle_game(buffer, pinfo, tree)
    end
    if first_byte == 0x0e then
        return handle_version(buffer, pinfo, tree)
    end
    return handle_small_messages(buffer, pinfo, tree)
end

function lurk.dissector(buffer, pinfo, tree)
    if buffer:len() < 1 then 
        return false 
    end

    local main_tree = tree:add(lurk, buffer(), "LURK Protocol Data")

    local main_offset = 0
    while buffer:len() - main_offset > 0 do
        local _, offset, ok = dissect(buffer(main_offset, buffer:len()-main_offset), pinfo, main_tree)
        if ok == false then
            return false
        end
        main_offset = main_offset + offset
    end

    return true
end

lurk:register_heuristic("tcp", lurk.dissector)