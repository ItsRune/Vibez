--!strict
--// Services \\--
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

--// Variables \\--
local Player = Players.LocalPlayer
local Maid: { [any]: RBXScriptConnection | { RBXScriptConnection } } = {}
local Definitions = require(script.Parent.Parent.Definitions)

--// Functions \\--
local function _getTempFolder()
	local folder = Workspace:FindFirstChild(script.Name .. "_Temp")

	if not folder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = script.Name .. "_Temp"
		newFolder.Parent = Workspace

		folder = newFolder
	end

	return folder
end

local function onDestroy(componentData: Definitions.componentData)
	componentData._debug("ranksticks_destroy", "Destroy method triggered.")
	if Maid == nil then
		return
	end

	componentData.Disconnect(Maid :: any)
	table.clear(Maid)
end

local function onSetup(componentData: Definitions.componentData)
	local _warn, remoteFunction = componentData._warn, componentData.remoteFunction

	local custScriptName = string.split(script.Parent.Parent.Name, "-")[1]
	local Character = Player.Character or Player.CharacterAdded:Wait()
	local stickDebounce = false

	onDestroy(componentData)

	local function handleStickMode(actionName: string, child: Tool)
		if componentData.Data.Mode == "DetectionInFront" or componentData.Data.Mode == "Default" then -- Default
			local cf, size = Character:GetBoundingBox()
			local newPart = Instance.new("Part")
			local Weld = Instance.new("WeldConstraint")
			local primaryPart = Character.PrimaryPart

			componentData._debug("rankstick_detect_in_front", "Creating new 'Part' & 'Weld'.")

			if not primaryPart then
				newPart:Destroy()
				return false
			end

			newPart.Name = actionName .. "_Checker"
			newPart.Transparency = 1
			newPart.CFrame = cf * CFrame.new(0, 0, -size.Z)
			newPart.Anchored = false
			newPart.Size = size + Vector3.new(size.X / 2, 0, size.Z)
			newPart.BrickColor = BrickColor.Red()
			newPart.Massless = true
			newPart.CanCollide = false
			newPart.Parent = _getTempFolder()

			componentData._debug("rankstick_detect_in_front", "Resizing and positioning part.")

			Weld.Name = newPart.Name
			Weld.Part0 = newPart
			Weld.Part1 = primaryPart
			Weld.Parent = newPart

			componentData._debug("rankstick_detect_in_front", "Welding new part to character.")

			local closestTargets, closestTarget = {}, nil
			local hasReceived, secondsSpent, connection = false, 0, nil

			componentData._debug("rankstick_detect_in_front", "Applying '.Touched' connection to part.")
			connection = newPart.Touched:Connect(function()
				hasReceived = true
				local partsWithinPart = Workspace:GetPartsInPart(newPart)

				for _, part in ipairs(partsWithinPart) do
					local ancestorModel = part:FindFirstAncestorWhichIsA("Model")
					if part:IsDescendantOf(child) or not ancestorModel then
						continue
					end

					local possiblePlayer = Players:GetPlayerFromCharacter(ancestorModel)
					if not possiblePlayer then
						continue
					end

					table.insert(closestTargets, possiblePlayer)
				end
			end)

			componentData._debug("rankstick_detect_in_front", "Awaiting 3 seconds for part input...")
			while hasReceived == false do
				if secondsSpent >= 3 then -- max amount of time the part will be active for
					hasReceived = false
					break
				end

				if hasReceived then
					break
				end

				if not connection then
					continue
				end

				task.wait(1)
				secondsSpent += 1
			end

			componentData._debug("rankstick_detect_in_front", "Deleting part.")
			Debris:AddItem(newPart, 0)

			if not hasReceived or child:IsDescendantOf(Player) then
				return false
			end

			for _, target: Player in pairs(closestTargets) do
				local t_char = target.Character
				local c_char = (closestTarget ~= nil) and closestTarget.Character or nil

				if not c_char or not t_char then
					continue
				end

				local localPrimaryPart = Character.PrimaryPart
				local closestPrimaryPart, targetPrimaryPart = c_char.PrimaryPart, t_char.PrimaryPart
				if not localPrimaryPart then
					continue
				end

				if
					closestTarget == nil
					or (
						closestTarget ~= nil
						and (localPrimaryPart.Position - closestPrimaryPart.Position).Magnitude
							> (localPrimaryPart.Position - targetPrimaryPart.Position).Magnitude
					)
				then
					closestTarget = target :: any
				end
			end

			_warn(
				"Ranking Sticks",
				`Rank sticks found {(closestTarget == nil) and "no players" or closestTarget.Name} to {child.Name}`
			)

			if closestTarget == nil then
				return false
			end

			remoteFunction:InvokeServer(string.lower(actionName), "Sticks", closestTarget)
			return true
		elseif componentData.Data.Mode == "ClickOnPlayer" then
			local mouse = Player:GetMouse()
			local mouseTarget = mouse.Target
			local primPart = (Player.Character :: any).PrimaryPart

			componentData._debug("rankstick_click_on_player", "Checking if player's mouse has a target")
			if not mouseTarget then
				return false
			end

			componentData._debug(
				"rankstick_click_on_player",
				"Checking if LocalPlayer's position is too far away. (Using 'clickOnPlayerRadius' setting)"
			)
			if (primPart.Position - mouseTarget.Position).Magnitude > componentData.Data.clickOnPlayerRadius then
				return false
			end

			componentData._debug("rankstick_click_on_player", "Checking if 'Target' exists as a Player")
			local player = Players:GetPlayerFromCharacter(mouseTarget.Parent :: any)
			if not player or player == Player then
				return false
			end

			remoteFunction:InvokeServer(string.lower(actionName), "Sticks", player)
			return true
		end

		return false
	end

	componentData._debug("ranksticks_initialization", "Connecting 'onChildAdded' to character.")
	table.insert(
		Maid,
		Character.ChildAdded:Connect(function(child: Instance)
			if child:GetAttribute(custScriptName) == "RankSticks" and child:IsA("Tool") then
				local actionName = child.Name

				Maid[actionName] = {
					child.Activated:Connect(function()
						if stickDebounce then
							return
						end

						stickDebounce = true
						componentData.remoteEvent:FireServer("Animate")

						local succeeded = handleStickMode(actionName, child)
						if not succeeded then
							stickDebounce = false
							return
						end

						task.wait(0.25)
						stickDebounce = false
					end),
				}
			end
		end)
	)

	componentData._debug("ranksticks_initialization", "Connecting 'onChildRemoved' to character.")
	table.insert(
		Maid,
		Character.ChildRemoved:Connect(function(child: Instance)
			if child:GetAttribute(custScriptName) == "RankSticks" and child:IsA("Tool") then
				local existingMaid = Maid[child.Name] :: { RBXScriptConnection }
				if existingMaid ~= nil then
					componentData._debug("ranksticks_destroy", "Disconnected '" .. #existingMaid .. "' connection(s).")
					for _, v: RBXScriptConnection in pairs(existingMaid) do
						v:Disconnect()
					end
				end
			end
		end)
	)
end

return {
	Setup = onSetup,
	Destroy = onDestroy,
}
