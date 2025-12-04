require("table")
local jsonEnc = require("json_encoder")
local translations = require("translations")

if not loader.features.export then
	return
end

local categories = {}
local itemsById = {}
local itemsByGuid = {}
local iconInfo = {}
local workshopsById = {}
local weaponCategoriesByGuid = {}
local itemTagsByGuid = {}
local inputCategoriesById = {}
local recipesById = {}
local perksByGuid = {}

local function exportIconTexture(texture, filename)
	if texture then
		local content = game.assets.get_content(texture.data)
		if content then
			local buf = content:read_data()
			local textureImage = image.decode_texture(buf, texture.format, texture.size.x, texture.size.y)
			local pngBuffer = image.encode(textureImage, "png")
			local path = "icons\\" .. filename .. ".png"
			io.export(path, pngBuffer)
			return path
		end
	end
	return nil
end

local function cleanFilename(filename)
	return string.gsub(filename, "[%s%(%)\"%[%]%'%`_<>%*\\/]+", "")
end

local function extractDamageDistribution(damageDistribution, item)
	if damageDistribution then
		local damage = { __type = "object" }
		local materialDamage = { __type = "object" }
		local otherDamage = { __type = "object" }
		for t, a in pairs(damageDistribution) do
			if t == "woodDamage" or t == "stoneDamage" or t == "metalDamage" then
				if a > 0 then
					materialDamage[t] = a
				end
			elseif t == "healing" or t == "explosionDamage" then
				if a > 0 then
					otherDamage[t] = a
				end
			else
				if a > 0 then
					damage[t] = a
				end
			end
		end
		if table.count(damage) > 1 then
			item.damage = damage
		end
		if table.count(materialDamage) > 1 then
			item.materialDamage = materialDamage
		end
		if table.count(damage) > 1 then
			item.otherDamage = otherDamage
		end
	end
end

local function extractDamageSetup(damageSetup, item, mods)
	if damageSetup then
		if mods then
			item.dmgMod = damageSetup.dmgMod
			item.speedMod = damageSetup.speedMod
		end
		if (damageSetup.isSet) then
			extractDamageDistribution(damageSetup.distribution, item)
		end
	end
end

local function extractArmorSetup(armorSetup, item, mods)
	if armorSetup and armorSetup.isSet then
		local armor = { __type = "object" }
		if mods then
			item.armorQuality = armorSetup.quality
		end
		for t, a in pairs(armorSetup.distribution) do
			if a > 0 then
				armor[t] = a
			end
		end
		if table.count(armor) > 1 then
			item.armor = armor
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
			item.buff.defaultLifetime = math.tointeger(buffData.defaultLifeTime.value / 1000000)
			item.buff.icon = exportIconTexture(buffData.icon.texture, "buffs\\" .. cleanFilename(item.name))
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
			local v = value.value
			if value.valueFormat == "Duration" then
				v = v / 1000
			end
			table.insert(item.uiValues, { __type = "object", _id = value.locaId.value, text = text, format = value.valueFormat, value = v })
		end
	end
end

local function extractImpactValues(impactValuesData, item, debug)
	if impactValuesData then
		local impactValues = {}
		for _, value in pairs(impactValuesData) do
			local locaTag = translations.translateGuid(value.value.locaTag) or ""
			if locaTag and locaTag ~= "" then
				local v = value.value.value
				local type = type(v)
				if type == "userdata" then
					v = v.value
					if value.value.type.value == 3756319748 then -- Seems to be a duration struct in ns
						v = v / 1000000000
					end
				end
				table.insert(impactValues, { __type = "object", _id = value.value.id, locaTag = locaTag, value = v, format = value.value.valueFormat, _luaType = type, _type = value.value.type.value })
			end
		end
		if debug then
			item._impactValues = impactValues
		else
			item.impactValues = impactValues
		end
	end
end

local function extractWeapons(itemData, item)
	item.genRarity = itemData.generateRarity
	item.disableRarityGeneration = itemData.disableRarityGeneration

	extractDamageSetup(itemData.damageSetup, item, true)
	extractArmorSetup(itemData.armorSetup, item, true)
	extractEquipmentSetup(itemData.equipment, item)

	item.perks = {}
	for _, perkRef in ipairs(itemData.perkReferences) do
		local perk = perksByGuid[perkRef]
		if perk then
			table.insert(item.perks, {
				__type = "object",
				_guid = perkRef,
				debugName = perk.debugName,
			})
		end
	end

	if itemData.weaponCategoryReference then
		local weaponCategory = weaponCategoriesByGuid[itemData.weaponCategoryReference]
		if weaponCategory then
			item.weaponCategory = weaponCategory.locaTag
			item.durabilityMod = weaponCategory.durabilityMod
			item.weaponCategoryType = weaponCategory.categoryType
			item.weaponClassType = weaponCategory.classType
		end
	end
end

local function extractAmmunition(itemData, item)
	return extractWeapons(itemData, item)
end

local function extractEquipment(itemData, item)
	extractEquipmentSetup(itemData.equipment, item)
	extractArmorSetup(itemData.armorSetup, item, true)
	extractBlockSetup(itemData.blockSetup, item)
end

local function extractConsumables(itemData, item)
	extractEquipmentSetup(itemData.equipment, item)
end

local function extractItem(itemRef)
	local itemInfo = game.assets.get_resource(itemRef, "keen::ItemInfo")
	if not itemInfo then
		warn("item not found for ref " .. itemRef)
	else
		--- @type keen.ItemInfo
		local itemData = itemInfo.data
		if itemData then
			-- print("Processing: " .. itemData.debugName)
			local item = { 
				__type = "object",
				_id = itemData.itemId.value,
				_guid = itemData.objectId,
				debugName = itemData.debugName,
				name = translations.translateGuid(itemData.name) or itemData.debugName,
				description = translations.translateGuid(itemData.description) or "",
				rarity = itemData.rarity,
				category = itemData.category,
			}
			if not categories[item.category] then
				categories[item.category] = {}
			end

			-- No idea what these are yet
			for _, tagData in pairs(itemData.tags) do
				local tag = itemTagsByGuid[tagData.tag]
				if tag then
					-- miss named parts of a fraction ?
					-- tagData.nominator - should be numerator?
					-- tagData.denominator
					-- print("Item Tag: " .. tagData.tag .. " : " .. tagData.nominator .. " / " .. tagData.denominator)
				end
			end

			extractUiValues(itemData.uiValues, item)
			extractLevelRange(itemData.itemLevelRange, item)
			extractImpactValues(itemData.impactValues, item, true)

			if item.category == "Weapons" then
				extractWeapons(itemData, item)
			elseif item.category == "Ammunition" then
				extractAmmunition(itemData, item)
			elseif item.category == "Equipment" then
				extractEquipment(itemData, item)
			elseif item.category == "Consumables" then
				extractConsumables(itemData, item)
			end

			item.icon = exportIconTexture(iconInfo[itemData.objectId], string.lower(item.category) .. "\\" .. cleanFilename(item.name))

			table.insert(categories[item.category], item)
			itemsById[item._id] = item
			itemsByGuid[item._guid] = item
		end
	end
end

-- Some ItemInfo are not in the ItemRegistryResource so have to be loaded on demand
-- Probaly a bug at devs end
local function lookupItemById(id, guid)
	local item = itemsById[id]
	if item == nil then
		extractItem(guid)
	end
	return itemsById[id]
end

local function extractIcons()
	---@type keen.ItemIconRegistryResource
	local iconRegistry = game.assets.get_resource("3064d35d-7342-40ca-bdc9-aad58f83bf45", "keen::ItemIconRegistryResource").data
	for _, icon in pairs(iconRegistry.icons) do
		iconInfo[icon.guid] = icon.uiTexture
	end
end

local function extractPerks()
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
				category = "Perks",
				debugName = perkData.debugName,
				name = translations.translateGuid(perkData.name) or perkData.debugName
			}
			if perkData.description then
				perkEntry.description = translations.translateGuid(perkData.description) or ""
			else
				perkEntry.description = ""
			end

			extractDamageSetup(perkData.damageModifier, perkEntry)
			extractArmorSetup(perkData.perkArmorSetup, perkEntry)
			extractImpactValues(perkData.impactValues, perkEntry, false)

			perkEntry.icon = exportIconTexture(perkData.icon.texture, "perks\\" .. cleanFilename(perkEntry.debugName))

			table.insert(perks, perkEntry)
			perksByGuid[perkEntry._guid] = perkEntry
		end
	end
end

local function extractItems()
	---@type keen.ItemRegistryResource
	local itemRegistry = game.assets.get_resources_by_type("keen::ItemRegistryResource")[1].data

	-- no idea what these are yet
	for _, itemTagData in pairs(itemRegistry.itemTags) do
		local itemTag = {
			_guid = itemTagData.tagGuid,
			_labelId = itemTagData.labelId.value -- do not appear to be a translation hash
		}
		itemTagsByGuid[itemTag._guid] = itemTag
	end

	for _, weaponCatData in pairs(itemRegistry.weaponCategories) do
		local weaponCat = {
			_guid = weaponCatData.guid,
			locaTag = translations.translateGuid(weaponCatData.weaponCategory.locaTag),
			-- no idea what this is - buried in impact I think - keen.impact.AttributeDeclerationBase
			_damageMod = weaponCatData.weaponCategory.damageMod, 
			durabilityMod = weaponCatData.weaponCategory.durabilityMod,
			categoryType = weaponCatData.weaponCategory.categoryType,
			classType = weaponCatData.weaponCategory.classType
		}
		weaponCategoriesByGuid[weaponCat._guid] = weaponCat
	end

	for _, itemRef in pairs(itemRegistry.itemRefs) do
		extractItem(itemRef)
	end
end

local function extractRecipes()
	---@type keen.RecipeRegistryResource
	local recipeRegistry = game.assets.get_resource("5e57de0f-280c-4559-8191-f02c1ba656e2", "keen::RecipeRegistryResource").data
	-- inputCategories - seems to be grouping of alternate items reference by numeric id
	-- recipes - the actual recipes
	--   will need indexed of items (by id) and inputCategories by id, maybe guid for items also

	for _, inputCatData in pairs(recipeRegistry.inputCategories) do
		local itemIds = {}
		inputCategoriesById[inputCatData.inputCategoryId.value] = itemIds
		for _, item in pairs(inputCatData.items) do
			table.insert(itemIds, item.value)
		end
	end

	categories["Recipes"] = {}
	for _, recipeData in pairs(recipeRegistry.recipes) do
		local recipe = {
			__type = "object",
			category = "Recipes",
			_id = recipeData.recipeId.value,
			_guid = recipeData.recipeGuid,
			level = recipeData.level,
			_workshopId = recipeData.workshopId.value,
			debugName = recipeData.debugName,
			isCooking = recipeData.isCookingRecipe,
			requiresSheltered = recipeData.requiresSheltered,
			isUpgrade = recipeData.isUpgrade,
			requiredEnergy = recipeData.requiredEnergy,
			comfortLevel = recipeData.comfortLevel,
			serverProgressLevel = recipeData.serverProgressLevel,
			requiredHappyNpcCount = recipeData.requiredHappyNpcCount,
			waterAmount = recipeData.waterAmount,
			waterCharges = recipeData.waterCharges,
			levelRequirement = recipeData.levelRequirement,
			comfortLevelRequirement = recipeData.comfortLevelRequirement,
			serverProgressLevelRequirement = recipeData.serverProgressLevelRequirement
		}
		recipesById[recipe._id] = recipe
		table.insert(categories["Recipes"], recipe)

		recipe.inputs = {}
		for _, inputInfo in pairs(recipeData.input) do
			local input = { 
				__type = "object",
			}
			table.insert(recipe.inputs, input)

			if inputInfo.itemStack.itemRef and inputInfo.itemStack.item.value ~= 0 then
				input.itemCount = inputInfo.itemStack.count
				local item = lookupItemById(inputInfo.itemStack.item.value, inputInfo.itemStack.itemRef)
				if item then
					input.item = {
						__type = "object",
						_id = item._id,
						_guid = item._guid,
						debugName = item.debugName,
						name = item.name,
						icon = item.icon
					}
				else
					print("Input Item  " .. inputInfo.itemStack.item.value .. " not found " .. inputInfo.itemStack.itemRef)
				end
			end
			-- not sure if this should be 'else' - I think it shoud be
			if inputInfo.inputItemCategory.categoryRef and inputInfo.inputItemCategory.category.value ~= 0 then
				input._categoryGuid = inputInfo.inputItemCategory.categoryRef
				input._categoryId = inputInfo.inputItemCategory.category.value
				input.categoryCount = inputInfo.inputItemCategory.count

				local itemIds = inputCategoriesById[input._categoryId]
				if itemIds then
					input.CategoryItems = {}
					for _, itemId in ipairs(itemIds) do
						-- Item guid not available here, might have to find anbother way to load items
						-- local item = lookupItemById(outputInfo.item.value, outputInfo.itemRef)
						local item = itemsById[itemId]
						if item then
							table.insert(input.CategoryItems,
								{
									__type = "object",
									_id = item._id,
									_guid = item._guid,
									debugName = item.debugName,
									name = item.name,
									icon = item.icon
								})
						else
							print("Input Category Item  " .. itemId .. " not found")
						end
					end
				end
			end

			if input._itemId and input._categoryId then
				print("Recipe has both item and category as input: " .. recipe.id)
			end
		end

		recipe.output = {}
		for _, outputInfo in pairs(recipeData.output) do
			local output = {
				__type = "object",
				count = outputInfo.count,
			}

			local item = lookupItemById(outputInfo.item.value, outputInfo.itemRef)
			if item then
				output.item = {
					__type = "object",
					_id = item._id,
					_guid = item._guid,
					debugName = item.debugName,
					name = item.name,
					icon = item.icon
				}
			else
				print("Ouptut Item " .. outputInfo.item.value .. " not found " .. outputInfo.itemRef)
			end
					
			table.insert(recipe.output, output)
		end

		recipe.craftingDuration = recipeData.craftingDuration.value
	end

	local workshopRegistry
	local workshopRegistryData = game.assets.get_resource("3baba1c2-bc82-4ab7-b20e-16dec28208af", "keen::WorkshopRegistryResource").data
	for _, workshopInfo in pairs(workshopRegistryData.workshops) do
		
	end

	---@type keen.RecipeDataResource
	local recipeDataData = game.assets.get_resource("5e57de0f-280c-4559-8191-f02c1ba656e2", "keen::RecipeDataResource").data

	for	_, workshopInfo in pairs(recipeDataData.workshops) do
		local workshop = { 
			__type = "object",
			_workshopObjectId = workshopInfo.workshopObjectId,
			_workshopId = workshopInfo.workshopId.value,
		} 
		for _, groupInfo in pairs(workshopInfo.groups) do
		end
	end

	-- workshops - referenced from recipes by numeric id
	--   label
	--   icon
	--   groupId - grouping of recipe set
	--   sets - collection of recipes 

	--   needs index of recipes by numeric id

	-- Then use workshop to organise output - perhaps just insert the workshop names, sets, groups etc into each recipe

end

local function exportCategories()
	-- Export categories to JSON files
	for category, items in pairs(categories) do
		print(string.format('exporting category "%s"', category))
		local json = jsonEnc.encode(items, "  ", false)
		local filename = string.format("%s.json", category:lower())
		io.export("json\\" .. string.lower(cleanFilename(filename)), json)
	end
end

extractIcons()
extractPerks()
extractItems()
extractRecipes()

exportCategories()
translations.export("translations.csv")
