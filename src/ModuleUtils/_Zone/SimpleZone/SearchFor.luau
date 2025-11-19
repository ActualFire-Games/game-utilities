local function splitRecursiveProperty(name: string)
	local instanceSplit = name:split(".")
	
	name = instanceSplit[1]
	
	return name, #instanceSplit > 1 and table.concat(instanceSplit, ".", 2, #instanceSplit)
end

local function propertyChecker(part, mode, checkCondition, properties)
	for _, info in properties do
		local name = info.Name
		local value = info.Value
		local t = info.Type
		
		local name, recursiveProperty = splitRecursiveProperty(name)

		-- If a part contains a parent of the same name, it will recursively search that part until the last property is found (example, Foo_Parent_Parent_Name = "Bar")
		if name == "Parent" and recursiveProperty then
			local parts = SearchFor({part.Parent}, {{Name = recursiveProperty, Value = value, Type = t}}, mode)
			checkCondition(table.find(parts, part.Parent) ~= nil)
			continue
		end
		-- If a part contains a child of the same name, it will recursively search that part until the last property is found (example, Foo_Bar_Baz_Name = "Bar")
		if part:FindFirstChild(name) and recursiveProperty then
			local parts = SearchFor({part:FindFirstChild(name)}, {{Name = recursiveProperty, Value = value, Type = t}}, mode)
			checkCondition(table.find(parts, part.Parent) ~= nil)
			continue
		end
		if t == "Tag" then
			checkCondition(part:HasTag(name))
			continue
		end
		if t == "Attribute" then
			local condition = part:GetAttribute(name) == value

			checkCondition(condition)
			continue
		end
		checkCondition(part[name] == value)
	end
end

function SearchFor(tableToSort, properties: any, mode: "And" | "Or")
	assert(mode ~= nil and (mode == "Or" or mode == "And"), "Bad mode argument.")
	
	local qualifiedParts = {}

	for i, part: BasePart in tableToSort do
		local doesNotMatch = false
		
		local function checkCondition(condition: any)
			if condition and mode == "Or" then
				table.insert(qualifiedParts, part)
			elseif not condition and mode == "And" then
				doesNotMatch = true
			end
		end
		
		propertyChecker(part, mode, checkCondition, properties)

		if not doesNotMatch and mode == "And" then
			table.insert(qualifiedParts, part)
		end
	end
	
	return qualifiedParts
end

return SearchFor