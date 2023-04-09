-- Author: Fetty42
-- Date: 09.04.2023
-- Version: 1.0.1.0

local dbPrintfOn = false

local function dbPrintf(...)
	if dbPrintfOn then
    	print(string.format(...))
	end
end

local function Printf(...)
    	print(string.format(...))
end

-- **************************************************

StorageLimit = {}; -- Class

StorageLimit.timeOfLastNotification = {}
StorageLimit.maxStoredFillTypesDefault = 5
StorageLimit.knownStorageStations = {}	-- StationName = maxStoredFillTypes
StorageLimit.initDone = false


addModEventListener(StorageLimit)

function StorageLimit:loadMap(name)
	dbPrintf("call StorageLimit:loadMap");
	UnloadingStation.getFreeCapacity = Utils.overwrittenFunction(UnloadingStation.getFreeCapacity, StorageLimit.unloadingStation_getFreeCapacity)	
end;


-- function StorageLimit:postLoadMap()
-- 	dbPrintf("call StorageLimit:postLoadMap");
-- 	-- StorageLimit:getAllStorageStations()
-- end;
-- FSBaseMission.onFinishedLoading = Utils.appendedFunction(FSBaseMission.onFinishedLoading, StorageLimit.postLoadMap);


function StorageLimit:update(dt)
	-- dbPrintf("call StorageLimit:update")
	if g_currentMission:getIsClient() and not StorageLimit.initDone then
		StorageLimit.initDone = true
		StorageLimit:getAllStorageStations()
	end
end


function StorageLimit:getAllStorageStations()
	dbPrintf("call StorageLimit:getAllStorageStations()");

	for _, station in pairs(g_currentMission.storageSystem.unloadingStations) do
	
		local placeable = station.owningPlaceable
		dbPrintf("  - Station: getName=%s | typeName=%s | categoryName=%s | isSellingPoint=%s | hasStoragePerFarm=%s | ownerFarmId=%s",
			placeable:getName(), tostring(placeable.typeName), tostring(placeable.storeItem.categoryName), tostring(station.isSellingPoint), station.hasStoragePerFarm, placeable.ownerFarmId)

		if StorageLimit:isStationRelevant(station) then
			dbPrintf("    --> is relevant StorageStation")
		end
	end
end


function StorageLimit:isStationRelevant(station)
	-- dbPrintf("call StorageLimit:isStationRelevant()");
	local placeable = station.owningPlaceable
	
	-- dbPrintf("  - Station: getName=%s | typeName=%s | categoryName=%s | isSellingPoint=%s | hasStoragePerFarm=%s | ownerFarmId=%s",
	-- placeable:getName(), tostring(placeable.typeName), tostring(placeable.storeItem.categoryName), tostring(station.isSellingPoint), station.hasStoragePerFarm, placeable.ownerFarmId)

	-- ~= PRODUCTIONPOINTS, ANIMALPENS
	-- == SILOS
	-- getName=Railroad Silo North | typeName=silo | categoryName=PLACEABLEMISC | isSellingPoint=nil | hasStoragePerFarm=true | ownerFarmId=0
	-- getName=Farma 400 + Obi 1000 | typeName=silo | categoryName=SILOS | isSellingPoint=nil | hasStoragePerFarm=false | ownerFarmId=1			--> is own relevant StorageStation
	-- getName=Medium Petrol Tank | typeName=silo | categoryName=DIESELTANKS | isSellingPoint=nil | hasStoragePerFarm=false | ownerFarmId=1 	--> is own relevant StorageStation
	-- getName=Liquidmanure Tank | typeName=silo | categoryName=SILOS | isSellingPoint=nil | hasStoragePerFarm=false | ownerFarmId=1 			--> is own relevant StorageStation

	if (station.isSellingPoint == nil or station.isSellingPoint == false) and placeable.ownerFarmId == g_currentMission:getFarmId()
		and (placeable.storeItem.categoryName == "SILOS" or placeable.storeItem.categoryName == "STORAGES") and placeable.typeName == "silo" then
		-- placeable.storeItem.categoryName ~= "ANIMALPENS" and placeable.storeItem.categoryName ~= "PRODUCTIONPOINTS"
		-- dbPrintf("    --> is own relevant StorageStation")
		return true
	end
	
	if station.isSellingPoint == nil and placeable.storeItem.categoryName == "PLACEABLEMISC" and station.hasStoragePerFarm then
		-- dbPrintf("    --> is general relevant StorageStation")
		-- print("")
		-- print("unloadingStations: " .. station.owningPlaceable:getName())
		-- print("**** DebugUtil.printTableRecursively() **********************************************************************************************")
		-- DebugUtil.printTableRecursively(station,".",0,0)
		-- print("**** End DebugUtil.printTableRecursively() ******************************************************************************************")
		return true
	end
	return false
end


function StorageLimit.unloadingStation_getFreeCapacity(station, superFunc, fillTypeIndex, farmId)
	-- dbPrintf("call StorageLimit:unloadingStation_getFreeCapacity")
	-- dbPrintf("call StorageLimit:unloadingStation_getFreeCapacity: station=%s | fillTypeIndex=%s | farmId=%s", station, fillTypeIndex, farmId)

	-- don't handle
	if not StorageLimit:isStationRelevant(station) or fillTypeIndex == nil or farmId == nil then
		return superFunc(station, fillTypeIndex, farmId)
	end

	-- info output, but not every call
	local withOutput = false
	if StorageLimit.timeOfLastNotification[farmId] == nil
	or StorageLimit.timeOfLastNotification[farmId][station] == nil
	or StorageLimit.timeOfLastNotification[farmId][station][fillTypeIndex] == nil
	or g_currentMission.environment.dayTime/(1000*60) > StorageLimit.timeOfLastNotification[farmId][station][fillTypeIndex] + 6
	then
		-- dbPrintf(string.format("  dayTime=%s", tostring(g_currentMission.environment.dayTime/(1000*60))))
		if StorageLimit.timeOfLastNotification[farmId] == nil then
			StorageLimit.timeOfLastNotification[farmId] = {}
		end
		if StorageLimit.timeOfLastNotification[farmId][station] == nil then
			StorageLimit.timeOfLastNotification[farmId][station] = {}
		end
		StorageLimit.timeOfLastNotification[farmId][station][fillTypeIndex] = g_currentMission.environment.dayTime/(1000*60)
		-- dbPrintf(tostring(StorageLimit.timeOfLastNotification[farmId][station][fillTypeIndex]))
		withOutput = true
	end

	if withOutput then
		local fillTypeName = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex).name
		dbPrintf("call2 StorageLimit.unloadingStation_getFreeCapacity: station=%s | fillTypeIndex=%s | fillTypeName=%s | farmId=%s",
			tostring(station), tostring(fillTypeIndex), tostring(fillTypeName), tostring(farmId))
		dbPrintf("  Station: getName=%s | typeName=%s | categoryName=%s", station.owningPlaceable:getName(), station.owningPlaceable.typeName, station.owningPlaceable.storeItem.categoryName)
	end

	local maxStoredFillTypes = StorageLimit.maxStoredFillTypesDefault
	if StorageLimit.knownStorageStations[station.owningPlaceable:getName()] == nil then
		Printf("StorageLimit: Unknown storage station '%s'. Set max storage slots to %s", station.owningPlaceable:getName(), StorageLimit.maxStoredFillTypesDefault)
		StorageLimit.knownStorageStations[station.owningPlaceable:getName()] = StorageLimit.maxStoredFillTypesDefault
	else
		maxStoredFillTypes = StorageLimit.knownStorageStations[station.owningPlaceable:getName()]
		if withOutput then
			dbPrintf("  Already known storage station '%s' with %s storage slots", station.owningPlaceable:getName(), maxStoredFillTypes)
		end
	end

	-- Number of stored fill types
	local storedFillTypes = {}
	local countStoredFillTypes = 0
    local countTargetStorages = 0
	for _, targetStorage in pairs(station.targetStorages) do
        if farmId == nil or station:hasFarmAccessToStorage(farmId, targetStorage) then
            countTargetStorages = countTargetStorages + 1

			-- current targetStorage debug output
			-- if withOutput then
			-- 	print("")
			-- 	print("TargetStorage: " .. countTargetStorages)
			-- 	print("**** DebugUtil.printTableRecursively() **********************************************************************************************")
			-- 	DebugUtil.printTableRecursively(targetStorage,".",0,2)
			-- 	print("**** End DebugUtil.printTableRecursively() ******************************************************************************************")
			-- end

			for fillTypeIndex1, _ in pairs(targetStorage.fillTypes) do
				local ftName = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex1).name
				if station:getFillLevel(fillTypeIndex1, farmId) > 0.1 and storedFillTypes[ftName] == nil then
					storedFillTypes[ftName] = true
					countStoredFillTypes = countStoredFillTypes + 1
					if withOutput then
						dbPrintf("  Storage-%s: ftName=%s(%s) | ftFillLevel=%s | countStoredFillTypes=%s", countTargetStorages, ftName, fillTypeIndex1, station:getFillLevel(fillTypeIndex1, farmId), countStoredFillTypes)
					end
				end
			end
		end
	end

    local maxStoredFillTypesOverAll = maxStoredFillTypes + (countTargetStorages-1)*2
	local isFilltypeAlreadyInUse = station:getFillLevel(fillTypeIndex, farmId) > 0.1

	local notificationText = "";
	local callSuperFunction = true
	if isFilltypeAlreadyInUse  then
		-- The storage space for this fill type is already in use
		if countStoredFillTypes <= maxStoredFillTypesOverAll then
			if withOutput then
				dbPrintf("  The filltype is already in use --> Unloading is allowed. Storage slots in use %s/%s", countStoredFillTypes, maxStoredFillTypesOverAll)
				notificationText = string.format(g_i18n:getText("SiloFilltypeLimiting_ExistingFiltype"), countStoredFillTypes, maxStoredFillTypesOverAll)
			end
		else
			notificationText = string.format(g_i18n:getText("SiloFilltypeLimiting_UnloadingNotAllowed"), countStoredFillTypes, maxStoredFillTypesOverAll)
			callSuperFunction = false
		end
	elseif countStoredFillTypes < maxStoredFillTypesOverAll then
		if withOutput then
			dbPrintf("  New filltype and still free storage slots --> Unloading is allowed. Storage slots in use %s/%s", countStoredFillTypes, maxStoredFillTypesOverAll)
			notificationText = string.format(g_i18n:getText("SiloFilltypeLimiting_NewFilltype"), countStoredFillTypes, maxStoredFillTypesOverAll)
		end
	else
		notificationText = string.format(g_i18n:getText("SiloFilltypeLimiting_UnloadingNotAllowed"), countStoredFillTypes, maxStoredFillTypesOverAll)
		callSuperFunction = false
	end

	-- info output, but not every call
	if withOutput and  notificationText ~= "" then
		dbPrintf("  StorageLimit: countTargetStorages=%s | maxStoredFillTypesOverAll=%s | Msg=%s", countTargetStorages, maxStoredFillTypesOverAll, notificationText)
		g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK, notificationText)
	end
	
	if callSuperFunction then
		return superFunc(station, fillTypeIndex, farmId)
	else
    	return 0
	end
end


-- function StorageLimit:onLoad(savegame)end;
-- function StorageLimit:onUpdate(dt)end;
-- function StorageLimit:deleteMap()end;
-- function StorageLimit:keyEvent(unicode, sym, modifier, isDown)end;
-- function StorageLimit:mouseEvent(posX, posY, isDown, isUp, button)end;

