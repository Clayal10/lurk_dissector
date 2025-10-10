lurk = Proto("lurk", "LURK")

local lurk_type = ProtoField.uint8("lurk.msg_type", "Message Type", base.HEX, {
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
})

lurk.fields = { lurk_type }

function lurk.dissector(buffer, pinfo, tree)
    if buffer:len() < 1 then 
        return false 
    end

    local first_byte = buffer(0,1):uint()
    if (first_byte < 0x01) or (first_byte > 0xe) then
        return false
    end

    pinfo.cols.protocol = "LURK"
    local subtree = tree:add(lurk, buffer(), "LURK Protocol Data")
    subtree:add(lurk_type, buffer(0, 1))

    return true
end

lurk:register_heuristic("tcp", lurk.dissector)