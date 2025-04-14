-- server.lua
local QBCore = exports['qb-core']:GetCoreObject()

-- Register the drag race item as a useable item
QBCore.Functions.CreateUseableItem('dragRaceItem', function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not Player.Functions.GetItemByName(item.name) then 
        return 
    end

    -- When the item is used, trigger the client event that opens the drag race UI.
    TriggerClientEvent('dragRace:useItem', source)
    print('Player [' .. source .. '] used the item: ' .. item.name)
end)
