--!nocheck
--// Services \\--
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

--// Types \\--
type tweenServiceElement = {
	Play: () -> (),
	Pause: () -> (),
	Cancel: () -> (),
	Destroy: () -> (),
	setCallback: (...(playbackState: Enum.PlaybackState) -> ()) -> (),
}
type Tweens = (Inst: Instance, TweenInfo, { [string]: any }) -> tweenServiceElement

--// Variables \\--
local Definitions = require(script.Parent.Parent.Definitions)
local oldUIData = require(script.oldUI)
local frameComponents = script.Frames
local notifiedAboutBetaUsage = false
local truncHistory, truncMaxFrames = {}, 0
local Maid = {
	Parent = {},
	Children = {},
}

--// UI Variables \\--
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local UI = script:FindFirstChild("Interface")
local Frame = UI and UI.Frame or nil
local Content, Top, Buttons = UI and Frame.Content or nil, UI and Frame.Top or nil, UI and Frame.Buttons or nil
local currentOpenFrame, isToggled = nil, false
local onSetup, onDestroy, _toggleUI, topBarButton

--// Functions \\--
-- Changes the color of the active topbar button to be a brighter white.
local function _changeSelectorHighlight(Tweens: Tweens, frameName: string)
	for _, topButton: Instance in ipairs(Buttons.Holder:GetChildren()) do
		if not topButton:IsA("ImageButton") then
			continue
		end

		local TI = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
		local textTransparencyToShiftTo = (frameName == topButton.Name) and 0 or 0.6
		local iconTransparencyToShiftTo = (frameName == topButton.Name) and 0 or 0.5

		Tweens(topButton.Label, TI, {
			TextTransparency = textTransparencyToShiftTo,
		}):Play()

		Tweens(topButton.Icon, TI, {
			ImageTransparency = iconTransparencyToShiftTo,
		}):Play()
	end
end

-- Protected calls to prevent any issues with loading/executing a frame's module.
local function _safelyLoadModuleAndRun(module: ModuleScript, subCommand: string, ...: any)
	local _, requiredModule = pcall(require, module)
	pcall(requiredModule[subCommand], ...)
end

local function onMouseHoveringOverButtonsFrame(componentData: Definitions.componentData, override: boolean?)
	local TI = TweenInfo.new(0.25, Enum.EasingStyle.Quint)
	for i = 1, #Buttons.Holder:GetChildren() do
		local child = Buttons.Holder:GetChildren()[i]
		if not child:IsA("ImageButton") then
			continue
		end

		if override then
			child.Label.Frame.Size = UDim2.fromScale(0, 1)
			continue
		end

		componentData
			.Tweens(child.Label.Frame, TI, {
				Size = UDim2.fromScale(0, 1),
			})
			:Play()
	end

	if override then
		Content.Size = UDim2.fromScale(0.8, 0.825)
	end

	componentData
		.Tweens(Content, TI, {
			Size = UDim2.fromScale(0.8, 0.825),
		})
		:Play()
end

local function onMouseStopsHoveringOverButtonsFrame(componentData: Definitions.componentData, override: boolean?)
	local TI = TweenInfo.new(0.25, Enum.EasingStyle.Quint)
	for i = 1, #Buttons.Holder:GetChildren() do
		local child = Buttons.Holder:GetChildren()[i]
		if not child:IsA("ImageButton") then
			continue
		end

		if override then
			child.Label.Frame.Size = UDim2.fromScale(1, 1)
			continue
		end

		componentData
			.Tweens(child.Label.Frame, TI, {
				Size = UDim2.fromScale(1, 1),
			})
			:Play()
	end

	if override then
		Content.Size = UDim2.fromScale(0.94, 0.825)
		return
	end

	componentData
		.Tweens(Content, TI, {
			Size = UDim2.fromScale(0.94, 0.825),
		})
		:Play()
end

local function _openFrame(componentData: Definitions.componentData, frameName: string)
	local newFrame = Content:FindFirstChild(frameName)
	local tweenInOutInfo = TweenInfo.new(0.75, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut)
	local Tweens: Tweens = componentData.Tweens

	-- We can't proceed if there's no frame available.
	if not newFrame then
		componentData._warn("UI Error", "No frame could be found with the name '" .. frameName .. "'!")
		return
	end

	-- Tweens out the frame that's already opened.
	if currentOpenFrame ~= nil then
		-- Since this UI has no frames behind it, we want to ensure the 'frameName'
		-- isn't the same as the one being opened.
		if currentOpenFrame.Name == frameName then
			return
		end

		-- Detect when the opening frame is already being tweened. (Hot fix for when switching tabs quickly)
		local endPosition = UDim2.fromScale(-0.5, 0.5)
		if truncHistory[1] == currentOpenFrame.Name and currentOpenFrame.Position.X.Scale > 0.5 then
			endPosition = UDim2.fromScale(1.5, 0.5)
		end

		local newCurrentReference = currentOpenFrame
		local previousFrameModule = frameComponents:FindFirstChild(newCurrentReference.Name)

		if previousFrameModule and previousFrameModule:IsA("ModuleScript") then
			_safelyLoadModuleAndRun(previousFrameModule, "Destroy", newCurrentReference, componentData)
		end

		local Tween = Tweens(newCurrentReference, tweenInOutInfo, {
			Position = endPosition,
		})

		Tween:setCallback(function(playBackState)
			if playBackState ~= Enum.PlaybackState.Completed then
				return
			end

			newCurrentReference.Position = UDim2.fromScale(1.5, 0.5)
		end)

		Tween:Play()
	end

	local frameModule = frameComponents:FindFirstChild(frameName)
	if not frameModule or not frameModule:IsA("ModuleScript") then
		componentData._warn("UI Error", "No module could be found for page '" .. frameName .. "'!")
		return
	end

	currentOpenFrame = newFrame
	local Tween = Tweens(newFrame, tweenInOutInfo, {
		Position = UDim2.fromScale(0.5, 0.5),
	})

	Tween:Play()

	table.insert(truncHistory, 1, frameName)
	if #truncHistory > truncMaxFrames then
		componentData._debug("interface_tabs", "Truncating tab history...")
		truncHistory = componentData.Table.Truncate(truncHistory, truncMaxFrames)
	end

	_safelyLoadModuleAndRun(frameModule, "Setup", newFrame, componentData)
	_changeSelectorHighlight(componentData.Tweens, frameName)
end

-- Safely disconnects and destroys any active frames.
local function _onExitButtonClicked(componentData: Definitions.componentData): ()
	_toggleUI(componentData)
end

-- Toggles the 'Enabled' property of the GUI & destroys any existing modular connections.
function _toggleUI(componentData: Definitions.componentData)
	isToggled = not isToggled

	if not isToggled then
		onDestroy(componentData)
		return
	end

	UI.Enabled = true

	-- Setup top button tab buttons.
	for _, componentButton: TextButton in ipairs(Buttons.Holder:GetChildren()) do
		if not componentButton:IsA("ImageButton") or not componentButton.Visible then
			continue
		end

		table.insert(
			Maid.Children,
			componentButton.MouseButton1Click:Connect(function()
				_openFrame(componentData, componentButton.Name)
			end)
		)
	end

	-- Exit button
	table.insert(
		Maid.Children,
		Top.Exit.MouseButton1Click:Connect(function()
			_onExitButtonClicked(componentData)
		end)
	)

	-- Main frame's dragging mechanics
	do
		local isDragging = false
		local startX, startY, startFramePos
		table.insert(
			Maid.Children,
			Top.Drag.MouseButton1Down:Connect(function()
				isDragging = true

				startX, startY = Mouse.X, Mouse.Y
				startFramePos = Frame.Position
			end)
		)

		table.insert(
			Maid.Children,
			Top.Drag.MouseButton1Up:Connect(function()
				isDragging = false
			end)
		)

		table.insert(
			Maid.Children,
			Mouse.Move:Connect(function()
				if not isDragging then
					return
				end

				local distX, distY = startX - Mouse.X, startY - Mouse.Y
				componentData
					.Tweens(Frame, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
						Position = startFramePos - UDim2.fromOffset(distX, distY),
					})
					:Play()
			end)
		)
	end

	-- Resize mobile user's text size to hopefully fit better.
	-- I don't want to hear that this is a bad solution.
	if UserInputService.TouchEnabled then
		for _, uiTextConstraint: UITextSizeConstraint in ipairs(UI:GetDescendants()) do
			if not uiTextConstraint:IsA("UITextSizeConstraint") then
				continue
			end

			uiTextConstraint.MaxTextSize -= 8
		end

		Frame.Size = UDim2.fromScale(1, 0.45)
	end

	local visibleFrames = componentData.Table.Filter(Buttons.Holder:GetChildren(), function(button: GuiBase2d)
		return button:IsA("ImageButton") and button.Visible == true
	end)

	local foundFrameThatsVisible = visibleFrames[1]
	if not foundFrameThatsVisible then
		return -- Odd, why enable the UI if you have no tabs to open?
	end

	truncMaxFrames = #visibleFrames

	-- CANCEL: Ensure the ranking frame is always the first to open.
	-- - If developers can remove tabs, why hard-code 'Ranking' frame?
	_openFrame(componentData, foundFrameThatsVisible.Name)

	-- Add connection to mouse hovering over buttons frame.
	if UserInputService.MouseEnabled then
		onMouseStopsHoveringOverButtonsFrame(componentData, true)
		componentData._debug("interface_side_bar", "Establishing connection between 'Buttons' and 'Content' frames.")

		-- Uses render step instead of '.MouseEnter' due to the mouse being detected inside the
		-- 'Buttons' frame but the top frame being the 'Content' frame.
		local sideBarOpened = false
		RunService:BindToRenderStep(
			`vibez_interface_side_bar_{componentData.Identifier}`,
			Enum.RenderPriority.Last.Value + 1,
			function()
				local playerGui = Player:FindFirstChild("PlayerGui") :: PlayerGui
				if not playerGui then
					return
				end

				-- Unfortunately, resizing the buttons frame causes movement for the buttons so this
				-- has to be the only solution?
				local guiObjects = playerGui:GetGuiObjectsAtPosition(Mouse.X, Mouse.Y)
				local contentExists = table.find(guiObjects, Content)
				local buttonsExists = table.find(guiObjects, Buttons)

				if
					(contentExists and not buttonsExists)
					or (not contentExists and not buttonsExists) and sideBarOpened
				then
					sideBarOpened = false
					onMouseStopsHoveringOverButtonsFrame(componentData)
				elseif not contentExists and buttonsExists and not sideBarOpened then
					sideBarOpened = true
					onMouseHoveringOverButtonsFrame(componentData)
				end
			end
		)
	else -- Ensure the sidebar is always open.
		componentData._debug("interface_side_bar", "Sidebar options are remaining open.")
		onMouseHoveringOverButtonsFrame(componentData, true)
	end
end

function onDestroy(componentData: Definitions.componentData)
	if not componentData.Data.useBeta then
		return oldUIData.Destroy
	end

	UI.Enabled = false
	UI.Frame.Position = UDim2.fromScale(0.5, 0.5)

	componentData.Disconnect(Maid.Children)
	table.clear(Maid.Children)

	if currentOpenFrame == nil then
		return
	end

	_safelyLoadModuleAndRun(frameComponents:FindFirstChild(currentOpenFrame.Name), "Destroy", componentData)
	pcall(RunService.UnbindFromRenderStep, RunService, `vibez_interface_side_bar_{componentData.Identifier}`)

	currentOpenFrame.Position = UDim2.fromScale(1.5, 0.5)
	currentOpenFrame = nil

	return
end

function onSetup(componentData: Definitions.componentData)
	local staffInformation = componentData.remoteFunction:InvokeServer("staffCheck", "Interface")
	if
		typeof(staffInformation) ~= "table"
		or not staffInformation.Rank
		or staffInformation.Rank < componentData.Data.MinRank
	then
		componentData._debug("staff_check", "Staff check failed for Interface.")
		return
	end

	if not componentData.Data.useBeta then
		componentData._warn("Vibez Setup", "Setting up V1 Interface.")
		oldUIData.Setup(componentData)
		return
	elseif componentData.Data.useBeta and UI == nil then
		componentData._warn(
			"Vibez Setup",
			"V2 Interface is not within this instance of the wrapper! Please ensure you're using the right version...\nSetting up V1 Interface."
		)
		oldUIData.Setup(componentData)
		return
	end

	onDestroy(componentData)

	if notifiedAboutBetaUsage == false then
		notifiedAboutBetaUsage = nil
		componentData._warn(
			"Vibez Beta",
			"Your group owner has opted to use our in-development UI, please keep in mind that this UI is still being worked on and can contain bugs!"
		)
	end

	for _, ignoredTab: string in ipairs(componentData.Data.nonViewableTabs) do
		for _, tab: GuiButton in ipairs(Buttons.Holder:GetChildren()) do
			if tab.Name:lower():sub(1, #ignoredTab) ~= ignoredTab:lower() then
				continue
			end

			tab.Visible = false
			componentData._debug("interface_tab_removal", `'{tab.Name}' tab has been hidden.`)
		end
	end

	local interfaceData = componentData.Data
	if topBarButton ~= nil then
		componentData._debug(
			"interface_initialization",
			"Initialization of topbar button failed due to one already existing."
		)
		return
	end

	--stylua: ignore
	topBarButton = componentData.TopbarPlus
		.new()
		:setImage(interfaceData.iconImageId)
		:setCaption(interfaceData.iconToolTip)
		:align(interfaceData.iconPosition)
		:bindToggleKey(Enum.KeyCode[interfaceData.iconKeybind])
		.toggled:Connect(function(state: boolean)
			if state then
				_toggleUI(componentData)
				return
			end

			_onExitButtonClicked(componentData)
		end)

	-- Apply group name as the title.
	local groupNameLabel = Top.Left.Title
	local isOk, groupInfo = pcall(GroupService.GetGroupInfoAsync, GroupService, componentData.GroupId)
	groupNameLabel.Text = isOk and groupInfo.Name or ""

	componentData._debug("interface_initialization", "Setup completed.")
end

return {
	Setup = onSetup,
	Destroy = onDestroy,
}
