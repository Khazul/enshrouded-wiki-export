require("table")
local jsonEnc = require("json_encoder")
local translations = require("translations")
if not loader.features.export then
	return
end

local function extractDamageDistribution(damageDistribution, item)
	item.damage = { __type = "object" }
	item.materialDamage = { __type = "object" }
	item.otherDamage = { __type = "object" }
	for t, a in pairs(damageDistribution) do
		if t == "woodDamage" or t == "stoneDamage" or t == "metalDamage" then
			if a > 0 then
				item.materialDamage[t] = a
			end
		elseif t == "healing" or t == "explosionDamage" then
			if a > 0 then
				item.otherDamage[t] = a
			end
		else
			if a > 0 then
				item.damage[t] = a
			end
		end
	end
end

local function extractDamageSetup(damageSetup, item)
	if damageSetup then
		item.dmgMod = damageSetup.dmgMod
		item.speedMod = damageSetup.speedMod
		if (damageSetup.isSet) then
			extractDamageDistribution(damageSetup.distribution, item)
		end
	end
end

local function extractArmorSetup(armorSetup, item)
	if armorSetup and armorSetup.isSet then
		item.armor = { __type = "object" }
		item.armorQuality = armorSetup.quality
		for t, a in pairs(armorSetup.distribution) do
			if a > 0 then
				item.armor[t] = a
			end
		end
	end
end

local function extractBlockSetup(blockSetup, item)
	if blockSetup and blockSetup.isSet then
		item.blockQuality = blockSetup.quality
	end
end	

local function extractBuff(appliedBuff, item)
	if appliedBuff then
		print("  Buff" .. appliedBuff)
		local buffInfo = game.assets.get_resource(appliedBuff, "keen::BuffType")
		if buffInfo then
			---@type keen.BuffType
			local buffData = buffInfo.data
			item.buff = { __type = "object" }
			item.buff._guid = appliedBuff
			item.buff.typeId = buffData.buffTypeId.value
			item.buff.slot = buffData.slot
			item.buff.name = translations.translateGuid(buffData.name)
			item.buff.desc = translations.translateGuid(buffData.description)
			item.buff.applyType = buffData.applyType
			item.buff.defaultLifetime = buffData.defaultLifeTime.value
		end
	end
end	

local function extractDebuff(appliedBuff, item)
end	

local function extractStackSize(itemData, item)
end

local function extractEquipmentSetup(equipmentSetup, item)
	if equipmentSetup then
		item.slot = equipmentSetup.slot
		extractBuff(equipmentSetup.appliedBuff, item)
		extractDebuff(equipmentSetup.appliedDebuff, item)
	end
end

local function extractLevelRange(levelRange, item)
	if levelRange then
		item.minLevel = levelRange.minLevel
		item.maxLevel = levelRange.maxLevel
	end
end

local function extractUiValues(uiValues, item)
	if uiValues then
		item.uiValues = {}
		for _, value in ipairs(uiValues) do
			local text = translations.translateHash(value.locaId.value)
			table.insert(item.uiValues, { __type = "object", _id = value.locaId.value, text = text, format = value.valueFormat, value = value.value })
		end
	end
end

local function extractWeapons(itemData, item)
	item.genRarity = itemData.generateRarity
	item.disableRarityGeneration = itemData.disableRarityGeneration

	for _, value in pairs(itemData.impactValues) do
		if value.value.type.value == 3902764048 and value.value.valueFormat == "Duration" then
			local locaTag = translations.translateGuid(value.value.locaTag) or "?"
			if value.value.id == "0750bfea-b306-4452-9cec-05bca19e1e33"
				or value.value.id == "51bb9d6e-16cb-4b45-95e1-bf1f2e306586"
				or value.value.id == "fee154e6-8708-47e2-9e9c-8ab3f7d009c2"
				or value.value.id == "0750bfea-b306-4452-9cec-05bca19e1e33" then
				item.actionRate = value.value.value
				item.actionTag  = locaTag
			end
		end
	end

	extractDamageSetup(itemData.damageSetup, item)
	extractArmorSetup(itemData.armorSetup, item)
	extractEquipmentSetup(itemData.equipment, item)

	item.perks = {}
	for _, perkId in ipairs(itemData.perkReferences) do
		local perkInfo = game.assets.get_resource(perkId, "keen::Perk")
		if (perkInfo) then
			---@type keen.Perk
			local perkData = perkInfo.data
			local perkEntry = {
				__type = "object",
				guid = perkId,
				debugName = perkData.debugName,
			}
			table.insert(item.perks, perkEntry)
		end
	end
end

local function extractAmmunition(itemData, item)
	return extractWeapons(itemData, item)
end

local function extractEquipment(itemData, item)
	extractEquipmentSetup(itemData.equipment, item)
	extractArmorSetup(itemData.armorSetup, item)
	extractBlockSetup(itemData.blockSetup, item)
end

local function extractConsumables(itemData, item)
	extractEquipmentSetup(itemData.equipment, item)
end

local categories = {}


---@type keen.ItemRegistryResource
local itemRegistry = game.assets.get_resources_by_type("keen::ItemRegistryResource")[1].data

for _, itemRef in ipairs(itemRegistry.itemRefs) do
	local itemInfo = game.assets.get_resource(itemRef, "keen::ItemInfo")

	if not itemInfo then
		warn("item not found for ref " .. itemRef)
	else
		local item = { __type = "object" }

		--- @type keen.ItemInfo
		local itemData = itemInfo.data

		if itemData then
			print("Processing: " .. itemData.debugName)

			item._id = itemData.itemId.value
			item._guid = itemData.objectId
			item.debugName = itemData.debugName
			item.name = translations.translateGuid(itemData.name) or itemData.debugName
			item.description = translations.translateGuid(itemData.description) or ""
			item.rarity = itemData.rarity
			item.category = itemData.category
			if not categories[item.category] then
				categories[item.category] = {}
			end
			table.insert(categories[item.category], item)

			extractUiValues(itemData.uiValues, item)
			extractLevelRange(itemData.itemLevelRange, item)

			if item.category == "Weapons" then
				extractWeapons(itemData, item)
			elseif item.category == "Ammunition" then
				extractAmmunition(itemData, item)
			elseif item.category == "Equipment" then
				extractEquipment(itemData, item)
			elseif item.category == "Consumables" then
				extractConsumables(itemData, item)
			end
		end
	end
end

local perkRegistry = game.assets.get_resources_by_type("keen::PerkCollectionResource")[1].data

local perks = {}
local category = "Perks"
if not categories[category] then
	categories[category] = perks
end

for _, perkRef in ipairs(perkRegistry.perks) do
	local perkInfo = game.assets.get_resource(perkRef, "keen::Perk")

	if (perkInfo) then
		---@type keen.Perk
		local perkData = perkInfo.data
		local perkEntry = {
			__type = "object",
			_guid = perkRef,
			debugName = perkData.debugName,
			name = translations.translateGuid(perkData.name) or perkData.debugName
		}
		if perkData.description then
			perkEntry.description = translations.translateGuid(perkData.description) or ""
		else
			perkEntry.description = ""
		end

		extractDamageSetup(perkData.damageSetup, perkEntry)
		extractArmorSetup(perkData.armorSetup, perkEntry)

		table.insert(perks, perkEntry)
	end
end


-- Export categories to JSON files
for category, items in pairs(categories) do
	print(string.format('exporting category "%s"', category))
	local json = jsonEnc.encode(items, "  ", false)
	local filename = string.format("%s.json", category:lower())
	io.export(filename, json)
end

translations.export("translations.csv")
