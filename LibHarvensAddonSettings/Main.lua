if LibHarvensAddonSettings then
	error("Library loaded already. Please remove all LibHarvensAddonSettings in sub folders.")
end

LibHarvensAddonSettings = {}
LibHarvensAddonSettings.version = 20008
local LibHarvensAddonSettings = LibHarvensAddonSettings

-----
-- Control Types
-----
LibHarvensAddonSettings.ST_CHECKBOX = 1
LibHarvensAddonSettings.ST_SLIDER = 2
LibHarvensAddonSettings.ST_EDIT = 3
LibHarvensAddonSettings.ST_DROPDOWN = 4
LibHarvensAddonSettings.ST_COLOR = 5
LibHarvensAddonSettings.ST_BUTTON = 6
LibHarvensAddonSettings.ST_LABEL = 7
LibHarvensAddonSettings.ST_SECTION = 8
LibHarvensAddonSettings.ST_ICONPICKER = 9
-----

LibHarvensAddonSettings.addons = {}

local AddonSettings = ZO_Object:Subclass()
local AddonSettingsControl = ZO_Object:Subclass()

LibHarvensAddonSettings.AddonSettings = AddonSettings
LibHarvensAddonSettings.AddonSettingsControl = AddonSettingsControl


--v- Baertram
local isConsoleUI = IsConsoleUI()
local addonsStr = GetString(SI_GAME_MENU_ADDONS)
local LHAS_settingsEntryInGameMenu = ((LibAddonMenu2 ~= nil and (not isConsoleUI or (isConsoleUI and LibAddonMenu2.panelId ~= nil))) and addonsStr .." 2") or addonsStr
LibHarvensAddonSettings.LHAS_settingsEntryInGameMenu = LHAS_settingsEntryInGameMenu

-----
-- Ask before reload UI dialog (on settings changed)
-----
--Boolean variable to define if the ReloadUI asking dialog should show, or not
LibHarvensAddonSettings.reloadUIRequested = false

--Add a red /!\ icon left of the control's label text to show it requires a reloadUI
local reloadUITexture = "/esoui/art/miscellaneous/eso_icon_warning.dds"
local reloadUITextureStr = "|cFF0000".. zo_iconFormatInheritColor(reloadUITexture, 24, 24) .."|r"
local function buildRequiresReloadLabelText(selfVar, text)
	if selfVar ~= nil then
		local requiresReload = selfVar:GetValueOrCallback(selfVar.requiresReload)
		if requiresReload == true then
			return reloadUITextureStr .. " " .. text
		end
	end
	return text
end
LibHarvensAddonSettings.BuildRequiresReloadLabelText = buildRequiresReloadLabelText

--Get the currently selected LHAS addonPanel
local function getLHASActivePanel()
	for _, lastActivePanel in ipairs(LibHarvensAddonSettings.addons) do
		if lastActivePanel.selected == true then
			return lastActivePanel
		end
	end
end
LibHarvensAddonSettings.GetLHASActivePanel = getLHASActivePanel

local function showLHASSettingsMenu(panelToShow)
	if panelToShow == nil then
		if ZO_IsTableEmpty(LibHarvensAddonSettings.addons) then return end
		panelToShow = LibHarvensAddonSettings.addons[1] --get first panel
	end
	if isConsoleUI then
		if LibHarvensAddonSettings.scene == nil then return end
		--Show the gamepad menu now (if not shown)
		SCENE_MANAGER:Show("mainMenuGamepad")

		--Select the LHAS entry in the mainMenuGamepad Scene now
		LibHarvensAddonSettings.scene:Show()

		--Select the own addon panel
		panelToShow:Select()
	else
		--Show the keyboard menu
		if not GAME_MENU_SCENE:IsShowing() then
			SCENE_MANAGER:Show("gameMenuInGame")
		end

		--Select the settings entry
		local gameMenu = ZO_GameMenu_InGame.gameMenu
		local settingsMenuEntry = (gameMenu and gameMenu.headerControls and gameMenu.headerControls[GetString(SI_GAME_MENU_SETTINGS)]) or nil
		--local rootNodeChildren = (gameMenu and gameMenu.rootNode and gameMenu.rootNode.children) or nil
		if settingsMenuEntry then
			if not settingsMenuEntry.selected then
				settingsMenuEntry.control:SetSelected(true)
				settingsMenuEntry:SetOpen(true)
			end
			for _, subChildNode in ipairs(settingsMenuEntry.children) do
				local data = subChildNode.data
				if data.name == LHAS_settingsEntryInGameMenu then
					subChildNode.control:SetSelected(true)
					data.callback()
					--Select the own addon panel
					panelToShow:Select()
					return
				end
			end
		end
	end
end
LibHarvensAddonSettings.ShowSettingsMenu = showLHASSettingsMenu

--Create gamepad/console, or keyboard dialog "Ask before ReloadUI"
local askBeforeReloadUIDialogTitle = reloadUITextureStr .. " ReloadUI required"
local askBeforeReloadUIDialogText = "A setting change in an HarvensAddonSettings panel requires a reload of the UserInterface!\nIf you do not reload now, the changed settings of the panel will be reverted."
local function createConfirmReloadUIDialog()
	if (isConsoleUI or IsInGamepadPreferredMode()) and ESO_Dialogs["LHAS_GAMEPAD_CONFIRM_RELOADUI"] == nil then
		ESO_Dialogs["LHAS_GAMEPAD_CONFIRM_RELOADUI"] =
		{
			canQueue = true,
			gamepadInfo =
			{
				dialogType = GAMEPAD_DIALOGS.BASIC,
			},
			title =
			{
				text = askBeforeReloadUIDialogTitle,
			},
			mainText =
			{
				text = askBeforeReloadUIDialogText,
			},
			mustChoose = true,
			buttons =
			{
				{
					text = SI_ADDON_MANAGER_RELOAD,
					callback = function(dialog)
						dialog.data.confirmCallback()
					end
				},
				{
					text = SI_DIALOG_EXIT,
					callback = function(dialog)
						if dialog.data.declineCallback then
							dialog.data.declineCallback()
						end
					end
				},
			}
		}
	elseif ESO_Dialogs["LHAS_CONFIRM_RELOADUI"] == nil then

		ESO_Dialogs["LHAS_CONFIRM_RELOADUI"] =
		{
			canQueue = true,
			title =
			{
				text = askBeforeReloadUIDialogTitle,
			},
			mainText =
			{
				text = askBeforeReloadUIDialogText,
			},
			mustChoose = true,
			buttons =
			{
				{
					text = SI_ADDON_MANAGER_RELOAD,
					callback = function(dialog)
						dialog.data.confirmCallback()
					end
				},
				{
					text = SI_DIALOG_EXIT,
					callback = function(dialog)
						if dialog.data.declineCallback then
							dialog.data.declineCallback()
						end
					end
				},
			}
		}
	end
end

local function showReloadUIConfirmationDialog(scene, addonPanel)
	local reloadUIRequested = LibHarvensAddonSettings.reloadUIRequested
	if not reloadUIRequested then return false end

	createConfirmReloadUIDialog()

	local dialogName = isConsoleUI or IsInGamepadPreferredMode() and "LHAS_GAMEPAD_CONFIRM_RELOADUI" or "LHAS_CONFIRM_RELOADUI"
    ZO_Dialogs_ShowPlatformDialog(dialogName,
            {
                confirmCallback = function()
					--Accept the ReloadUI now
                    ReloadUI("ingame")
                end,
                declineCallback = function()
					--Do not accept the ReloadUI -> Revert the settings of the active panel to last known state
					--Passed in a scene?
					if scene and scene.AcceptHideScene then
						local lastActiceLHASPanel = addonPanel or getLHASActivePanel()
						if lastActiceLHASPanel ~= nil then
							lastActiceLHASPanel:RevertToLastState()
						else
							--No revert possible, but we need to reset the "show reloadUI dialog" variable :-(
							LibHarvensAddonSettings.reloadUIRequested = false
						end
						scene:AcceptHideScene()

					--Passed in a LHAS addon panel?
					elseif addonPanel and addonPanel.Select then
						--Re-Show the last active LHAS panel again
						addonPanel:RevertToLastState()
						addonPanel:Select()
					end
                end,
            })
    return true --prevent the selected panel to show -> Dialog first!
end
LibHarvensAddonSettings.ShowReloadUIConfirmationDialog = showReloadUIConfirmationDialog
--^- Baertram

-----
-- AddonSettingsControl class - represents single option control
-----
function AddonSettingsControl:New(callbackManager, type)
	local object = ZO_Object.New(self)
	object.type = type
	object.callbackManager = callbackManager
	if object.callbackManager then
		object.callbackManager:RegisterCallback("ValueChanged", object.SettingValueChangedCallback, object)
	end
	return object
end

--v- Baertram
function AddonSettingsControl:RequiresReloadUIIfChanged()
d("[LHAS]AddonSettingsControl:RequiresReloadUIIfChanged - requiresReload: " ..tostring((self.requiresReload == true) or (type(self.requiresReload) == "function" and self.requiresReload() == true)))
	if (self.requiresReload == true) or (type(self.requiresReload) == "function" and self.requiresReload() == true) then
		LibHarvensAddonSettings.reloadUIRequested = true
	end
end
--^- Baertram

function AddonSettingsControl:IsDisabled()
	return (self.disable == true) or (type(self.disable) == "function" and self.disable())
end

function AddonSettingsControl:SettingValueChangedCallback(changedSetting)
	if self == changedSetting then
		return
	end

	if self.getFunction then
		self:SetValue(self.getFunction())
	end

	if self.type == LibHarvensAddonSettings.ST_LABEL or self.type == LibHarvensAddonSettings.ST_SECTION then
		return
	end

	self:SetEnabled(not self:IsDisabled())
end

function AddonSettingsControl:SetAnchor(lastControl)
	if isConsoleUI then
		return
	end
	self.control:ClearAnchors()
	if lastControl == LibHarvensAddonSettings.container then
		self.control:SetAnchor(TOPLEFT, lastControl, TOPLEFT, 0, 8)
	else
		self.control:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 8)
	end
end

function AddonSettingsControl:ValueChanged(...)
	if type(self.setFunction) == "function" then
		self.setFunction(...)
		self:RequiresReloadUIIfChanged() --Baertram
	elseif type(self.clickHandler) == "function" then
		self.clickHandler(...)
		self:RequiresReloadUIIfChanged() --Baertram
	end
	if self.callbackManager then
		self.callbackManager:FireCallbacks("ValueChanged", self)
	end
end

function AddonSettingsControl:GetValueOrCallback(arg)
	return type(arg) == "function" and arg(self) or arg
end

function AddonSettingsControl:GetString(strOrId)
	return type(strOrId) == "number" and GetString(strOrId) or strOrId
end

function AddonSettingsControl:SetValue(...)
	if not self.control or not self.control.SetValue then
		return
	end
	return self.control:SetValue(...)
end

function AddonSettingsControl:ResetToDefaults()
	if self.type == LibHarvensAddonSettings.ST_DROPDOWN then
		self:SetValue(self.default)
		if self.control then
			local itemIndex = 1
			local items = self:GetValueOrCallback(self.items)
			for i = 1, #items do
				if self.items[i].name == self.default then
					itemIndex = i
					break
				end
			end
			local combobox = self.control:GetDropDown()
			self.setFunction(combobox, self.default, self.items[itemIndex])
		end
	elseif self.type == LibHarvensAddonSettings.ST_COLOR then
		self:SetValue(unpack(self.default))
		self.setFunction(unpack(self.default))
	elseif self.type == LibHarvensAddonSettings.ST_ICONPICKER then
		self:SetValue(self.default or 1)
		local items = self:GetValueOrCallback(self.items)
		local combobox = self.control:GetDropDown()
		self.setFunction(combobox, self.default, self.items[self.default])
	elseif self.setFunction then
		self:SetValue(self.default)
		self.setFunction(self.default)
	end
end

function AddonSettingsControl:GetHeight()
	return self.control:GetHeight() + 8
end
-----

-----
-- AddonSettings class - represents addon settings panel
-----
function AddonSettings:New(name, options)
	local object = ZO_Object.New(self)
	if type(options) == "table" then
		object.allowDefaults = options.allowDefaults
		object.defaultsFunction = options.defaultsFunction
		if options.allowRefresh then
			object.callbackManager = ZO_CallbackObject:New()
		end
	end
	object.name = name
	object.selected = false
	object.mouseOver = false
	object.settings = {}
	return object
end

function AddonSettings:SetAnchor(prev)
	if prev then
		self.prev = prev
		prev.next = self
		self.control:SetAnchor(TOPLEFT, prev.control, BOTTOMLEFT, 0, 8)
	else
		self.control:SetAnchor(TOPLEFT)
	end
end

function AddonSettings:AddSetting(params)
	local setting = AddonSettingsControl:New(self.callbackManager, params.type)
	self.settings[#self.settings + 1] = setting
	setting:SetupControl(params)
	return setting
end

function AddonSettings:AddSettings(params)
	local ret = {}
	for i = 1, #params do
		ret[i] = self:AddSetting(params[i])
	end
	return ret
end

--v- Baertram
function AddonSettings:DoesAnySettingRequireAReloadUI()
	for _, settingData in ipairs(self.settings) do
		if (settingData.requiresReload == true) or (type(settingData.requiresReload) == "function" and settingData.requiresReload() == true) then
			return true
		end
	end
	return false
end

function AddonSettings:SavedLastState()
	--todo Save the current state of all settings in the panel (get all getFunctions or get* data and cache it, in case any control got a requiresReload == true value)
	self.lastSaved = nil
	if self:DoesAnySettingRequireAReloadUI() then
		self.lastSaved = {}
		for settingIndex, settingData in ipairs(self.settings) do
			if settingData.type ~= LibHarvensAddonSettings.ST_LABEL and settingData.type ~= LibHarvensAddonSettings.ST_SECTION then
				local lastValue = (type(settingData.getFunction) == "function" and settingData.getFunction()) or ((type(settingData.default) == "function" and settingData.default()) or settingData.default)
				if lastValue ~= nil then
					self.lastSaved[settingIndex] = {
						label = 	settingData.label, --for comparison later (if anyone inserts a new setting "on the fly")
						lastValue = lastValue
					}
				end
			end
		end
	end
end

function AddonSettings:RevertToLastState()
	--Revert to the last saved state of all settings in the panel, before a ReloadUI dialog was shown
	if not LibHarvensAddonSettings.reloadUIRequested or ZO_IsTableEmpty(self.lastSaved) then return end
	local panelSettings = self.settings
	for settingIndex, settingDataSaved in ipairs(self.lastSaved) do
		if settingDataSaved.type ~= LibHarvensAddonSettings.ST_LABEL and settingDataSaved.type ~= LibHarvensAddonSettings.ST_SECTION then
			--Find the setting at the index and compare the name to assure we reset the correct setting
			local setting = panelSettings[settingIndex]
			if setting ~= nil and setting.label == settingDataSaved.label then
				if type(setting.setFunction) == "function" then setting.setFunction(settingDataSaved.lastValue) end
			end
		end
	end
	self.lastSaved = nil
	LibHarvensAddonSettings.reloadUIRequested = false
end
--^- Baertram

function AddonSettings:Select()
	if self.selected then
		return
	end
--v- Baertram
	if LibHarvensAddonSettings.reloadUIRequested then
		return showReloadUIConfirmationDialog(nil, getLHASActivePanel())
	end
--^- Baertram

	self:SavedLastState()

	if not isConsoleUI then
		LibHarvensAddonSettings:DetachContainer()
	end
	CALLBACK_MANAGER:FireCallbacks("LibHarvensAddonSettings_AddonSelected", self.name, self)

	if not isConsoleUI then
		LibHarvensAddonSettings:AttachContainerToControl(self.control)
		if self.prev then
			self.control:ClearAnchors()
			self.control:SetAnchor(TOPLEFT, self.prev.control, BOTTOMLEFT, 0, 8)
		end
		if self.next then
			LibHarvensAddonSettings:AttachControlToContainer(self.next.control)
		end
	end

	self.selected = true
	self:UpdateHighlight()
end

function AddonSettings:UpdateHighlight()
	if isConsoleUI then
		return
	end
	if self.selected then
		self.control:GetNamedChild("Label"):SetColor(ZO_SELECTED_TEXT:UnpackRGB())
	elseif self.mouseOver then
		self.control:GetNamedChild("Label"):SetColor(ZO_HIGHLIGHT_TEXT:UnpackRGB())
	else
		self.control:GetNamedChild("Label"):SetColor(ZO_NORMAL_TEXT:UnpackRGB())
	end
end

function AddonSettings:ResetToDefaults()
	if self.selected and self.allowDefaults then
		for i = 1, #self.settings do
			self.settings[i]:ResetToDefaults()
		end
		if type(self.defaultsFunction) == "function" then
			self.defaultsFunction()
		end
		self:UpdateControls()
	end
end

function AddonSettings:CleanUp()
	for i = 1, #self.settings do
		self.settings[i]:CleanUp()
	end
end

function AddonSettings:GetOverallHeight()
	local sum = 0
	for i = 1, #self.settings do
		sum = sum + self.settings[i]:GetHeight()
	end
	return sum
end

function AddonSettings:Clear()
	self.settings = {}
	self.selected = false
end
-----

-----
-- LibHarvensAddonSettings singleton
-----
local function RemoveColorMarkup(name)
	name = zo_strgsub(name, "|[Cc][%w][%w][%w][%w][%w][%w]", "")
	name = zo_strgsub(name, "|[Rr]", "")
	return name
end

function LibHarvensAddonSettings:AddAddon(name, options)
	name = RemoveColorMarkup(name)

	for i = 1, #self.addons do
		if self.addons[i].name == name then
			return self.addons[i]
		end
	end
	local addonSettings = AddonSettings:New(name, options)
	table.insert(self.addons, addonSettings)

	return addonSettings
end

function LibHarvensAddonSettings:DetachContainer()
	if isConsoleUI then
		return
	end
	self.container:ClearAnchors()
	if self.container.attached then
		self.container.attached:ClearAnchors()
		self.container.attached = nil
	end
end

function LibHarvensAddonSettings:AttachControlToContainer(control)
	if isConsoleUI then
		return
	end
	control:ClearAnchors()
	control:SetAnchor(TOPLEFT, self.container, BOTTOMLEFT, 0, 8)
	self.container.attached = control
end

function LibHarvensAddonSettings:AttachContainerToControl(control)
	if isConsoleUI then
		return
	end
	self.container:ClearAnchors()
	self.container:SetParent(control)
	self.container:SetAnchor(TOPLEFT, control, BOTTOMLEFT, 0, 0)
	self.container:SetHidden(false)
	self.container:SetHeight(0)
	self.container.currentHeight = 0
end

function LibHarvensAddonSettings:Initialize()
	if self.initialized then
		return
	end

	self:CreateAddonSettingsPanel()
	self:CreateControlPools()
	self:CreateAddonList()

	self.initialized = true
end
