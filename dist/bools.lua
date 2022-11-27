local BoolFunctions = {
	StringTable = {"false","true"}
}

function BoolFunctions:FromNumber(Number)
	return Number ~= 0
end

function BoolFunctions:FromString(String)
	local FoundNumber = table.find(BoolFunctions.StringTable,String:lower())
	if FoundNumber then
		return BoolFunctions:FromNumber(FoundNumber-1)
	end
	return false
end

function BoolFunctions:ToBool(Value)
	if typeof(Value) == "string" then
		return BoolFunctions:FromString(Value)
	elseif typeof(Value) == "number" then
		return BoolFunctions:FromNumber(Value)
	elseif typeof(Value) == "boolean" then
		return Value
	end
	return false
end

return BoolFunctions