
--script to make a skirt appear invisible when using wizard juice by changing the parts its comprised of to be the same as whatever the player is wearing underneath
--[[player equipment slots

    0:helmet,
    1:cuirass,
    2:greaves,
    3:left pauldron,
    4:right pauldron,
    5:left gauntlet/glove,
    6:right gauntlet/glove,
    7:boots/shoes,
    8:shirt,
    9:pants,
    10:skirt,
    11:robe,
    12:ring,
    13:ring,
    14:amulet,
    16:weapon,
    17:lamp/shield,
    18:arrow/bolt,
]]
--load json file of every vanilla armor/clothing item in the game
local clothing_armor_parts_list = jsonInterface.load("custom/clothing_armor_parts_REFORMAT_TEST.json")
--load bodyparts file
local skin_parts_for_clothing = jsonInterface.load("custom/body_parts_for_pants_greaves.json")

function remove_stank(pid)

    if Players[pid] and Players[pid]:IsLoggedIn() then
        logicHandler.RunConsoleCommandOnPlayer(pid, "removespell, wizard_juice_stank", true)
    end

end

local function OnServerPostInitHandler()

    if not RecordStores["miscellaneous"].data.permanentRecords["skirt_wizard_juice"] then

        RecordStores["miscellaneous"].data.permanentRecords["skirt_wizard_juice"] = {
            name = "Stank Wizard Juice",
            value = 666,
            weight = 0.01,
            icon  = "m\\Misc_Com_Bottle_05.tga",
            model = "m\\Misc_Com_Bottle_05.NIF"
        }
    end

    if not RecordStores["spell"].data.permanentRecords["wizard_juice_stank"] then

		    RecordStores["spell"].data.permanentRecords["wizard_juice_stank"] = {

            name = "Stanky Wizard Juice...",
            cost = 0,
            flags = 0,
            subtype = 4,
            effects = {
             {
              attribute = -1,
              skill = -1,
              area = 0,
              duration = 30,
              id = 27,
              rangeType = 0,
              magnitudeMin = 1,
              magnitudeMax = 1
            }
          }
        }

    		RecordStores["spell"]:Save()
    end
end

local function mergeParts(newParts, finalParts, has_boots_equip)

    if has_boots_equip then
        for i, parts in pairs(newParts) do
            if parts.partType == "15" or parts.partType == "16" then
                newParts[i] = nil
            end
        end
    end

    for i, tempParts in pairs(newParts) do
        for key, parts in pairs(finalParts) do
            if tempParts.partType == parts.partType then
                finalParts[key] = nil
                break
            end
        end
    end

    tableHelper.insertValues(finalParts, newParts)

    tableHelper.cleanNils(finalParts)
end

local function checkRecordStore(pid, refId, recordStore)

    if recordStore.data.permanentRecords[refId] then
        if recordStore.data.permanentRecords[refId].baseId then
            return recordStore.data.permanentRecords[refId].baseId
        end
        if recordStore.data.permanentRecords[refId].parts then
            return recordStore.data.permanentRecords[refId].parts
        end
    end

    if recordStore.data.generatedRecords[refId] then
        if recordStore.data.generatedRecords[refId].baseId then
            return recordStore.data.generatedRecords[refId].baseId
        end
        if recordStore.data.generatedRecords[refId].parts then
            return recordStore.data.generatedRecords[refId].parts
        end
    end

    return refId

end

local function get_parts(parts_OR_baseid)

    if type(parts_OR_baseid) == "table" then
        return tableHelper.deepCopy(parts_OR_baseid)
    else
        return tableHelper.deepCopy(clothing_armor_parts_list[parts_OR_baseid])
    end

end

local function validate_equipment_slots(pid)

    local slots = {2, 7, 9, 10}

    for i, slot in pairs(slots) do

        if not Players[pid].data.equipment[slot] then
            Players[pid].data.equipment[slot] = {
              enchantmentCharge = -1,
              count = 0,
              refId = "",
              charge = -1
            }
        end
    end
end

local function inventory_packet_handler(pid, refId, action, equip_the_item)

    tes3mp.ClearInventoryChanges(pid)
    tes3mp.SetInventoryChangesAction(pid, action)
    local item = {refId = refId, count = 1}
    packetBuilder.AddPlayerInventoryItemChange(pid, item)
    tes3mp.SendInventoryChanges(pid)

    local playerPacket = packetReader.GetPlayerPacketTables(pid, "PlayerInventory")
    -- playerPacket.inventory[1].count = 1
    -- Players[pid]:SaveInventory(playerPacket)
    if action == enumerations.inventory.REMOVE then
        local item_index = inventoryHelper.getItemIndex(Players[pid].data.inventory, refId)
        if Players[pid].data.inventory[item_index].count >= 2 then
            Players[pid].data.inventory[item_index].count = Players[pid].data.inventory[item_index].count - 1
        else
            Players[pid].data.inventory[item_index] = nil
        end
    end
    if action == enumerations.inventory.ADD then

        inventoryHelper.addItem(Players[pid].data.inventory, refId, 1)

        if logicHandler.IsGeneratedRecord(item.refId) then

            local recordStore = logicHandler.GetRecordStoreByRecordId(refId)

            if recordStore ~= nil then
                Players[pid]:AddLinkToRecord(recordStore.storeType, refId)
            end
        end

    end
    -- if action == enumerations.inventory.ADD then
    --     inventoryHelper.addItem(Players[pid].data.inventory, refId, 1)
    -- end
    --
    -- if action == enumerations.inventory.REMOVE then
    --     inventoryHelper.removeExactItem(Players[pid].data.inventory, refId, 1)
    -- end

    --tableHelper.print(Players[pid].data.inventory[item_index])

    --TODO  make a new function for equiping and call it down below..
    if equip_the_item then
        if not tes3mp.HasItemEquipped(pid, refId) then
            tes3mp.EquipItem(pid, 10, refId, 1, playerPacket.inventory[1].charge or -1, playerPacket.inventory[1].enchantmentCharge or -1)
            tes3mp.SendEquipment(pid)
            Players[pid].data.equipment[10] = {
              enchantmentCharge = playerPacket.inventory[1].enchantmentCharge or -1,
              count = 1,
              refId = refId,
              charge = playerPacket.inventory.charge or -1
            }
        end
    end
end

local function OnPlayerItemUseHandler(eventStatus, pid, itemRefId)

    if itemRefId == "skirt_wizard_juice" then

        validate_equipment_slots(pid)

        --if player is wearing a skirt
        if Players[pid].data.equipment[10].refId ~= "" then
            local greavesParts = {}
            local pantsParts = {}
            local bootParts = {}
            local armorStore = RecordStores["armor"]
            local clothingStore = RecordStores["clothing"]
            local add_skirt = false


            local skirt_refid = Players[pid].data.equipment[10].refId
            if not logicHandler.IsGeneratedRecord(Players[pid].data.equipment[10].refId) then
                new_generated_id = clothingStore:GenerateRecordId()
                clothingStore.data.generatedRecords[new_generated_id] = {
                    parts = {},
                    baseId = ""
                }
            end

            -- if player is wearing pants
            if Players[pid].data.equipment[9].refId ~= "" then
                -- tes3mp.LogAppend(enumerations.log.INFO, "------------------------- " .. "pants")
                pantsParts = get_parts(checkRecordStore(pid, Players[pid].data.equipment[9].refId, clothingStore))
                if logicHandler.IsGeneratedRecord(skirt_refid) then
                    clothingStore.data.generatedRecords[skirt_refid].parts = pantsParts
                else
                    clothingStore.data.generatedRecords[new_generated_id].parts = pantsParts
                    clothingStore.data.generatedRecords[new_generated_id].baseId = skirt_refid
                    if add_skirt == false then add_skirt = true end
                end
            end

            --if player is wearing greaves
            if Players[pid].data.equipment[2].refId ~= "" then
                -- tes3mp.LogAppend(enumerations.log.INFO, "------------------------- " .. "greaves")
                greavesParts = get_parts(checkRecordStore(pid, Players[pid].data.equipment[2].refId, armorStore))
                if logicHandler.IsGeneratedRecord(skirt_refid) then
                    --if player is not wearing pants just use the greaves parts ELSE merge in the greaves parts over the pants parts
                    if Players[pid].data.equipment[9].refId == "" then
                        clothingStore.data.generatedRecords[skirt_refid].parts = greavesParts
                    else
                        clothingStore.data.generatedRecords[skirt_refid].parts = pantsParts
                        mergeParts(greavesParts, clothingStore.data.generatedRecords[skirt_refid].parts)
                    end
                else --skirt was not an existing generated record so add the parts to a newly created record and use the skirts refId as the baseId
                    if Players[pid].data.equipment[9].refId == "" then
                        clothingStore.data.generatedRecords[new_generated_id].parts = greavesParts
                    else
                        clothingStore.data.generatedRecords[new_generated_id].parts = pantsParts
                        mergeParts(greavesParts, clothingStore.data.generatedRecords[new_generated_id].parts)
                    end
                    clothingStore.data.generatedRecords[new_generated_id].baseId = skirt_refid
                    if add_skirt == false then add_skirt = true end
                end
            end

            --if player is wearing pants or greaves and also boots then add bootParts so the boot ankles show on the skirt
            if Players[pid].data.equipment[7].refId ~= "" then
                if Players[pid].data.equipment[2].refId ~= "" or Players[pid].data.equipment[9].refId ~= "" then
                    if logicHandler.GetRecordTypeByRecordId(Players[pid].data.equipment[7].refId) == "armor" then
                        bootParts = get_parts(checkRecordStore(pid, Players[pid].data.equipment[7].refId, armorStore))
                        if logicHandler.IsGeneratedRecord(skirt_refid) then
                            mergeParts(bootParts, clothingStore.data.generatedRecords[skirt_refid].parts, true)
                        else
                            mergeParts(bootParts, clothingStore.data.generatedRecords[new_generated_id].parts, true)
                            clothingStore.data.generatedRecords[new_generated_id].baseId = skirt_refid
                            if add_skirt == false then add_skirt = true end
                        end
                    end
                end
            end

            --if player is NOT wearing pants or greaves then add bodyparts so they appear naked with the skirt on
            if Players[pid].data.equipment[2].refId == "" and Players[pid].data.equipment[9].refId == "" then
                local race = tes3mp.GetRace(pid)
                local skin_parts = tableHelper.deepCopy(skin_parts_for_clothing[race])
                if logicHandler.IsGeneratedRecord(skirt_refid) then
                    clothingStore.data.generatedRecords[skirt_refid].parts = skin_parts
                    if Players[pid].data.equipment[7].refId ~= "" then
                        bootParts = get_parts(checkRecordStore(pid, Players[pid].data.equipment[7].refId, armorStore))
                        mergeParts(bootParts, clothingStore.data.generatedRecords[skirt_refid].parts, true)
                    end
                else
                    clothingStore.data.generatedRecords[new_generated_id].parts = skin_parts
                    -- clothingStore.data.generatedRecords[new_generated_id].parts = skin_parts_for_clothing[race]
                    if Players[pid].data.equipment[7].refId ~= "" then
                        bootParts = get_parts(checkRecordStore(pid, Players[pid].data.equipment[7].refId, armorStore))
                        mergeParts(bootParts, clothingStore.data.generatedRecords[new_generated_id].parts, true)
                    end
                    clothingStore.data.generatedRecords[new_generated_id].baseId = skirt_refid
                    if add_skirt == false then add_skirt = true end
                end
            end

            clothingStore:SaveGeneratedRecords(clothingStore.data.generatedRecords)
            clothingStore:LoadRecords(pid, clothingStore.data.generatedRecords, tableHelper.getArrayFromIndexes(clothingStore.data.generatedRecords))

            if add_skirt then
                -- tes3mp.UnequipItem(pid, 10)
                inventory_packet_handler(pid, skirt_refid, enumerations.inventory.REMOVE)
                inventory_packet_handler(pid, new_generated_id, enumerations.inventory.ADD)
            end

            logicHandler.RunConsoleCommandOnPlayer(pid, "PlaySound3DVP, drown, 1.0, 1.0", true)
            logicHandler.RunConsoleCommandOnPlayer(pid, "AddSpell, wizard_juice_stank", true)
            local stank_timer = tes3mp.CreateTimerEx("remove_stank", time.seconds(10.00), "i", pid)
      			tes3mp.StartTimer(stank_timer)

            -- inventoryHelper.removeExactItem(Players[pid].data.inventory, "skirt_wizard_juice", 1)
            -- inventory_packet_handler(pid, "skirt_wizard_juice", enumerations.inventory.REMOVE)
            logicHandler.RunConsoleCommandOnPlayer(pid, "removeItem, skirt_wizard_juice, 1", true)
            logicHandler.RunConsoleCommandOnPlayer(pid, "togglemenus", false)
            logicHandler.RunConsoleCommandOnPlayer(pid, "togglemenus", false)
            tes3mp.MessageBox(pid, -1, "Your skirt has been saturated with strange smelling wizard juice.")

            tes3mp.SendBaseInfo(pid) --updates the player model so we see the new skirt without changing views if the player is in third person...
            clothingStore:QuicksaveToDrive()
            Players[pid]:QuicksaveToDrive() --TODO test like this
        else
            tes3mp.MessageBox(pid, -1, "Equip a skirt.")
        end
    end
end

customEventHooks.registerHandler("OnPlayerItemUse", OnPlayerItemUseHandler)
customEventHooks.registerHandler("OnServerPostInit", OnServerPostInitHandler)
