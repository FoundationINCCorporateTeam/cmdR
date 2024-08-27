local HttpService = game:GetService("HttpService")
local plugin = plugin or Instance.new("Plugin")

local toolbar = plugin:CreateToolbar("Script Installer")
local button = toolbar:CreateButton("Open CLI", "Open Script Installer CLI", "rbxassetid://14978048121")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScriptInstallerGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = game:GetService("CoreGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 600, 0, 400)
frame.Position = UDim2.new(0.5, -300, 0.5, -200)
frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
frame.BorderSizePixel = 0
frame.Parent = screenGui
frame.Visible = false

local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.Size = UDim2.new(1, -20, 1, -20)
scrollingFrame.Position = UDim2.new(0, 10, 0, 10)
scrollingFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
scrollingFrame.BorderSizePixel = 0
scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollingFrame.ScrollBarThickness = 10
scrollingFrame.Parent = frame

local listLayout = Instance.new("UIListLayout")
listLayout.Parent = scrollingFrame
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 5)

local textBox = Instance.new("TextBox")
textBox.Size = UDim2.new(1, -20, 0.1, -10)
textBox.Position = UDim2.new(0, 10, 0, 10)
textBox.ClearTextOnFocus = false
textBox.Text = ""
textBox.PlaceholderText = "Type command here..."
textBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
textBox.Font = Enum.Font.SourceSans
textBox.TextSize = 14
textBox.TextStrokeTransparency = 0.7
textBox.Parent = frame

local function createOutputLabel(text)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 0, 30)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Font = Enum.Font.SourceSans
	label.TextSize = 14
	label.Text = text
	label.Parent = scrollingFrame
	scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
	scrollingFrame.CanvasPosition = Vector2.new(0, scrollingFrame.CanvasSize.Y.Offset)
end

local function installScript(scriptData, parent)
	local item
	if scriptData.type == "Folder" then
		item = Instance.new("Folder")
		item.Name = scriptData.name
		item.Parent = parent
		for _, childData in pairs(scriptData.children) do
			installScript(childData, item)
		end
	else
		if scriptData.type == "LocalScript" then
			item = Instance.new("LocalScript")
		elseif scriptData.type == "ModuleScript" then
			item = Instance.new("ModuleScript")
		else
			item = Instance.new("Script")
		end
		item.Name = scriptData.name
		item.Source = scriptData.code
		item.Parent = parent
	end
	return item
end

local customCommands = {}

local function loadCustomCommands(configScript)
	local success, commands = pcall(function()
		return loadstring(configScript)()
	end)
	if success and commands then
		for command, func in pairs(commands) do
			customCommands[command] = func
		end
	end
end

local function parseCommandWithParams(command)
	local spaceIndex = command:find(" ")
	if spaceIndex then
		local cmd = command:sub(1, spaceIndex - 1)
		local params = command:sub(spaceIndex + 1)
		return cmd, params
	else
		return command, nil
	end
end

local function processCommand(command)
	-- Remove leading and trailing whitespace
	command = command:match("^%s*(.-)%s*$")

	-- Check if the command starts with the package install prefix
	local scriptPrefix = "%cmdR packageInt LUAU "

	if command:sub(1, #scriptPrefix) == scriptPrefix then
		local scriptName = command:sub(#scriptPrefix + 1):match("^%s*(.-)%s*$")
		if scriptName and scriptName ~= "" then
			local url = "https://appbloxinteractive.glitch.me/get-script?name=" .. HttpService:UrlEncode(scriptName)
			local success, response = pcall(function()
				return HttpService:GetAsync(url)
			end)
			if success then
				local data
				local successDecode, decodeError = pcall(function()
					data = HttpService:JSONDecode(response)
				end)
				if successDecode then
					installScript(data, game:GetService("ServerScriptService"))

					for _, child in pairs(data.children) do
						if child.name == "@cmdR/cmdconfig" and child.type == "ModuleScript" then
							loadCustomCommands(child.code)
						end
					end

					createOutputLabel("> " .. command .. "\nPackage installed successfully!")
				else
					createOutputLabel("> " .. command .. "\nError decoding package data: " .. decodeError)
				end
			else
				createOutputLabel("> " .. command .. "\nError fetching package: " .. response)
			end
		else
			createOutputLabel("> " .. command .. "\nInvalid command: Missing package name.")
		end
	elseif customCommands[command] then
		-- Handle custom commands
		local success, err = pcall(function()
			customCommands[command](nil) -- Pass parameters if needed
		end)
		if not success then
			createOutputLabel("> Error executing command: " .. err)
		end
	else
		createOutputLabel("> " .. command .. "\nInvalid command format.")
	end
end


local function searchForCmdConfigs(container)
	for _, item in pairs(container:GetDescendants()) do
		if item:IsA("ModuleScript") and item.Name == "@cmdR/cmdconfig" then
			loadCustomCommands(item.Source)
		end
	end
end

local function searchForAllCmdConfigs()
	table.clear(customCommands)
	for _, service in pairs(game:GetChildren()) do
		searchForCmdConfigs(service)
	end
	createOutputLabel("> All custom commands have been loaded.")
end

local function printCustomCommands()
	for command, _ in pairs(customCommands) do
		print(command)
	end
end

button.Click:Connect(function()
	frame.Visible = not frame.Visible
	if frame.Visible then
		searchForAllCmdConfigs()
		printCustomCommands()
	end
end)

textBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		local command = textBox.Text
		createOutputLabel("> Command: " .. command)
		createOutputLabel("> Executing Command...")
		pcall(function()
			processCommand(command)
		end)
		textBox.Text = ""
	end
end)
