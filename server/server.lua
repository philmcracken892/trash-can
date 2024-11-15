local RSGCore = exports['rsg-core']:GetCoreObject()


-- remove item
RegisterNetEvent('cools-garbage:server:removeItem')
AddEventHandler('cools-garbage:server:removeItem', function(item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    Player.Functions.RemoveItem(item, amount)
    TriggerClientEvent("inventory:client:ItemBox", src, RSGCore.Shared.Items[item], "remove")
end)

RegisterServerEvent("cools-garbage:server:itemdelete")
AddEventHandler("cools-garbage:server:itemdelete", function(location, item, qt, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
	local Playercid = Player.PlayerData.citizenid
    local itemv = item.name
    
    exports.oxmysql:execute('SELECT * FROM market_items WHERE marketid = ? AND items = ?',{location, itemv} , function(result)
        if result[1] ~= nil then
            local stockv = result[1].stock + tonumber(qt)
            --print(stockv)
            exports.oxmysql:execute('UPDATE market_items SET stock = ?, price = ? WHERE marketid = ? AND items = ?',{stockv, amount, location, itemv})
            Player.Functions.RemoveItem(itemv, qt)
            TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[itemv], "remove")
        else
            local price = amount
            exports.oxmysql:execute('INSERT INTO market_items (`marketid`, `items`, `stock`, `price`) VALUES (?, ?, ?, ?);',{location, itemv, qt, price})
            Player.Functions.RemoveItem(itemv, qt)
            TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[itemv], "remove")
        end
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('success.refill').." " ..qt.. "x " ..item.label, 'success')
    end)
end)

RegisterNetEvent('cools-garbage:server:interactTrashCan')
AddEventHandler('cools-garbage:server:interactTrashCan', function()
    local citizenid = RSGCore.Functions.GetPlayerData().citizenid

    -- Generate the stash name as "Trash (citizenID)"
    local stashName = "Trash (" .. citizenid .. ")"

    -- Open the stash inventory with the generated stash name
    TriggerServerEvent("inventory:server:OpenInventory", "stash", stashName, citizenid, {
        maxweight = 40000,
        slots = 21,
    })

    -- Set a timer to delete the stash after 5 minutes
    SetTimeout(5 * 60 * 1000, function()
        TriggerServerEvent("inventory:server:RemoveStash", "stash", stashName, citizenid)
    end)
end)

-- Function to remove the stash from the database and clear its contents
function RemoveStashFromDatabase(stashName, citizenid)
    -- Perform the necessary database operation to delete the stash based on the provided parameters
    -- For example, if you're using an SQL database, execute a DELETE query
    -- Replace the following lines with your actual database handling logic
    local query = "DELETE FROM stashes WHERE stash_name = @stashName AND citizen_id = @citizenid"
    MySQL.Async.execute(query, {
        ['@stashName'] = stashName,
        ['@citizenid'] = citizenid,
    }, function(rowsChanged)
        -- Check if the delete operation was successful (rowsChanged > 0)
        if rowsChanged > 0 then
            print("Stash removed from the database:", stashName)
            -- Optionally, notify the player that their stash was deleted
            TriggerClientEvent('chatMessage', source, "System", {255, 0, 0}, "Your stash was removed.")
        else
            print("Failed to remove stash from the database:", stashName)
        end
    end)

    -- Clear the stash contents from the database
    -- Similar to the deletion, you should perform the necessary database operation to clear the items
    -- associated with the stash from the database table where the stash contents are stored.
end

-- Event handler for the client-side request to delete the stash
RegisterNetEvent('cools-garbage:server:deleteStash')
AddEventHandler('cools-garbage:server:deleteStash', function()
    local src = source
    local PlayerData = RSGCore.Functions.GetPlayerData(src)
    local cid = PlayerData.citizenid
    local stashName = 'trash' .. cid -- Concatenate the string before passing it to the function
    RemoveStashFromDatabase(stashName, cid)
end)

