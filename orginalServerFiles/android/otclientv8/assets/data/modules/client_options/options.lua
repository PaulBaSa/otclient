-- chunkname: @/modules/client_options/options.lua

local defaultOptions = {
	smartWalk = false,
	showPing = true,
	showFps = true,
	dontStretchShrink = false,
	showLeftHorizontalPanel = false,
	wsadWalking = false,
	walkFirstStepDelay = 200,
	walkTurnDelay = 150,
	walkTeleportDelay = 200,
	walkCtrlTurnDelay = 150,
	profile = 1,
	antialiasing = true,
	showRightHorizontalPanel = true,
	walksync = false,
	countReachPlayer = false,
	vsync = true,
	hotkeyDelay = 30,
	turnDelay = 30,
	fullscreen = false,
	topHealtManaBar = false,
	displayCreatureBars = true,
	showHealthManaCircle = false,
	displayMana = true,
	displayHealth = true,
	displayNames = true,
	optimizationLevel = 1,
	backgroundFrameRate = 60,
	containerPanel = 5,
	leftPanels = 0,
	rightPanels = 1,
	openPrivateChatWhenReceivePrivateMessage = false,
	showPrivateMessagesOnScreen = true,
	showPrivateMessagesInConsole = true,
	showTimestampsInConsole = true,
	showInfoMessagesInConsole = true,
	showEventMessagesInConsole = true,
	showStatusMessagesInConsole = true,
	autoChaseOverride = true,
	smartMoveItems = false,
	layout = DEFAULT_LAYOUT,
	cacheMap = g_app.isMobile(),
	classicControl = not g_app.isMobile(),
}
local optionsWindow, optionsButton, optionsTabBar
local options = {}
local extraOptions = {}
local generalPanel, interfacePanel, consolePanel, graphicsPanel, extrasPanel

function init()
	for k,v in pairs(defaultOptions) do
	  g_settings.setDefault(k, v)
	  options[k] = v
	end
	for _, v in ipairs(g_extras.getAll()) do
		extraOptions[v] = g_extras.get(v)
	  g_settings.setDefault("extras_" .. v, extraOptions[v])
	end
  
	optionsWindow = g_ui.displayUI('options')
	optionsWindow:hide()
  
	optionsTabBar = optionsWindow:getChildById('optionsTabBar')
	optionsTabBar:setContentWidget(optionsWindow:getChildById('optionsTabContent'))
  
	g_keyboard.bindKeyDown('Ctrl+Shift+F', function() toggleOption('fullscreen') end)
	g_keyboard.bindKeyDown('Ctrl+N', toggleDisplays)
  
	generalPanel = g_ui.loadUI('game')
	optionsTabBar:addTab(tr('Game'), generalPanel, '')
	
	interfacePanel = g_ui.loadUI('interface')
	optionsTabBar:addTab(tr('Interface'), interfacePanel, '')  
  
	consolePanel = g_ui.loadUI('console')
	optionsTabBar:addTab(tr('Console'), consolePanel, '')
  
	graphicsPanel = g_ui.loadUI('graphics')
	optionsTabBar:addTab(tr('Graphics'), graphicsPanel, '')
	
	extrasPanel = g_ui.createWidget('OptionPanel')
	for _, v in ipairs(g_extras.getAll()) do
	  local extrasButton = g_ui.createWidget('OptionCheckBox')
	  extrasButton:setId(v)
	  extrasButton:setText(g_extras.getDescription(v))
	  extrasPanel:addChild(extrasButton)
	end
  
	optionsButton = modules.client_topmenu.addLeftButton('optionsButton', tr('Options'), '/images/topbuttons/options', toggle)
	
	addEvent(function() setup() end)
	
	connect(g_game, { onGameStart = online,
					   onGameEnd = offline })                    
  end

function terminate()
	disconnect(g_game, {
		onGameStart = online,
		onGameEnd = offline
	})
	g_keyboard.unbindKeyDown("Ctrl+Shift+F")
	g_keyboard.unbindKeyDown("Ctrl+N")
	optionsWindow:destroy()
	optionsButton:destroy()
end

function setup()
	-- load options
	for k,v in pairs(defaultOptions) do
	  if type(v) == 'boolean' then
		setOption(k, g_settings.getBoolean(k), true)
	  elseif type(v) == 'number' then
		setOption(k, g_settings.getNumber(k), true)
	  elseif type(v) == 'string' then
		setOption(k, g_settings.getString(k), true)
	  end
	end
	 
	
	if g_game.isOnline() then
	  online()
	end  
  end

function toggle()
	if optionsWindow:isVisible() then
		hide()
	else
		show()
	end
end

function show()
	optionsWindow:show()
	optionsWindow:raise()
	optionsWindow:focus()
end

function hide()
	optionsWindow:hide()
end

function toggleDisplays()
	if options.displayNames and options.displayHealth and options.displayMana then
		setOption("displayNames", false)
	elseif options.displayHealth then
		setOption("displayHealth", false)
		setOption("displayMana", false)
	elseif not options.displayNames and not options.displayHealth then
		setOption("displayNames", true)
	else
		setOption("displayHealth", true)
		setOption("displayMana", true)
	end
end

function toggleOption(key)
	setOption(key, not getOption(key))
end

function setOption(key, value, force)
	if extraOptions[key] ~= nil then
		g_extras.set(key, value)
		g_settings.set("extras_" .. key, value)

		if key == "debugProxy" and modules.game_proxy then
			if value then
				modules.game_proxy.show()
			else
				modules.game_proxy.hide()
			end
		end

		return
	end

	if modules.game_interface == nil then
		return
	end

	if not force and options[key] == value then
		return
	end

	local gameMapPanel = modules.game_interface.getMapPanel()

	if key == "vsync" then
		g_window.setVerticalSync(value)

		local gameMapPanel = modules.game_interface.getMapPanel()

		gameMapPanel:setKeepAspectRatio(gameMapPanel:isKeepAspectRatioEnabled())
	elseif key == "showFps" then
		modules.client_topmenu.setFpsVisible(value)

		if modules.game_stats and modules.game_stats.ui.fps then
			modules.game_stats.ui.fps:setVisible(value)
		end
	elseif key == "showPing" then
		modules.client_topmenu.setPingVisible(value)

		if modules.game_stats and modules.game_stats.ui.ping then
			modules.game_stats.ui.ping:setVisible(value)
		end
	elseif key == "fullscreen" then
		g_window.setFullscreen(value)
	elseif key == "showHealthManaCircle" then
		modules.game_healthinfo.healthCircle:setVisible(value)
		modules.game_healthinfo.healthCircleFront:setVisible(value)
		modules.game_healthinfo.manaCircle:setVisible(value)
		modules.game_healthinfo.manaCircleFront:setVisible(value)
	elseif key == "backgroundFrameRate" then
		local text, v = value, value

		if value <= 0 or value >= 201 then
			text = "max"
			v = 0
		end

		graphicsPanel:getChildById("backgroundFrameRateLabel"):setText(tr("Game framerate limit: %s", text))
		g_app.setMaxFps(v)
	elseif key == "optimizationLevel" then
		g_adaptiveRenderer.setLevel(value - 2)
	elseif key == "displayNames" then
		gameMapPanel:setDrawNames(value)
	elseif key == "displayHealth" then
		gameMapPanel:setDrawPlayerBars(value)
	elseif key == "displayMana" then
		gameMapPanel:setDrawManaBar(value)
	elseif key == "displayCreatureBars" then
		gameMapPanel:setDrawHealthBars(value)
	elseif key == "dontStretchShrink" then
		addEvent(function()
			modules.game_interface.updateStretchShrink()
		end)
	elseif key == "wsadWalking" then
		if modules.game_console and modules.game_console.consoleToggleChat:isChecked() ~= value then
			modules.game_console.consoleToggleChat:setChecked(value)
		end
	elseif key == "hotkeyDelay" then
		generalPanel:getChildById("hotkeyDelayLabel"):setText(tr("Hotkey delay: %s ms", value))
	elseif key == "walkFirstStepDelay" then
		generalPanel:getChildById("walkFirstStepDelayLabel"):setText(tr("Walk delay after first step: %s ms", value))
	elseif key == "walkTurnDelay" then
		generalPanel:getChildById("walkTurnDelayLabel"):setText(tr("Walk delay after turn: %s ms", value))
	elseif key == "walkTeleportDelay" then
		generalPanel:getChildById("walkTeleportDelayLabel"):setText(tr("Walk delay after teleport: %s ms", value))
	elseif key == "walkCtrlTurnDelay" then
		generalPanel:getChildById("walkCtrlTurnDelayLabel"):setText(tr("Walk delay after ctrl turn: %s ms", value))
	elseif key == "antialiasing" then
		g_app.setSmooth(value)
	elseif key == "showLeftHorizontalPanel" then
		modules.game_interface.showLeftHorizontalPanel(value)
	elseif key == "showRightHorizontalPanel" then
		modules.game_interface.showRightHorizontalPanel(value)
	end

	for _, panel in pairs(optionsTabBar:getTabsPanel()) do
		local widget = panel:recursiveGetChildById(key)

		if widget then
			if widget:getStyle().__class == "UICheckBox" then
				widget:setChecked(value)

				break
			end

			if widget:getStyle().__class == "UIScrollBar" then
				widget:setValue(value)

				break
			end

			if widget:getStyle().__class == "UIComboBox" then
				if type(value) == "string" then
					widget:setCurrentOption(value, true)

					break
				end

				if value == nil or value < 1 then
					value = 1
				end

				if widget.currentIndex ~= value then
					widget:setCurrentIndex(value, true)
				end
			end

			break
		end
	end

	g_settings.set(key, value)

	options[key] = value

	if key == "rightPanels" or key == "leftPanels" then
		modules.game_interface.refreshViewMode()
	end
end

function getOption(key)
	return options[key]
end

function addTab(name, panel, icon)
	optionsTabBar:addTab(name, panel, icon)
end

function addButton(name, func, icon)
	optionsTabBar:addButton(name, func, icon)
end

function online()
	g_app.setSmooth(g_settings.getBoolean("antialiasing"))
end

local function isInArray(array, value)
	for i, v in ipairs(array) do
		if v == value then
			return true
		end
	end

	return false
end
