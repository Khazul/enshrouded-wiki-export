require("table")
local jsonEnc = require("json_encoder")

if not loader.features.export then
	return
end

---@param locale keen.LanguageId|nil the locale identifier. If nil, falls back to "keenglish"
---@return table<u32, string> dictionary of translations
local function get_translations(locale)
	---@type keen.LocaTagCollectionResource
	local localization = game.assets.get_resources_by_type("keen::LocaTagCollectionResource")[1].data
	local content_hash = nil

	if locale ~= nil then
		-- look for the specified locale
		for _, loc in ipairs(localization.languages) do
			if loc.language == locale then
				content_hash = loc.dataHash
				break
			end
		end
	else
		-- fall back to keenglish
		content_hash = localization.keenglishDataHash
	end

	if content_hash == nil then
		error("Locale not found: " .. tostring(locale))
	end

	-- load the localization data
	local guid = game.guid.from_content_hash(content_hash)
	local buf = game.assets.get_content(guid):read_data()

	---@type keen.LocaTagCollectionResourceData
	local localization_data = buf:read_resource("keen::LocaTagCollectionResourceData")

	-- build the dictionary
	local dict = {}

	for _, tag in ipairs(localization_data.tags) do
		dict[tag.id.value] = tag.text
	end

	return dict
end

local usTranslations = get_translations("En_Us")
local translations = get_translations()

local function translate(id)
	return usTranslations[game.guid.hash(id)] or translations[game.guid.hash(id)]
end

local function getDamageDistribution(damageDistribution, item)
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

local function getArmorDistribution(armorDistribution, item)
	item.armor = { __type = "object" }
	for t, a in pairs(armorDistribution) do
		if a > 0 then
			item.armor[t] = a
		end
	end
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
			item.id = itemData.itemId.value
			item.guid = itemData.objectId
			item.debugName = itemData.debugName
			item.name = translate(itemData.name) or itemData.debugName
			item.description = translate(itemData.description) or ""
			print(item.description)
			item.rarity = itemData.rarity
			local category = itemData.category
			if not categories[category] then
				categories[category] = {}
			end
			table.insert(categories[category], item)
			-- local stackSize = data.maxStackSize
			-- data.appliedBuff
			-- data.appiedDebuff

			if category == "Weapons" or category == "Ammunition" then
				item.genRarity = itemData.generateRarity
				item.disableRarityGeneration = itemData.disableRarityGeneration

				for _, value in pairs(itemData.impactValues) do
					if value.value.type.value == 3902764048 and value.value.valueFormat == "Duration" then
						local locaTag = translate(value.value.locaTag) or "?"
						if value.value.id == "0750bfea-b306-4452-9cec-05bca19e1e33"
							or value.value.id == "51bb9d6e-16cb-4b45-95e1-bf1f2e306586"
							or value.value.id == "fee154e6-8708-47e2-9e9c-8ab3f7d009c2"
							or value.value.id == "0750bfea-b306-4452-9cec-05bca19e1e33" then
							item.actionRate = value.value.value
							item.actionTag  = locaTag
						end
					end
				end

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
							name = translate(perkData.name) or perkData.debugName,
						}
						if perkData.description then
							perkEntry.description = translate(perkData.description) or ""
						else
							perkEntry.description = ""
						end

						if perkData.damageSetup then
							perkEntry.dmgMod = perkData.damageSetup.dmgMod
							perkEntry.speedMod = perkData.damageSetup.speedMod
							getDamageDistribution(perkData.damageSetup.distribution, perkEntry)
						end

						if perkData.armorSetup then
							getArmorDistribution(perkData.armorSetup.distribution, perkEntry)
						end

						table.insert(item.perks, perkEntry)
					end
				end

				local damage = itemData.damageSetup
				if damage then
					item.dmgMod = damage.dmgMod
					item.speedMod = damage.speedMod
					getDamageDistribution(damage.distribution, item)
				end
			else
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
			guid = perkRef,
			debugName = perkData.debugName,
			name = translate(perkData.name) or perkData.debugName,
		}
		if perkData.description then
			perkEntry.description = translate(perkData.description) or ""
		else
			perkEntry.description = ""
		end

		if perkData.damageSetup then
			perkEntry.dmgMod = perkData.damageSetup.dmgMod
			perkEntry.speedMod = perkData.damageSetup.speedMod
			getDamageDistribution(perkData.damageSetup.distribution, perkEntry)
		end

		if perkData.armorSetup then
			getArmorDistribution(perkData.armorSetup.distribution, perkEntry)
		end

		table.insert(perks, perkEntry)
	end
end


-- Export categories to JSON files
for category, items in pairs(categories) do
	print(string.format('exporting category "%s"', category))
	local json = jsonEnc.encode(items, "  ")
	local filename = string.format("%s.json", category:lower())
	io.export(filename, json)
end
