local translations = {}


local function get_translations()
	---@type keen.LocaTagCollectionResource
	local localization = game.assets.get_resources_by_type("keen::LocaTagCollectionResource")[1].data
	local keenglishDataGuid = game.guid.from_content_hash(localization.keenglishDataHash)
	local buf = game.assets.get_content(keenglishDataGuid):read_data()

	---@type keen.LocaTagCollectionResourceData
	local localization_data = buf:read_resource("keen::LocaTagCollectionResourceData")

	local dict = {}

	for _, tag in ipairs(localization_data.tags) do
		dict[tag.id.value] = tag.text
	end

	return dict
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

function translations.translateGuid(id)
    if translations.usTranslations == nil then
        translations.usTranslations = get_translations("En_Us")
    end

    if translations.defaultTranslations == nil then
        translations.defaultTranslations = get_translations()
    end

    local hash = game.guid.hash(id)
    return translations.usTranslations[hash] or translations.defaultTranslations[hash]
end

function translations.translateHash(hash)
    if translations.usTranslations == nil then
        translations.usTranslations = get_translations("En_Us")
    end

    if translations.defaultTranslations == nil then
        translations.defaultTranslations = get_translations()
    end

    return translations.usTranslations[hash] or translations.defaultTranslations[hash]
end

function translations.export(filename)
    csv = "Key,US_Translation,Default_Translation\n"
    if translations.usTranslations == nil then
        translations.usTranslations = get_translations("En_Us")
    end
    if translations.defaultTranslations == nil then
        translations.defaultTranslations = get_translations()
    end
    local allKeys = {}
    for k, _ in pairs(translations.usTranslations) do
        allKeys[k] = true
    end
    for k, _ in pairs(translations.defaultTranslations) do
        allKeys[k] = true
    end
    for k, _ in pairs(allKeys) do
        local usText = translations.usTranslations[k] or ""
        local defText = translations.defaultTranslations[k] or ""
        csv = csv .. string.format('%s,"%s","%s"\n', k, usText:gsub('"', '""'), defText:gsub('"', '""'))
    end
	io.export(filename, csv)
end

return translations
