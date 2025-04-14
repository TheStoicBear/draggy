-- server.lua
local QBCore = exports['qb-core']:GetCoreObject()

-- This callback checks whether the player has the required item.
QBCore.Functions.CreateCallback('dragRace:hasItem', function(source, cb, itemName)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        local item = Player.Functions.GetItemByName(itemName)
        if item then
            cb(true)
        else
            cb(false)
        end
    else
        cb(false)
    end
end)
