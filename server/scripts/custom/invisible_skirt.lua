
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
    15:belt,
    16:weapon,
    17:lamp/shield,
    18:arrow/bolt,
]]
--load json file of every vanilla armor/clothing item in the game
local clothing_armor_parts_list = jsonInterface.load("custom/clothing_armor_parts_REFORMAT_TEST.json")
--load bodyparts file
local skin_parts_for_clothing = jsonInterface.load("custom/body_parts_for_pants_greaves.json")
--helmet file
local helmets_list = jsonInterface.load("custom/helmets.json")

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

local function is_boot(refId)
    local parts = clothing_armor_parts_list[refId]
    if not parts then
        -- tes3mp.LogAppend(enumerations.log.INFO, "------------------------- " .. "refid was not found in the clothing_armor_parts_list")
        return false -- refId not found in clothing_armor_parts_list
    end

    for _, part in pairs(parts) do
        if part.partType == "18" or part.partType == "17" then -- Compare as strings
            -- tes3mp.LogAppend(enumerations.log.INFO, "------------------------- " .. "refid was found in the clothing_armor_parts_list")
            return true -- Found partType "18" or "17"
        end
    end

    -- tes3mp.LogAppend(enumerations.log.INFO, "------------------------- " .. "refid was found but no matching partType")
    return false -- No matching partType found
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

    tableHelper.print(Players[pid].data.inventory[item_index])

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

            --TODO try using permanentRecords to fix the ghost dupe bug...
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
                tes3mp.LogAppend(enumerations.log.INFO, "------------------------- " .. "pants")
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
                tes3mp.LogAppend(enumerations.log.INFO, "------------------------- " .. "greaves")
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
                tes3mp.LogAppend(enumerations.log.INFO, "------------------------- " .. "player was wearing boots or shoes")
                if Players[pid].data.equipment[2].refId ~= "" or Players[pid].data.equipment[9].refId ~= "" then
                    -- tes3mp.LogAppend(enumerations.log.INFO, "------------------------- " .. "player was wearing pants or greaves")
                    -- tes3mp.LogAppend(enumerations.log.INFO, "------------------------- " .. "Players[pid].data.equipment[7].refId: " .. tostring(Players[pid].data.equipment[7].refId))
                    tableHelper.print(clothing_armor_parts_list[Players[pid].data.equipment[7].refId])

                    if logicHandler.GetRecordTypeByRecordId(Players[pid].data.equipment[7].refId) == "armor" or is_boot(Players[pid].data.equipment[7].refId) then
                        -- tes3mp.LogAppend(enumerations.log.INFO, "------------------------- " .. "player was wearing BOOTS")
                        bootParts = get_parts(checkRecordStore(pid, Players[pid].data.equipment[7].refId, armorStore))
                        if logicHandler.IsGeneratedRecord(skirt_refid) then
                            mergeParts(bootParts, clothingStore.data.generatedRecords[skirt_refid].parts, true)
                            -- tes3mp.LogAppend(enumerations.log.INFO, "------------------------- " .. "skirt_refid was a generated record and parts were merged")
                        else
                            mergeParts(bootParts, clothingStore.data.generatedRecords[new_generated_id].parts, true)
                            clothingStore.data.generatedRecords[new_generated_id].baseId = skirt_refid
                            if add_skirt == false then add_skirt = true end
                            -- tes3mp.LogAppend(enumerations.log.INFO, "------------------------- " .. "skirt_refid was NOT a generated record and parts were merged to a newly created gen record")
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

            -- clothingStore:SaveGeneratedRecords(clothingStore.data.generatedRecords)
            -- clothingStore:LoadRecords(pid, clothingStore.data.generatedRecords, tableHelper.getArrayFromIndexes(clothingStore.data.generatedRecords))

            tes3mp.ClearRecords()
            tes3mp.SetRecordType(enumerations.recordType.CLOTHING)
            packetBuilder.AddClothingRecord(new_generated_id, clothingStore.data.generatedRecords[new_generated_id])
            tes3mp.SendRecordDynamic(pid, true, false)

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

local function make_helmet_invisible(pid)
    -- Check if the player is wearing a helmet
    if Players[pid].data.equipment[0].refId ~= "" then
        local helmet_refId = Players[pid].data.equipment[0].refId
        local armorStore = RecordStores["armor"]
        local equip_helmet = false
        local generated_record
        local new_generated_id

        -- Look up the helmet in the helmets_list
        local helmet_data = helmets_list[helmet_refId]
        -- if not helmet_data then
        --     tes3mp.MessageBox(pid, -1, "Helmet data not found in helmets_list.")
        --     -- return
        -- end

        -- Check if the helmet is already a generated record
        if not logicHandler.IsGeneratedRecord(helmet_refId) and helmet_data and helmet_data.AODT then
            new_generated_id = armorStore:GenerateRecordId()
            armorStore.data.generatedRecords[new_generated_id] = {
                name = helmet_data.FNAM,
                subtype = 0,
                icon = helmet_data.ITEX,
                model = helmet_data.MODL,
                enchantmentId = helmet_data.ENAM or nil,
                health = helmet_data.AODT.durability,
                armorRating = helmet_data.AODT.armor_rating,
                value = helmet_data.AODT.value,
                weight = helmet_data.AODT.weight,
                enchantmentCharge = helmet_data.AODT.enchant_points
            }
            helmet_refId = new_generated_id
            equip_helmet = true
            -- Players[pid].data.customVariables.setHelmetToggle = true
            Players[pid].data.customVariables.helmetToggle = true
            generated_record = new_generated_id
            Players[pid].data.customVariables.savedBaseId = Players[pid].data.equipment[0].refId
            tes3mp.LogAppend(enumerations.log.INFO, "------------------------- " .. " debug 1")
            tes3mp.PlaySpeech(pid, "fx\\item\\armrliton.wav")
        else
            generated_record = armorStore.data.generatedRecords[Players[pid].data.equipment[0].refId] --TODO use player variable to store record on login...
            -- Modify the existing generated record
            if generated_record and generated_record.baseId and not Players[pid].data.customVariables.helmetToggle then
                Players[pid].data.customVariables.savedBaseId = generated_record.baseId
                local helmet_data = helmets_list[generated_record.baseId]
                tes3mp.LogAppend(enumerations.log.INFO, "------------------------- " .. " debug 2")
                if not helmet_data and generated_record.baseId then
                    helmet_data = helmets_list[armorStore.data.generatedRecords[generated_record.baseId].baseId]
                    Players[pid].data.customVariables.savedBaseId = armorStore.data.generatedRecords[generated_record.baseId].baseId
                    tes3mp.LogAppend(enumerations.log.INFO, "------------------------- " .. "helmet_data was set to the baseId of: " .. tostring(armorStore.data.generatedRecords[generated_record.baseId]) .. "which was: " .. tostring(armorStore.data.generatedRecords[generated_record.baseId].baseId))
                end
                if helmet_data and helmet_data.AODT then
                  tes3mp.LogAppend(enumerations.log.INFO, "------------------------- " .. " debug 3")
                    Players[pid].data.customVariables.helmetToggle = true
                    generated_record.baseId = nil
                    generated_record.icon = helmet_data.ITEX
                    generated_record.model = helmet_data.MODL
                    generated_record.health = helmet_data.AODT.durability
                    generated_record.armorRating = helmet_data.AODT.armor_rating
                    generated_record.value = helmet_data.AODT.value
                    generated_record.weight = helmet_data.AODT.weight
                    generated_record.enchantmentCharge = helmet_data.AODT.enchant_points
                    tes3mp.PlaySpeech(pid, "fx\\item\\armrliton.wav")

                end
            else
                if Players[pid].data.customVariables.helmetToggle then
                    tes3mp.LogAppend(enumerations.log.INFO, "------------------------- " .. " debug 4")
                    Players[pid].data.customVariables.helmetToggle = false
                    generated_record.baseId = Players[pid].data.customVariables.savedBaseId
                    tes3mp.PlaySpeech(pid, "fx\\item\\armrlitoff.wav")
                end

                -- if generated_record.parts then
                --     generated_record.parts = nil
                -- end
            end
        end

        -- Save and load the modified record
        -- armorStore:SaveGeneratedRecords(armorStore.data.generatedRecords)
        -- armorStore:LoadRecords(pid, armorStore.data.generatedRecords, tableHelper.getArrayFromIndexes(armorStore.data.generatedRecords))

        -- if Players[pid].data.equipment[0] and Players[pid].data.equipment[0].refId == "" then
        --     Players[pid]:LoadEquipment()
        --     if Players[pid].data.equipment[0].refId == "" then
        --         tes3mp.MessageBox(pid, -1, "You are not wearing a helmet.")
        --         return
        --     end
        -- end
        tes3mp.ClearRecords()
        tes3mp.SetRecordType(enumerations.recordType.ARMOR)
        packetBuilder.AddArmorRecord(Players[pid].data.equipment[0].refId, armorStore.data.generatedRecords[Players[pid].data.equipment[0].refId])
        tes3mp.SendRecordDynamic(pid, true, false)

        -- Equip the modified helmet
        if equip_helmet then
            local old_helmet = Players[pid].data.equipment[0].refId
            local charge = Players[pid].data.equipment[0].charge or -1
            local enchantmentCharge = Players[pid].data.equipment[0].enchantmentCharge or -1

            -- tes3mp.UnequipItem(pid, 0)
            inventory_packet_handler(pid, old_helmet, enumerations.inventory.REMOVE)
            Players[pid].data.equipment[0].refId = new_generated_id
            inventory_packet_handler(pid, new_generated_id, enumerations.inventory.ADD, true)
            tes3mp.EquipItem(pid, 0, new_generated_id, 1, charge, enchantmentCharge)
            tes3mp.SendEquipment(pid)
        end

        -- Update the player model
        tes3mp.SendBaseInfo(pid)
        armorStore:QuicksaveToDrive()
        Players[pid]:QuicksaveToDrive()

        -- tes3mp.MessageBox(pid, -1, "Your helmet has been made invisible.")
    else
        tes3mp.MessageBox(pid, -1, "You are not wearing a helmet.")
    end
end

customCommandHooks.registerCommand("hh", make_helmet_invisible)

customEventHooks.registerHandler("OnPlayerItemUse", OnPlayerItemUseHandler)
customEventHooks.registerHandler("OnServerPostInit", OnServerPostInitHandler)
customEventHooks.registerHandler("OnPlayerAuthentified", OnPlayerAuthentifiedHandler)
