local RSGCore = exports['rsg-core']:GetCoreObject()

-- Register the event to delete the stash
RegisterNetEvent('cools-garbage:client:deleteStash')
AddEventHandler('cools-garbage:client:deleteStash', function()
    RSGCore.Functions.GetPlayerData(function(PlayerData)
        local cid = PlayerData.citizenid
        local stashName = 'trash' .. cid
        exports['rsg-inventory']:DeleteStash(stashName)  -- Use the new export to delete the stash
    end)
end)

-- Register the event to open the stash
RegisterNetEvent('cools-garbage:client:interactTrashCan')
AddEventHandler('cools-garbage:client:interactTrashCan', function()
    RSGCore.Functions.GetPlayerData(function(PlayerData)
        local cid = PlayerData.citizenid
        local stashName = 'trash' .. cid

        -- Use the new export to open the stash
        exports['rsg-inventory']:OpenStash({
            id = stashName,
            type = 'stash',
            label = 'Trash Container',
            weight = Config.trashMaxWeight,
            slots = Config.trashMaxSlots
        })

        SetTimeout(5 * 60 * 1000, function()
            -- Call the event to delete the stash after 5 minutes
            TriggerEvent('cools-garbage:client:deleteStash')
        end)
    end)
end)

Citizen.CreateThread(function()
    -- Define the single model ID for the trash can
    local model = 50927092  -- Model hash for the trash can

    -- Request and load the model once
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(1)
    end

    for _, npcstore in pairs(Config.trashLocations) do
        -- Add a blip if enabled
        if npcstore.showblip then
            local StoreBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, npcstore.shopcoords)
            SetBlipSprite(StoreBlip, npcstore.blipsprite, true)
            SetBlipScale(StoreBlip, npcstore.blipscale)
        end

        -- Spawn the trash can object at each location
        local dest = npcstore.shopcoords
        local object = CreateObject(model, dest.x, dest.y, dest.z, true, true, false)
        while not DoesEntityExist(object) do
            Wait(1)
        end

        -- Set object properties
        SetEntityHeading(object, npcstore.heading)
        SetEntityAsMissionEntity(object, true, true)
        FreezeEntityPosition(object, true)
        SetEntityCollision(object, true, true)

        -- Integrate with `ox_target`
        exports.ox_target:addModel(model, {
            {
                name = 'trash_can',
                icon = 'fas fa-trash',
                label = 'Use Trash Can',
                distance = 2.0,
                onSelect = function()
                    -- Trigger the trash deletion event and notify
                    TriggerEvent('cools-garbage:client:delete', 'trash_can')
                    lib.notify({
                        title = 'Trash Can',
                        description = 'Will be deleted after 5 minutes.',
                        type = 'info',
                        icon = 'fa-solid fa-clock'
                    })
                end
            }
        })
    end
end)


local selectedItem = nil

RegisterNetEvent('cools-garbage:client:delete')
AddEventHandler('cools-garbage:client:delete', function()
    RSGCore.Functions.GetPlayerData(function(PlayerData)
        if PlayerData.items == nil then 
            -- Register and show empty inventory menu
            lib.registerContext({
                id = 'empty_trash_menu',
                title = 'Trash Can',
                options = {
                    {
                        title = '| Trash Can |',
                        description = 'No items in inventory.',
                        disabled = true
                    }
                }
            })
            lib.showContext('empty_trash_menu')
        else
            local menuOptions = {
                {
                    title = '| Trash Can |',
                    disabled = true
                }
            }

            -- Add inventory items to menu
            for k, v in pairs(PlayerData.items) do
                if PlayerData.items[k].amount > 0 and PlayerData.items[k].type == "item" then
                    menuOptions[#menuOptions + 1] = {
                        title = PlayerData.items[k].label,
                        description = "In inventory: " .. PlayerData.items[k].amount,
                        icon = "nui://rsg-inventory/html/images/" .. PlayerData.items[k].image,
                        onSelect = function()
                            TriggerEvent('cools-garbage:client:showRemoveAmountMenu', PlayerData.items[k])
                        end,
                        metadata = {
                            { label = 'Amount', value = PlayerData.items[k].amount }
                        }
                    }
                end
            end

            -- Add return button
            menuOptions[#menuOptions + 1] = {
                title = '⬅ Return',
                icon = 'arrow-left',
                onSelect = function()
                    TriggerEvent('cools-garbage:client:delete')
                end
            }

            -- Register and show the menu
            lib.registerContext({
                id = 'trash_menu',
                title = 'Trash Can',
                options = menuOptions,
                menu = 'trash_menu' -- This allows the menu to refresh when returning
            })

            lib.showContext('trash_menu')
        end
    end, currentvendor)
end)
-- New event to handle amount input
RegisterNetEvent('cools-garbage:client:showRemoveAmountMenu')
AddEventHandler('cools-garbage:client:showRemoveAmountMenu', function(item)
    selectedItem = item -- Store the selected item for later removal
    
    -- Show the input dialog directly instead of a menu first
    local input = lib.inputDialog('Trash Can', {
        {
            type = 'number',
            label = 'Amount to remove',
            description = 'How many ' .. item.label .. ' do you want to remove?',
            icon = 'trash',
            min = 1,
            max = item.amount,
            default = 1,
            required = true
        }
    })

    -- Handle the input result
    if input then
        local quantity = input[1]
        if quantity and quantity > 0 and quantity <= item.amount then
            TriggerServerEvent('cools-garbage:server:removeItem', item.name, quantity)
        else
            lib.notify({
                title = 'Invalid Amount',
                description = 'Please enter a number between 1 and ' .. item.amount,
                type = 'error'
            })
        end
    end
    
    selectedItem = nil -- Reset the selected item
end)
lib.registerContext({
    id = 'empty_trash_menu',
    title = 'Trash Can',
    options = {
        {
            title = '| Trash Can |',
            description = 'No items in inventory.',
            disabled = true
        }
    }
})

-- New event to handle item removal based on the specified amount
RegisterNetEvent('cools-garbage:client:removeItem')
AddEventHandler('cools-garbage:client:removeItem', function()
    if selectedItem then -- Check if selectedItem is not nil
        local name = selectedItem.name -- Get the name of the selected item
        local amount = selectedItem.amount -- Get the amount of the selected item

        local howmany = exports['rsg-input']:ShowInput({
            header = "Enter how many " .. RSGCore.Shared.Items[name].label .. " you want to remove (In inventory: " .. amount .. ")",
            submitText = "Remove",
            inputs = {
                { text = "Amount:", name = "qt", type = "number", min = 1, max = amount } -- Restrict the input to be between 1 and the current amount
            },
        })

        if howmany ~= nil then
            local quantity = tonumber(howmany.qt)
            if quantity and quantity > 0 then
                TriggerServerEvent('cools-garbage:server:removeItem', name, quantity) -- Send the item and quantity to the server for removal
            else
                RSGCore.Functions.Notify('Invalid amount. Please enter a valid number greater than 0.', 'error')
            end
        end
        selectedItem = nil -- Reset the selectedItem after handling the removal
    else
        RSGCore.Functions.Notify('No item selected.', 'error')
    end
end)

-- ... (Remaining code)

function getMenuTitle(menuid)
    for k,v in pairs(Config.trashLocations)  do
        if menuid == v.name then
            return v.name
        end
    end
    -- If the menuid doesn't match any trash locations, return a default value or an empty string.
    return "Trash Can" -- Replace "Default Title" with your preferred default title.
end


-- New event to handle amount input
RegisterNetEvent('cools-garbage:client:showRemoveAmountMenu')
AddEventHandler('cools-garbage:client:showRemoveAmountMenu', function(item)
    selectedItem = item -- Store the selected item for later removal
    
    -- Show input dialog
    local input = lib.inputDialog('Remove ' .. RSGCore.Shared.Items[item.name].label, {
        {
            type = 'number',
            label = 'Amount to remove',
            description = 'Enter amount (max: ' .. item.amount .. ')',
            min = 1,
            max = item.amount,
            default = 1,
            required = true
        }
    })

    if input then
        local quantity = input[1]
        if quantity and quantity > 0 then
            TriggerServerEvent('cools-garbage:server:removeItem', item.name, quantity)
        else
            lib.notify({
                title = 'Error',
                description = 'Invalid amount. Please enter a valid number greater than 0.',
                type = 'error'
            })
        end
    end
    selectedItem = nil
end)

function getMenuTitle(menuid)
    for k,v in pairs(Config.trashLocations) do
        if menuid == v.name then
            return v.name
        end
    end
    return "Trash Can"
end




