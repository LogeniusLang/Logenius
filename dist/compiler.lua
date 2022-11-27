local BoolFunctions = {
	StringTable = {"false","true"},
    FindTable = function(Tab, Value)
        for Idx, Val in pairs(Tab) do
            if Val == Value then
                return Idx
            end
        end
    end
}

function BoolFunctions:FromNumber(Number)
	return Number ~= 0
end

function BoolFunctions:FromString(String)
	local FoundNumber = BoolFunctions.FindTable(BoolFunctions.StringTable,String:lower())
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

local Backend = {
	FindNameInDict = function(Dict, Name)
		for Key, Value in pairs(Dict) do
			if Value.Name == Name then
				return true
			end
		end
		return
	end,
	GetNameInDict = function(Dict, Name)
		for Key, Value in pairs(Dict) do
			if Value.Name == Name then
				return Value
			end
		end
		return
	end,
	KeyNameInDict = function(Dict, Name)
		for Key, Value in pairs(Dict) do
			if Value.Name == Name then
				return Key
			end
		end
		return
	end,
    SplitString = function(Input, Sep)
        if Sep == nil then
            Sep = "%s"
        end
        local Result = {}
        for Str in string.gmatch(Input, "([^"..Sep.."]+)") do
                table.insert(Result, Str)
        end
        return Result
    end
}
local Modules = {
	BoolFunctions = require("bools")
}

local Definers = {
	Wrap = "->",
	Call = "=>",
	Variable = "v:",
	String = "str:",
	Number = "num:",
	Boolean = "bool:",
	Define = "def:",
	Array = "arr:",
	Get = "g:",
	Global = "gl:",
	Set = "s:",
}

local RunStarters = {
	Start = Definers.Wrap .. "process",
	End = Definers.Wrap .. "process end",
}

local Process = {
	String = function(UnpStr)
		return string.gsub(UnpStr, "__", " ")
	end
}

local Globals = {
	log = function(UnpStr, Raw)
		local Str = Process.String(UnpStr)
		print(Str)
		Raw.Thread.Output[#Raw.Thread.Output + 1] = Str
	end,
}

function GetBetween(Start, End, Str)
	return string.match(Str, Start .. "(.-)" .. End)
end

function GetAfter(Start, Str)
	return string.sub(Str, Start:len() + 1, Str:len())
end

function CreateThread(Code, RunEnv)
	local RawCode = GetBetween(RunStarters.Start, RunStarters.End, Code)
	RawCode = string.gsub(RawCode, "\r", "")
	RawCode = string.gsub(RawCode, "\t", "")
	RawCode = string.gsub(RawCode, "\n", "")
	local Env = {
		RawLines = Backend.SplitString(RawCode, ";"),
		Lines = {},
		Variables = {},
		RunEnv = RunEnv,
		Output = {},
	}
	for _, Line in pairs(Env.RawLines) do
		Env.Lines[#Env.Lines + 1] = Backend.SplitString(Line, " ")
	end
	return Env
end

function Error(Line, ExpressionLine, Message, Env)
	error(("[%s]: Line #%s, Expression #%s: %s"):format(arg[1], Line, ExpressionLine, Message))
end

function DecompileStatement(Statement)
	local Type = Statement:sub(1, Statement:find(":"))
	local StatementTable = {
		RealValue = GetAfter(Type, Statement),
		Type = Type:sub(1, #Type - 1)
	}
	return StatementTable
end

function IsGet(Expression)
	return Expression:sub(1, 2) == Definers.Get
end

function DecompileVariables(Thread)
	local CurrentVariables = {}
	for LineKey, Line in pairs(Thread.Lines) do
		for ExpressionKey, Expression in pairs(Line) do
			if string.sub(Expression, 1, 2) == Definers.Variable then
				local VarName = GetAfter(Definers.Variable, Expression)
				if Backend.FindNameInDict(CurrentVariables, VarName) then
					Error(LineKey, ExpressionKey, ("Variable %q was already assigned, please use \"s:<VarName>\" to assign an existing variable"):format(VarName), Thread.RunEnv)
					return Thread
				end
				if Line[ExpressionKey + 1] ~= Definers.Call then
					Error(LineKey, ExpressionKey, ("Expecting %s, got %s"):format(Definers.Call, Line[ExpressionKey + 1]), Thread.RunEnv)
					return Thread
				end
				CurrentVariables[#CurrentVariables + 1] = {
					Name = VarName,
					Value = DecompileStatement(Line[ExpressionKey + 2])
				}
			elseif string.sub(Expression, 1, 2) == Definers.Set then
				local VarName = GetAfter(Definers.Set, Expression)
				if not Backend.FindNameInDict(CurrentVariables, VarName) then
					Error(LineKey, ExpressionKey, ("Variable %q does not exist"):format(VarName), Thread.RunEnv)
					return Thread
				else
					if Line[ExpressionKey + 1] ~= Definers.Call then
						Error(LineKey, ExpressionKey, ("Expecting %s, got %s"):format(Definers.Call, Line[ExpressionKey + 1]), Thread.RunEnv)
						return Thread
					end
					CurrentVariables[Backend.KeyNameInDict(CurrentVariables, VarName)] = {
						Name = VarName,
						Value = DecompileStatement(Line[ExpressionKey + 2])
					}
				end
			elseif string.sub(Expression, 1, 3) == Definers.Global then
				local FName = GetAfter(Definers.Global, Expression)
				if Line[ExpressionKey + 1] ~= Definers.Call then
					Error(LineKey, ExpressionKey, ("Expecting %s, got %s"):format(Definers.Call, Line[ExpressionKey + 1]), Thread.RunEnv)
					return Thread
				end
				local Call = Globals[FName]
				if not Call then
					Error(LineKey, ExpressionKey, ("%q is not a Global Function"):format(FName), Thread.RunEnv)
					return Thread
				else
					local Value = Line[ExpressionKey + 2]
					local IsNot = false
					if Value:sub(1, 1) == "!" then
						IsNot = true
						Value = Value:sub(2, #Value)
					end
					if IsGet(Value) then
						local VarName = GetAfter(Definers.Get, Value)
						if not Backend.FindNameInDict(CurrentVariables, VarName) then
							Error(LineKey, ExpressionKey, ("Variable %q does not exist"):format(VarName), Thread.RunEnv)
							return Thread
						else
							local Val = Backend.GetNameInDict(CurrentVariables, VarName).Value
							if IsNot == true then
								if Val.Type == "bool" then
									local Bool = not Modules.BoolFunctions:ToBool(Val.RealValue)
									Val.RealValue = tostring(Bool)
								else
									Error(LineKey, ExpressionKey, ("\"bool\" expected, got %q"):format(Val.Type), Thread.RunEnv)
									return Thread
								end
							end
							Call(Val.RealValue, {
								Thread = Thread,
								LineKey = LineKey,
								Line = Line,
								ExpressionKey = ExpressionKey,
								Expression = Expression,
								CurrentVariables = CurrentVariables
							})
						end
					else
						local AllowedTypes = {
							"num",
							"str",
							"bool",
							"arr"
						}
						local Type = Value:sub(1, Value:find(":") - 1)
						if not BoolFunctions.FindTable(AllowedTypes, Type) then
							Error(LineKey, ExpressionKey, ("%q is not a valid DataType"):format(Type), Thread.RunEnv)
							return Thread
						else
							local Val = DecompileStatement(Value)
							if IsNot == true then
								if Val.Type == "bool" then
									local Bool = not Modules.BoolFunctions:ToBool(Val.RealValue)
									Val.RealValue = tostring(Bool)
								else
									Error(LineKey, ExpressionKey, ("\"bool\" expected, got %q"):format(Val.Type), Thread.RunEnv)
									return Thread
								end
							end
							Call(Val.RealValue, {
								Thread = Thread,
								LineKey = LineKey,
								Line = Line,
								ExpressionKey = ExpressionKey,
								Expression = Expression,
								CurrentVariables = CurrentVariables
							})
						end
					end
				end
			end
		end 
	end
	Thread.Variables = CurrentVariables
	return Thread
end

function Run(Code, Env)
	local Thread = CreateThread(Code, Env)
	Thread = DecompileVariables(Thread)
	return Thread
end

local Script = io.open(arg[1], "r+"):read("*a")

print(Script)

Run(Script, getfenv())