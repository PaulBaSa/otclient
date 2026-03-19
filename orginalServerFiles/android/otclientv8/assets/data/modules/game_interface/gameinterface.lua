gameRootPanel = nil
gameMapPanel = nil
gameRightPanels = nil
gameLeftPanels = nil
gameBottomPanel = nil
gameBottomActionPanel = nil
gameLeftActionPanel = nil
gameRightActionPanel = nil
gameLeftActions = nil
logoutButton = nil
mouseGrabberWidget = nil
countWindow = nil
logoutWindow = nil
exitWindow = nil
bottomSplitter = nil
limitedZoom = false
increaseLeftPanel = nil
decreaseLeftPanel = nil
increaseRightPanel = nil
decreaseRightPanel = nil
SchedulerLoaded = nil
FirstRightSidePanel = nil
LeftHorizontalPanel = nil
RightHorizontalPanel = nil
hookedMenuOptions = {}
lastDirTime = g_clock.millis()

local highlightedPanel
local panelsConfig = {
	totalPanels = 5,
	maxRightPanels = 4,
	maxLeftPanels = 4,
	fitSizeToHorizontalPanel = true,
	horizontalPanelHeight = 220,
	highlightWhenDrag = true
}

function loadSettings()
	local minimapHeight = g_settings.getNumber("minimapHeight")

	if minimapHeight == 0 then
		return
	end

	if RightHorizontalPanel:isVisible() then
		RightHorizontalPanel:setHeight(minimapHeight)
		gameRightPanels:setMarginTop(minimapHeight)
		modules.game_minimap.getMinimap():setHeight(minimapHeight)
	elseif LeftHorizontalPanel:isVisible() then
		LeftHorizontalPanel:setHeight(minimapHeight)
		gameLeftPanels:setMarginTop(minimapHeight)
		modules.game_minimap.getMinimap():setHeight(minimapHeight)
	end
end

function refreshSidePanels()
	local minimap = modules.game_minimap.getMinimap()

	if RightHorizontalPanel:isVisible() then
		RightHorizontalPanel:setHeight(minimap:getHeight())
		gameRightPanels:setMarginTop(minimap:getHeight())
		minimap:setParent(RightHorizontalPanel)
		minimap:setWidth(gameRightPanels:getChildCount() * 177)
	elseif LeftHorizontalPanel:isVisible() then
		LeftHorizontalPanel:setHeight(minimap:getHeight())
		gameLeftPanels:setMarginTop(minimap:getHeight())
		minimap:setParent(LeftHorizontalPanel)
		minimap:setWidth(gameLeftPanels:getChildCount() * 177)
	end

	for _, sidePanel in pairs(gameRightPanels:getChildren()) do
		sidePanel:reloadChildReorderMargin()
	end

	for _, sidePanel in pairs(gameLeftPanels:getChildren()) do
		sidePanel:reloadChildReorderMargin()
	end
end

function showHorizontalPanel(panel, parent, visible)
	local minimap = modules.game_minimap.getMinimap()

	if visible then
		panel:show()
		panel:setHeight(panelsConfig.horizontalPanelHeight)
		parent:setMarginTop(panelsConfig.horizontalPanelHeight)
		minimap:setParent(panel)
		minimap:setDraggable(false)
		minimap:getChildById("rightResizeBorder"):hide()
	else
		panel:hide()
		panel:setHeight(1)
		parent:setMarginTop(0)

		if minimap:getParent():getId() == panel:getId() then
			minimap:setParent(nil)
			getRightPanel():insertChild(1, minimap)
			minimap:setDraggable(true)
			minimap:getChildById("rightResizeBorder"):show()
		end
	end

	refreshSidePanels()
end


function showLeftHorizontalPanel(visible)
	showHorizontalPanel(LeftHorizontalPanel, gameLeftPanels, visible)

	if visible and RightHorizontalPanel:isVisible() then
		modules.client_options.setOption("showRightHorizontalPanel", false)
	end
end

function showRightHorizontalPanel(visible)
	showHorizontalPanel(RightHorizontalPanel, gameRightPanels, visible)

	if visible and LeftHorizontalPanel:isVisible() then
		modules.client_options.setOption("showLeftHorizontalPanel", false)
	end
end

function onGeometryChange(self, oldRect, newRect)
	if self:getParent():getId() == RightHorizontalPanel:getId() then
		local height = self:getHeight()

		RightHorizontalPanel:setHeight(height)
		gameRightPanels:setMarginTop(height)
	elseif self:getParent():getId() == LeftHorizontalPanel:getId() then
		local height = self:getHeight()

		LeftHorizontalPanel:setHeight(height)
		gameLeftPanels:setMarginTop(height)
	end
end

local function createSidePanel(sidePanel)
  if sidePanel:getChildCount() >= 4 then
      return
  end

  local panel = g_ui.createWidget("GameSidePanel")

  if sidePanel:getId() == gameLeftPanels:getId() then
      panel:setId("sideLeftPanel" .. sidePanel:getChildCount() + 1)
      if panelsConfig.highlightWhenDrag then
          panel:setMarginLeft(1)
      end
  elseif sidePanel:getId() == gameRightPanels:getId() then
      panel:setId("sideRightPanel" .. sidePanel:getChildCount() + 1)
      if panelsConfig.highlightWhenDrag then
          panel:setMarginRight(1)
      end
  end
  panel.loadScheduledInserts = function(self)
  end

  sidePanel:insertChild(1, panel)

  if not FirstRightSidePanel and sidePanel:getId() == gameRightPanels:getId() then
      FirstRightSidePanel = panel
  end
end

function getMainRightPanel()
	return getRightPanel()
end

function init()
  g_ui.importStyle('styles/countwindow')

  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd,
    onLoginAdvice = onLoginAdvice,
  }, true)

  connect(LocalPlayer, {
		onUpdateAutoloot = onUpdateAutoloot
	})

  -- Call load AFTER game window has been created and 
  -- resized to a stable state, otherwise the saved 
  -- settings can get overridden by false onGeometryChange
  -- events
  connect(g_app, {
    onRun = load,
    onExit = save
  })
  
  gameRootPanel = g_ui.displayUI('gameinterface')
  gameRootPanel:hide()
  gameRootPanel:lower()
  gameRootPanel.onGeometryChange = updateStretchShrink

  mouseGrabberWidget = gameRootPanel:getChildById('mouseGrabber')
  mouseGrabberWidget.onMouseRelease = onMouseGrabberRelease
  mouseGrabberWidget.onTouchRelease = mouseGrabberWidget.onMouseRelease

  local switchPanels = gameRootPanel:getChildById("switchPanels")

	increaseLeftPanel = switchPanels:getChildById("increaseLeftPanel")

	function increaseLeftPanel.onClick()
		g_settings.set("leftPanels", g_settings.getNumber("leftPanels") + 1)
		modules.client_options.setOption("leftPanels", g_settings.getNumber("leftPanels"), true)
		modules.game_interface.refreshViewMode()
	end

	decreaseLeftPanel = switchPanels:getChildById("decreaseLeftPanel")

	function decreaseLeftPanel.onClick()
		g_settings.set("leftPanels", g_settings.getNumber("leftPanels") - 1)
		modules.client_options.setOption("leftPanels", g_settings.getNumber("leftPanels"), true)
		modules.game_interface.refreshViewMode()
	end

	increaseRightPanel = switchPanels:getChildById("increaseRightPanel")

	function increaseRightPanel.onClick()
		g_settings.set("rightPanels", g_settings.getNumber("rightPanels") + 1)
		modules.client_options.setOption("rightPanels", g_settings.getNumber("rightPanels"), true)
		modules.game_interface.refreshViewMode()
	end

	decreaseRightPanel = switchPanels:getChildById("decreaseRightPanel")

	function decreaseRightPanel.onClick()
		g_settings.set("rightPanels", g_settings.getNumber("rightPanels") - 1)
		modules.client_options.setOption("rightPanels", g_settings.getNumber("rightPanels"), true)
		modules.game_interface.refreshViewMode()
	end

	bottomSplitter = gameRootPanel:getChildById("bottomSplitter")
	gameMapPanel = gameRootPanel:getChildById("gameMapPanel")
	RightHorizontalPanel = gameRootPanel:getChildById("gameRightHorizontalPanel")
	LeftHorizontalPanel = gameRootPanel:getChildById("gameLeftHorizontalPanel")
	gameRightPanels = gameRootPanel:getChildById("gameRightPanels")
	gameLeftPanels = gameRootPanel:getChildById("gameLeftPanels")
	gameBottomPanel = gameRootPanel:getChildById("gameBottomPanel")
	gameBottomActionPanel = gameRootPanel:getChildById("gameBottomActionPanel")
	gameRightActionPanel = gameRootPanel:getChildById("gameRightActionPanel")
	gameLeftActionPanel = gameRootPanel:getChildById("gameLeftActionPanel")
	gameLeftActions = gameRootPanel:getChildById("gameLeftActions")

	connect(gameLeftPanel, {
		onVisibilityChange = onLeftPanelVisibilityChange
	})

	logoutButton = modules.client_topmenu.addLeftButton("logoutButton", tr("Exit"), "/images/topbuttons/logout", tryLogout, true)

	setupLeftActions()
	refreshViewMode()
	bindKeys()
	connect(gameMapPanel, {
		onGeometryChange = updateSize,
		onVisibleDimensionChange = updateSize
	})
	connect(g_game, {
		onMapChangeAwareRange = updateSize
	})

	local settings = g_settings.getNode("game_interface")

	if settings and settings.splitterMarginBottom then
		bottomSplitter:setMarginBottom(settings.splitterMarginBottom)
	end

	if g_game.isOnline() then
		show()
	end
end

function bindKeys()
  gameRootPanel:setAutoRepeatDelay(10)

  local lastAction = 0
  g_keyboard.bindKeyPress('Escape', function() 
    if lastAction + 50 > g_clock.millis() then return end 
    lastAction = g_clock.millis()
    g_game.cancelAttackAndFollow() 
  end, gameRootPanel)
  g_keyboard.bindKeyPress('Ctrl+=', function() if g_game.getFeature(GameNoDebug) then return end gameMapPanel:zoomIn() end, gameRootPanel)
  g_keyboard.bindKeyPress('Ctrl+-', function() if g_game.getFeature(GameNoDebug) then return end gameMapPanel:zoomOut() end, gameRootPanel)
  g_keyboard.bindKeyDown('Ctrl+Q', function() tryLogout(false) end, gameRootPanel)
  g_keyboard.bindKeyDown('Ctrl+L', function() tryLogout(false) end, gameRootPanel)
  g_keyboard.bindKeyDown('Ctrl+W', function() g_map.cleanTexts() modules.game_textmessage.clearMessages() end, gameRootPanel)
end

function terminate()
  hide()

  hookedMenuOptions = {}
  markThing = nil
  

  disconnect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd,
    onLoginAdvice = onLoginAdvice
  })

  disconnect(LocalPlayer, {
		onUpdateAutoloot = onUpdateAutoloot
	})

  disconnect(gameMapPanel, { onGeometryChange = updateSize })
  connect(gameMapPanel, { onGeometryChange = updateSize, onVisibleDimensionChange = updateSize })

  increaseLeftPanel = nil
	decreaseLeftPanel = nil
	increaseRightPanel = nil
	decreaseRightPanel = nil
	FirstRightSidePanel = nil
	SchedulerLoaded = nil

  logoutButton:destroy()
  gameRootPanel:destroy()
end

function onGameStart()
	refreshViewMode()
	show()

	if not g_game.isOfficialTibia() then
		g_game.enableFeature(GameForceFirstAutoWalkStep)
	else
		g_game.disableFeature(GameForceFirstAutoWalkStep)
	end

	local panelsList = {}

	for i = gameRightPanels:getChildCount(), 0, -1 do
		if i <= gameRightPanels:getChildCount() then
			table.insert(panelsList, gameRightPanels:getChildByIndex(i))
		end
	end

	for i = 0, gameLeftPanels:getChildCount() do
		if i <= gameLeftPanels:getChildCount() then
			table.insert(panelsList, gameLeftPanels:getChildByIndex(i))
		end
	end

	for _, panel in ipairs(panelsList) do
		if panel:getImageOffsetY() > 0 then
			panel:reloadChildReorderMargin()
		end
	end

	scheduleEvent(function()
		refreshSidePanels()
		loadSettings()
	end, 50)
end

function onGameEnd()
	hide()
	modules.client_topmenu.getTopMenu():setImageColor("white")
end


function show()
	connect(g_app, {
		onClose = tryExit
	})
	modules.client_background.hide()
	gameRootPanel:show()
	gameRootPanel:focus()
	gameMapPanel:followCreature(g_game.getLocalPlayer())
	updateStretchShrink()
	logoutButton:setTooltip(tr("Logout"))
	addEvent(function()
		if not limitedZoom or g_game.isGM() then
			gameMapPanel:setMaxZoomOut(513)
			gameMapPanel:setLimitVisibleRange(false)
		else
			gameMapPanel:setMaxZoomOut(15)
			gameMapPanel:setLimitVisibleRange(true)
		end

		addEvent(loadScheduledInserts)
	end)
end

function hide()
  disconnect(g_app, { onClose = tryExit })
  logoutButton:setTooltip(tr('Exit'))

  if logoutWindow then
    logoutWindow:destroy()
    logoutWindow = nil
  end
  if exitWindow then
    exitWindow:destroy()
    exitWindow = nil
  end
  if countWindow then
    countWindow:destroy()
    countWindow = nil
  end
  gameRootPanel:hide()
  gameMapPanel:setShader("")
  modules.client_background.show()
end

function save()
  local settings = {}
  settings.splitterMarginBottom = bottomSplitter:getMarginBottom()
  g_settings.setNode('game_interface', settings)
end

function load()
	local settings = g_settings.getNode("game_interface")

	if settings and settings.splitterMarginBottom then
		bottomSplitter:setMarginBottom(settings.splitterMarginBottom)
	end
end


function onLoginAdvice(message)
  displayInfoBox(tr("For Your Information"), message)
end

function forceExit()
  g_game.cancelLogin()
  scheduleEvent(exit, 10)
  return true
end

function tryExit()
  if exitWindow then
    return true
  end

  local exitFunc = function() scheduleEvent(exit, 10) end
  local logoutFunc = function() g_game.safeLogout() exitWindow:destroy() exitWindow = nil end
  local cancelFunc = function() exitWindow:destroy() exitWindow = nil end

  exitWindow = displayGeneralBox(tr('Exit'), tr("If you shut down the program, your character might stay in the game.\nClick on 'Logout' to ensure that you character leaves the game properly.\nClick on 'Exit' if you want to exit the program without logging out your character."),
  { { text=tr('Force Exit'), callback=exitFunc },
    { text=tr('Logout'), callback=logoutFunc },
    { text=tr('Cancel'), callback=cancelFunc },
    anchor=AnchorHorizontalCenter }, logoutFunc, cancelFunc)

  return true
end

function tryLogout(prompt)
  if type(prompt) ~= "boolean" then
    prompt = true
  end
  if not g_game.isOnline() then
    exit()
    return
  end

  if logoutWindow then
    return
  end

  local msg, yesCallback
  if not g_game.isConnectionOk() then
    msg = 'Your connection is failing, if you logout now your character will be still online, do you want to force logout?'

    yesCallback = function()
      g_game.forceLogout()
      if logoutWindow then
        logoutWindow:destroy()
        logoutWindow=nil
      end
    end
  else
    msg = 'Are you sure you want to logout?'

    yesCallback = function()
      g_game.safeLogout()
      if logoutWindow then
        logoutWindow:destroy()
        logoutWindow=nil
      end
    end
  end

  local noCallback = function()
    logoutWindow:destroy()
    logoutWindow=nil
  end

  if prompt then
    logoutWindow = displayGeneralBox(tr('Logout'), tr(msg), {
      { text=tr('Yes'), callback=yesCallback },
      { text=tr('No'), callback=noCallback },
      anchor=AnchorHorizontalCenter}, yesCallback, noCallback)
  else
     yesCallback()
  end
end

function updateStretchShrink()
	if modules.client_options.getOption("dontStretchShrink") and not alternativeView then
		gameMapPanel:setVisibleDimension({
			width = 15,
			height = 11
		})
		bottomSplitter:setMarginBottom(bottomSplitter:getMarginBottom() + (gameMapPanel:getHeight() - 352) - 10)
	end
end

function onMouseGrabberRelease(self, mousePosition, mouseButton)
	if mouseButton == MouseTouch then
		return
	end

	if selectedThing == nil then
		return false
	end

	if mouseButton == MouseLeftButton then
		local clickedWidget = gameRootPanel:recursiveGetChildByPos(mousePosition, false)

		if clickedWidget then
			if selectedType == "use" then
				onUseWith(clickedWidget, mousePosition)
			elseif selectedType == "trade" then
				onTradeWith(clickedWidget, mousePosition)
			end
		end
	end

	selectedThing = nil

	g_mouse.popCursor("target")
	self:ungrabMouse()
	gameMapPanel:blockNextMouseRelease(true)

	return true
end

local function isInArray(array, value)
	for i, v in ipairs(array) do
		if v == value then
			return true
		end
	end

	return false
end
function onUseWith(clickedWidget, mousePosition)
  if clickedWidget:getClassName() == 'UIGameMap' then
    local tile = clickedWidget:getTile(mousePosition)
    if tile then      
      if selectedThing:isFluidContainer() or selectedThing:isMultiUse() then      
        if selectedThing:getId() == 3180 or selectedThing:getId() == 3156 then
          -- special version for mwall
          g_game.useWith(selectedThing, tile:getTopUseThing(), selectedSubtype)      
        else
          g_game.useWith(selectedThing, tile:getTopMultiUseThingEx(clickedWidget:getPositionOffset(mousePosition)), selectedSubtype)
        end
      else
        g_game.useWith(selectedThing, tile:getTopUseThing(), selectedSubtype)
      end
    end
  elseif clickedWidget:getClassName() == 'UIItem' and not clickedWidget:isVirtual() then
    g_game.useWith(selectedThing, clickedWidget:getItem(), selectedSubtype)
  elseif clickedWidget:getClassName() == 'UICreatureButton' then
    local creature = clickedWidget:getCreature()
    if creature then
      g_game.useWith(selectedThing, creature, selectedSubtype)
    end
  end
end

function onTradeWith(clickedWidget, mousePosition)
  if clickedWidget:getClassName() == 'UIGameMap' then
    local tile = clickedWidget:getTile(mousePosition)
    if tile then
      g_game.requestTrade(selectedThing, tile:getTopCreatureEx(clickedWidget:getPositionOffset(mousePosition)))
    end
  elseif clickedWidget:getClassName() == 'UICreatureButton' then
    local creature = clickedWidget:getCreature()
    if creature then
      g_game.requestTrade(selectedThing, creature)
    end
  end
end

function startUseWith(thing, subType)
  gameMapPanel:blockNextMouseRelease()
  if not thing then return end
  if g_ui.isMouseGrabbed() then
    if selectedThing then
      selectedThing = thing
      selectedType = 'use'
    end
    return
  end
  selectedType = 'use'
  selectedThing = thing
  selectedSubtype = subType or 0
  mouseGrabberWidget:grabMouse()
  g_mouse.pushCursor('target')
end

function startTradeWith(thing)
  if not thing then return end
  if g_ui.isMouseGrabbed() then
    if selectedThing then
      selectedThing = thing
      selectedType = 'trade'
    end
    return
  end
  selectedType = 'trade'
  selectedThing = thing
  mouseGrabberWidget:grabMouse()
  g_mouse.pushCursor('target')
end

function isMenuHookCategoryEmpty(category)
  if category then
    for _,opt in pairs(category) do
      if opt then return false end
    end
  end
  return true
end

function addMenuHook(category, name, callback, condition, shortcut)
  if not hookedMenuOptions[category] then
    hookedMenuOptions[category] = {}
  end
  hookedMenuOptions[category][name] = {
    callback = callback,
    condition = condition,
    shortcut = shortcut
  }
end

function removeMenuHook(category, name)
  if not name then
    hookedMenuOptions[category] = {}
  else
    hookedMenuOptions[category][name] = nil
  end
end

function createThingMenu(menuPosition, lookThing, useThing, creatureThing)
  if not g_game.isOnline() then return end

  local menu = g_ui.createWidget('PopupMenu')
  menu:setGameMenu(true)

  local classic = modules.client_options.getOption('classicControl')
  local shortcut = nil

  if not classic and not g_app.isMobile() then shortcut = '(Shift)' else shortcut = nil end
  if lookThing then
    menu:addOption(tr('Look'), function() g_game.look(lookThing) end, shortcut)
  end
	if creatureThing then
    if creatureThing:isPlayer() then
      menu:addOption(
        tr("Inspect"),
        function()
          modules.game_inspect.inspect(creatureThing)
        end
      )
    end
  end
  local localPlayer = g_game.getLocalPlayer()
  if not classic and not g_app.isMobile() then shortcut = '(Ctrl)' else shortcut = nil end
  if useThing then
    if useThing:isContainer() then
      if useThing:getParentContainer() then
        menu:addOption(tr('Open'), function() g_game.open(useThing, useThing:getParentContainer()) end, shortcut)
        menu:addOption(tr('Open in new window'), function() g_game.open(useThing) end)
      else
        menu:addOption(tr('Open'), function() g_game.open(useThing) end, shortcut)
      end
      if not useThing:isNotMoveable() and useThing:isPickupable() then
        if useThing:getLootCategory() ~= 0 then
          menu:addSeparator()
          menu:addOption(tr('Remove loot category'), function() modules.game_containers.onRemoveLootCategory(useThing) end, shortcut, "#ff0000")
          menu:addOption(tr('Edit loot category'), function() modules.game_containers.onLootCategory(useThing) end, shortcut, "#ffae00")
          menu:addOption(tr('Pass loot category'), function() g_game.addLootCategory(useThing, LOOT_CATEGORY_COPY) end, shortcut, "#AAFF00")
        else
          menu:addOption(tr('Add loot category'), function() modules.game_containers.onLootCategory(useThing) end, shortcut, "#fbff00")
        end
      end
    else
      if useThing:isMultiUse() then
        menu:addOption(tr('Use with ...'), function() startUseWith(useThing) end, shortcut)
      else
        menu:addOption(tr('Use'), function() g_game.use(useThing) end, shortcut)
      end
    end
    if useThing:isPickupable() then
      menu:addSeparator()
      menu:addOption(tr('Open auto loot list'), function() openAutolootWindow() end, shortcut, "#00fffb")
      if localPlayer:isInAutoLootList(useThing:getId()) then
        menu:addOption(tr('Remove from auto loot list'), function() localPlayer:removeAutoLoot(useThing:getId()) end, shortcut, "#ff0000")
      else
        menu:addOption(tr('Add to auto loot list'), function() localPlayer:addAutoLoot(useThing:getId()) end, shortcut, "#22ff00")
      end
    end

    if useThing:isRotateable() then
      menu:addOption(tr('Rotate'), function() g_game.rotate(useThing) end)
    end
    if useThing:isWrapable() then
      menu:addOption(tr('Wrap'), function() g_game.wrap(useThing) end)
    end
    if useThing:isUnwrapable() then
      menu:addOption(tr('Unwrap'), function() g_game.wrap(useThing) end)
    end

    if g_game.getFeature(GameBrowseField) and useThing:getPosition().x ~= 0xffff then
      menu:addOption(tr('Browse Field'), function() g_game.browseField(useThing:getPosition()) end)
    end
  end

  if lookThing and not lookThing:isCreature() and not lookThing:isNotMoveable() and lookThing:isPickupable() then
    menu:addSeparator()
    menu:addOption(tr('Trade with ...'), function() startTradeWith(lookThing) end)
  end

  if lookThing then
    local parentContainer = lookThing:getParentContainer()
    if parentContainer and parentContainer:hasParent() then
      menu:addOption(tr('Move up'), function() g_game.moveToParentContainer(lookThing, lookThing:getCount()) end)
    end
  end

  if creatureThing then
    menu:addSeparator()

    if creatureThing:isLocalPlayer() then
      menu:addOption(tr('Set Outfit'), function() g_game.requestOutfit() end)
      menu:addOption(tr('Open Personal Store'), function() modules.game_personalstore.requestPersonalStore(creatureThing:getName()) end)

      if g_game.getFeature(GamePlayerMounts) then
        if not localPlayer:isMounted() then
          menu:addOption(tr('Mount'), function() localPlayer:mount() end)
        else
          menu:addOption(tr('Dismount'), function() localPlayer:dismount() end)
        end
      end
      
      if creatureThing:isPartyMember() then
        if creatureThing:isPartyLeader() then
          if creatureThing:isPartySharedExperienceActive() then
            menu:addOption(tr('Disable Shared Experience'), function() g_game.partyShareExperience(false) end)
          else
            menu:addOption(tr('Enable Shared Experience'), function() g_game.partyShareExperience(true) end)
          end
        end
        menu:addOption(tr('Leave Party'), function() g_game.partyLeave() end)
      end

    else
      local localPosition = localPlayer:getPosition()
      if not classic and not g_app.isMobile() then shortcut = '(Alt)' else shortcut = nil end
      if creatureThing:getPosition().z == localPosition.z then
        if g_game.getAttackingCreature() ~= creatureThing then
          menu:addOption(tr('Attack'), function() g_game.attack(creatureThing) end, shortcut)
        else
          menu:addOption(tr('Stop Attack'), function() g_game.cancelAttack() end, shortcut)
        end

        if g_game.getFollowingCreature() ~= creatureThing then
          menu:addOption(tr('Follow'), function() g_game.follow(creatureThing) end)
        else
          menu:addOption(tr('Stop Follow'), function() g_game.cancelFollow() end)
        end
      end

      if creatureThing:isPlayer() then
        menu:addSeparator()
        local creatureName = creatureThing:getName()
        menu:addOption(tr('Message to %s', creatureName), function() g_game.openPrivateChannel(creatureName) end)
        if modules.game_console.getOwnPrivateTab() then
          menu:addOption(tr('Invite to private chat'), function() g_game.inviteToOwnChannel(creatureName) end)
          menu:addOption(tr('Exclude from private chat'), function() g_game.excludeFromOwnChannel(creatureName) end) -- [TODO] must be removed after message's popup labels been implemented
        end
        if not localPlayer:hasVip(creatureName) then
          menu:addOption(tr('Add to VIP list'), function() g_game.addVip(creatureName) end)
        end

        if modules.game_console.isIgnored(creatureName) then
          menu:addOption(tr('Unignore') .. ' ' .. creatureName, function() modules.game_console.removeIgnoredPlayer(creatureName) end)
        else
          menu:addOption(tr('Ignore') .. ' ' .. creatureName, function() modules.game_console.addIgnoredPlayer(creatureName) end)
        end

        local localPlayerShield = localPlayer:getShield()
        local creatureShield = creatureThing:getShield()

        if localPlayerShield == ShieldNone or localPlayerShield == ShieldWhiteBlue then
          if creatureShield == ShieldWhiteYellow then
            menu:addOption(tr('Join %s\'s Party', creatureThing:getName()), function() g_game.partyJoin(creatureThing:getId()) end)
          else
            menu:addOption(tr('Invite to Party'), function() g_game.partyInvite(creatureThing:getId()) end)
          end
        elseif localPlayerShield == ShieldWhiteYellow then
          if creatureShield == ShieldWhiteBlue then
            menu:addOption(tr('Revoke %s\'s Invitation', creatureThing:getName()), function() g_game.partyRevokeInvitation(creatureThing:getId()) end)
          end
        elseif localPlayerShield == ShieldYellow or localPlayerShield == ShieldYellowSharedExp or localPlayerShield == ShieldYellowNoSharedExpBlink or localPlayerShield == ShieldYellowNoSharedExp then
          if creatureShield == ShieldWhiteBlue then
            menu:addOption(tr('Revoke %s\'s Invitation', creatureThing:getName()), function() g_game.partyRevokeInvitation(creatureThing:getId()) end)
          elseif creatureShield == ShieldBlue or creatureShield == ShieldBlueSharedExp or creatureShield == ShieldBlueNoSharedExpBlink or creatureShield == ShieldBlueNoSharedExp then
            menu:addOption(tr('Pass Leadership to %s', creatureThing:getName()), function() g_game.partyPassLeadership(creatureThing:getId()) end)
          else
            menu:addOption(tr('Invite to Party'), function() g_game.partyInvite(creatureThing:getId()) end)
          end
        end
        
        if modules.game_guildmanagement.canInvite(creatureName) then
          menu:addOption(tr('Invite to Guild'), function () modules.game_guildmanagement.invitePlayer(creatureName) end)
        elseif modules.game_guildmanagement.canKick(creatureName) then
          menu:addOption(tr('Kick from Guild'), function () modules.game_guildmanagement.kickPlayer(creatureName) end)
        end
      end
    end

    if modules.game_ruleviolation.hasWindowAccess() and creatureThing:isPlayer() then
      menu:addSeparator()
      menu:addOption(tr('Rule Violation'), function() modules.game_ruleviolation.show(creatureThing:getName()) end)
    end

    menu:addSeparator()
    menu:addOption(tr('Copy Name'), function() g_window.setClipboardText(creatureThing:getName()) end)
  end

  -- hooked menu options
  for _,category in pairs(hookedMenuOptions) do
    if not isMenuHookCategoryEmpty(category) then
      menu:addSeparator()
      for name,opt in pairs(category) do
        if opt and opt.condition(menuPosition, lookThing, useThing, creatureThing) then
          menu:addOption(name, function() opt.callback(menuPosition, 
            lookThing, useThing, creatureThing) end, opt.shortcut)
        end
      end
    end
  end

  if g_game.getFeature(GameBot) and useThing and useThing:isItem() then
    menu:addSeparator()
    local useThingId = useThing:getId()
    if useThing:getSubType() > 1 then
      menu:addOption("ID: " .. useThingId .. " SubType: " .. g_game..setClipboardText(useThingId), function() end)    
    else
      menu:addOption("ID: " .. useThingId, function() g_game.setClipboardText(useThingId) end)
    end
  end

  menu:display(menuPosition)
end

function processMouseAction(menuPosition, mouseButton, autoWalkPos, lookThing, useThing, creatureThing, attackCreature, marking)
  local keyboardModifiers = g_keyboard.getModifiers()
  local player = g_game.getLocalPlayer()
    if creatureThing and creatureThing:getPosition().z == autoWalkPos.z and creatureThing:isNpc() and mouseButton == MouseRightButton then
      g_game.talkChannel(11, 0, "hi")
     return true
    end

  if g_app.isMobile() then
    if mouseButton == MouseRightButton then
      createThingMenu(menuPosition, lookThing, useThing, creatureThing)
      return true      
    end
    if mouseButton ~= MouseLeftButton and mouseButton ~= MouseTouch2 and mouseButton ~= MouseTouch3 then
      return false
    end
    local action = getLeftAction()
    if action == "look" then
      if lookThing then
        resetLeftActions()
        g_game.look(lookThing)
        return true    
      end
      return true    
    elseif action == "use" then
      if useThing then
        resetLeftActions()
        if useThing:isContainer() then
          if useThing:getParentContainer() then
            g_game.open(useThing, useThing:getParentContainer())
          else
            g_game.open(useThing)
          end
          return true
        elseif useThing:isMultiUse() then
          startUseWith(useThing)
          return true
        else
          g_game.use(useThing)
          return true
        end
      end
      return true
    elseif action == "attack" then
      if attackCreature and attackCreature ~= player then
        resetLeftActions()
        if creatureThing:getPersonalStoreMode() >= 1 then
          modules.game_personalstore.requestPersonalStore(creatureThing:getName())
        else
          g_game.attack(attackCreature)
		end
        return true
      elseif creatureThing and creatureThing ~= player and creatureThing:getPosition().z == autoWalkPos.z then
        resetLeftActions()
        if creatureThing:getPersonalStoreMode() >= 1 then
          modules.game_personalstore.requestPersonalStore(creatureThing:getName())
        else
          g_game.attack(creatureThing)
		end
        return true
      end
      return true
    elseif action == "follow" then
      if attackCreature and attackCreature ~= player then
        resetLeftActions()
        g_game.follow(attackCreature)
        return true
      elseif creatureThing and creatureThing ~= player and creatureThing:getPosition().z == autoWalkPos.z then
        resetLeftActions()
        g_game.follow(creatureThing)
        return true
      end
      return true
    elseif not autoWalkPos and useThing then
      createThingMenu(menuPosition, lookThing, useThing, creatureThing)      
      return true
    end
  elseif not modules.client_options.getOption('classicControl') then
    if keyboardModifiers == KeyboardNoModifier and mouseButton == MouseRightButton then
      createThingMenu(menuPosition, lookThing, useThing, creatureThing)
      return true
    elseif lookThing and keyboardModifiers == KeyboardShiftModifier and (mouseButton == MouseLeftButton or mouseButton == MouseRightButton) then
      g_game.look(lookThing)
      return true
    elseif useThing and keyboardModifiers == KeyboardCtrlModifier and (mouseButton == MouseLeftButton or mouseButton == MouseRightButton) then
      if useThing:isContainer() then
        if useThing:getParentContainer() then
          g_game.open(useThing, useThing:getParentContainer())
        else
          g_game.open(useThing)
        end
        return true
      elseif useThing:isMultiUse() then
        startUseWith(useThing)
        return true
      else
        g_game.use(useThing)
        return true
      end
      return true
    elseif attackCreature and g_keyboard.isAltPressed() and (mouseButton == MouseLeftButton or mouseButton == MouseRightButton) then
        if creatureThing:getPersonalStoreMode() >= 1 then
          modules.game_personalstore.requestPersonalStore(creatureThing:getName())
        else
          g_game.attack(attackCreature)
		end
      return true
    elseif creatureThing and creatureThing:getPosition().z == autoWalkPos.z and g_keyboard.isAltPressed() and (mouseButton == MouseLeftButton or mouseButton == MouseRightButton) then
      if creatureThing:getPersonalStoreMode() >= 1 then
        modules.game_personalstore.requestPersonalStore(creatureThing:getName())
      else
        g_game.attack(creatureThing)
      end
      return true
    end
  else -- classic control
    if useThing and keyboardModifiers == KeyboardNoModifier and mouseButton == MouseRightButton and not g_mouse.isPressed(MouseLeftButton) then
      local player = g_game.getLocalPlayer()
      if attackCreature and attackCreature ~= player then
        if creatureThing:getPersonalStoreMode() >= 1 then
          modules.game_personalstore.requestPersonalStore(creatureThing:getName())
        else
          g_game.attack(attackCreature)
		end
        return true
      elseif creatureThing and creatureThing ~= player and creatureThing:getPosition().z == autoWalkPos.z then
        if creatureThing:getPersonalStoreMode() >= 1 then
          modules.game_personalstore.requestPersonalStore(creatureThing:getName())
        else
          g_game.attack(creatureThing)
		end
        return true
      elseif useThing:isContainer() then
        if useThing:getParentContainer() then
          g_game.open(useThing, useThing:getParentContainer())
          return true
        else
          g_game.open(useThing)
          return true
        end
      elseif useThing:isMultiUse() then
        startUseWith(useThing)
        return true
      else
        g_game.use(useThing)
        return true
      end
      return true
    elseif lookThing and keyboardModifiers == KeyboardShiftModifier and (mouseButton == MouseLeftButton or mouseButton == MouseRightButton) then
      g_game.look(lookThing)
      return true
    elseif lookThing and ((g_mouse.isPressed(MouseLeftButton) and mouseButton == MouseRightButton) or (g_mouse.isPressed(MouseRightButton) and mouseButton == MouseLeftButton)) then
      g_game.look(lookThing)
      return true
    elseif useThing and keyboardModifiers == KeyboardCtrlModifier and (mouseButton == MouseLeftButton or mouseButton == MouseRightButton) then
      createThingMenu(menuPosition, lookThing, useThing, creatureThing)
      return true
    elseif attackCreature and g_keyboard.isAltPressed() and (mouseButton == MouseLeftButton or mouseButton == MouseRightButton) then
        if creatureThing:getPersonalStoreMode() >= 1 then
          modules.game_personalstore.requestPersonalStore(creatureThing:getName())
        else
          g_game.attack(attackCreature)
		end
      return true
    elseif creatureThing and creatureThing:getPosition().z == autoWalkPos.z and g_keyboard.isAltPressed() and (mouseButton == MouseLeftButton or mouseButton == MouseRightButton) then
        if creatureThing:getPersonalStoreMode() >= 1 then
          modules.game_personalstore.requestPersonalStore(creatureThing:getName())
        else
          g_game.attack(creatureThing)
		end
      return true
    end
  end

  local player = g_game.getLocalPlayer()
  player:stopAutoWalk()  

  if autoWalkPos and keyboardModifiers == KeyboardNoModifier and (mouseButton == MouseLeftButton or mouseButton == MouseTouch2 or mouseButton == MouseTouch3) then
    local autoWalkTile = g_map.getTile(autoWalkPos)
    if autoWalkTile and not autoWalkTile:isWalkable(true) then
      modules.game_textmessage.displayFailureMessage(tr('Sorry, not possible.'))
      return false
    end
    player:autoWalk(autoWalkPos)
    return true
  end

  return false
end

function moveStackableItem(item, toPos)
  if countWindow then
    return
  end
  if g_keyboard.isCtrlPressed() then
    g_game.move(item, toPos, item:getCount())
    return
  elseif g_keyboard.isShiftPressed() then
    g_game.move(item, toPos, 1)
    return
  end
  local count = item:getCount()

  countWindow = g_ui.createWidget('CountWindow', rootWidget)
  local itembox = countWindow:getChildById('item')
  local scrollbar = countWindow:getChildById('countScrollBar')
  itembox:setItemId(item:getId())
  itembox:setItemCount(count)
  scrollbar:setMaximum(count)
  scrollbar:setMinimum(1)
  scrollbar:setValue(count)

  local spinbox = countWindow:getChildById('spinBox')
  spinbox:setMaximum(count)
  spinbox:setMinimum(0)
  spinbox:setValue(0)
  spinbox:hideButtons()
  spinbox:focus()
  spinbox.firstEdit = true

  local spinBoxValueChange = function(self, value)
    spinbox.firstEdit = false
    scrollbar:setValue(value)
  end
  spinbox.onValueChange = spinBoxValueChange

  local check = function()
    if spinbox.firstEdit then
      spinbox:setValue(spinbox:getMaximum())
      spinbox.firstEdit = false
    end
  end
  local okButton = countWindow:getChildById('buttonOk')
  local moveFunc = function()
    g_game.move(item, toPos, itembox:getItemCount())
    okButton:getParent():destroy()
    countWindow = nil
  end
  local cancelButton = countWindow:getChildById('buttonCancel')
  local cancelFunc = function()
    cancelButton:getParent():destroy()
    countWindow = nil
  end

  
  g_keyboard.bindKeyPress("Up", function() check() spinbox:up() end, spinbox)
  g_keyboard.bindKeyPress("Down", function() check() spinbox:down() end, spinbox)
  g_keyboard.bindKeyPress("Right", function() check() spinbox:up() end, spinbox)
  g_keyboard.bindKeyPress("Left", function() check() spinbox:down() end, spinbox)
  g_keyboard.bindKeyPress("PageUp", function() check() spinbox:setValue(spinbox:getValue()+10) end, spinbox)
  g_keyboard.bindKeyPress("PageDown", function() check() spinbox:setValue(spinbox:getValue()-10) end, spinbox)
  g_keyboard.bindKeyPress("Enter", function() moveFunc() end, spinbox)

  scrollbar.onValueChange = function(self, value)
    itembox:setItemCount(value)
    spinbox.onValueChange = nil
    spinbox:setValue(value)
    spinbox.onValueChange = spinBoxValueChange
  end
  countWindow.onEnter = moveFunc
  countWindow.onEscape = cancelFunc

  okButton.onClick = moveFunc
  cancelButton.onClick = cancelFunc
end

function isSchedulerLoaded()
	return SchedulerLoaded
end

function loadScheduledInserts()
  SchedulerLoaded = true
  local panelsList = gameRootPanel:getWidgetsWithScheduler()

  for _, widget in pairs(panelsList) do
      if type(widget.loadScheduledInserts) == "function" then
          widget:loadScheduledInserts()
      else
      end
  end
end

function getRootPanel()
  return gameRootPanel
end

function getMapPanel()
  return gameMapPanel
end

local function addRightPanel()
	createSidePanel(gameRightPanels)
end

function getFirstRightSidePanel()
	return FirstRightSidePanel
end

function getRightPanel()
	if gameRightPanels:getChildCount() == 0 then
		addRightPanel()
	end

	local panel = gameRightPanels:getChildByIndex(-1)

	if panel:getId() == "sideRightPanel1" then
		panel = FirstRightSidePanel
	end

	return panel
end

local rightPanels = {
	{}
}

function getLeftPanel()
	if gameLeftPanels:getChildCount() >= 1 then
		return gameLeftPanels:getChildByIndex(-1)
	end

	return getRightPanel()
end

function getContainerPanel()
	local containerPanel = g_settings.getNumber("containerPanel")

	if containerPanel >= 5 then
		containerPanel = containerPanel - 4

		if gameRightPanels:getChildCount() == 1 then
			return gameRightPanels:getChildByIndex(1)
		elseif gameRightPanels:getChildCount() == 2 then
			if containerPanel >= 2 then
				return gameRightPanels:getChildByIndex(1)
			else
				return gameRightPanels:getChildByIndex(2)
			end
		elseif gameRightPanels:getChildCount() == 3 then
			if containerPanel >= 3 then
				return gameRightPanels:getChildByIndex(1)
			elseif containerPanel == 2 then
				return gameRightPanels:getChildByIndex(2)
			elseif containerPanel == 3 then
				return gameRightPanels:getChildByIndex(3)
			end
		elseif gameRightPanels:getChildCount() == 4 then
			if containerPanel >= 4 then
				return gameRightPanels:getChildByIndex(1)
			elseif containerPanel == 3 then
				return gameRightPanels:getChildByIndex(2)
			elseif containerPanel == 2 then
				return gameRightPanels:getChildByIndex(3)
			elseif containerPanel == 1 then
				return gameRightPanels:getChildByIndex(4)
			end
		end
	end

	if gameLeftPanels:getChildCount() == 0 then
		return getRightPanel()
	end

	return gameLeftPanels:getChildByIndex(math.min(containerPanel, gameLeftPanels:getChildCount()))
end

local function addLeftPanel()
	createSidePanel(gameLeftPanels)
end

local function removeRightPanel()
	if gameRightPanels:getChildCount() <= 1 then
		return
	end

	local panel = gameRightPanels:getChildByIndex(1)

	for _, child in ipairs(panel:getChildren()) do
		if child.UIMiniWindowContainer and not child.isBlankMainPanel then
			if child.forceOpen then
				child:minimize(true)
			else
				child:close()
			end
		end
	end

	panel:moveTo(FirstRightSidePanel)
	gameRightPanels:removeChild(panel)
end

local function removeLeftPanel()
	if gameLeftPanels:getChildCount() == 0 then
		return
	end

	local panel = gameLeftPanels:getChildByIndex(-1)

	for _, child in ipairs(panel:getChildren()) do
		if child.UIMiniWindowContainer and not child.isBlankMainPanel then
			if child.forceOpen then
				child:minimize(true)
			else
				child:close()
			end
		end
	end

	panel:moveTo(FirstRightSidePanel)
	gameLeftPanels:removeChild(panel)
end

function getBottomPanel()
  return gameBottomPanel
end

function getBottomActionPanel()
  return gameBottomActionPanel
end

function getLeftActionPanel()
  return gameLeftActionPanel
end

function getRightActionPanel()
  return gameRightActionPanel
end

function refreshViewMode()
	local rightPanels = g_settings.getNumber("rightPanels") - gameRightPanels:getChildCount()
	local leftPanels = g_settings.getNumber("leftPanels") - 1 - gameLeftPanels:getChildCount()

	while rightPanels ~= 0 do
		if rightPanels > 0 then
			addRightPanel()

			rightPanels = rightPanels - 1
		else
			removeRightPanel()

			rightPanels = rightPanels + 1
		end
	end

	while leftPanels ~= 0 do
		if leftPanels > 0 then
			addLeftPanel()

			leftPanels = leftPanels - 1
		else
			removeLeftPanel()

			leftPanels = leftPanels + 1
		end
	end

	if not g_game.isOnline() then
		return
	end

	local minimumWidth = (g_settings.getNumber("rightPanels") + g_settings.getNumber("leftPanels") - 1) * 200 + 200

	minimumWidth = math.max(minimumWidth, g_resources.getLayout() == "mobile" and 640 or 800)

	g_window.setMinimumSize({
		width = minimumWidth,
		height = g_resources.getLayout() == "mobile" and 360 or 600
	})

	if minimumWidth > g_window.getWidth() then
		local oldPos = g_window.getPosition()
		local size = {
			width = minimumWidth,
			height = g_window.getHeight()
		}

		g_window.resize(size)
		g_window.move(oldPos)
	end

	for i = 1, gameRightPanels:getChildCount() + gameLeftPanels:getChildCount() do
		local panel

		if i > gameRightPanels:getChildCount() then
			panel = gameLeftPanels:getChildByIndex(i - gameRightPanels:getChildCount())
		else
			panel = gameRightPanels:getChildByIndex(i)
		end

		panel:setImageColor("white")
	end

	gameMapPanel:setMarginLeft(0)
	gameMapPanel:setMarginRight(0)
	gameMapPanel:setMarginTop(0)
	gameMapPanel:setVisibleDimension({
		width = 15,
		height = 11
	})
	g_game.changeMapAwareRange(50, 30)
	gameMapPanel:addAnchor(AnchorLeft, "gameLeftActionPanel", AnchorRight)
	gameMapPanel:addAnchor(AnchorRight, "gameRightActionPanel", AnchorLeft)
	gameMapPanel:addAnchor(AnchorBottom, "gameBottomActionPanel", AnchorTop)
	gameMapPanel:setKeepAspectRatio(false)
	gameMapPanel:setLimitVisibleRange(false)
	gameMapPanel:setZoom(11)
	gameMapPanel:setOn(false)
	modules.client_topmenu.getTopMenu():setImageColor("white")

	if modules.game_console then
		modules.game_console.switchMode(false)
	end

	if g_settings.getBoolean("cacheMap") then
		g_game.enableFeature(GameBiggerMapCache)
	end

	updateSize()

	local leftPanelsCount = g_settings.getNumber("leftPanels") - 1
	local rightPanelsCount = g_settings.getNumber("rightPanels")

	if panelsConfig.totalPanels > 0 then
		local count = leftPanelsCount + rightPanelsCount

		increaseLeftPanel:setEnabled(count < panelsConfig.totalPanels)
		decreaseLeftPanel:setEnabled(leftPanelsCount > 0)
		increaseRightPanel:setEnabled(count < panelsConfig.totalPanels)
		decreaseRightPanel:setEnabled(rightPanelsCount > 1)
	else
		increaseLeftPanel:setEnabled(leftPanelsCount < panelsConfig.maxLeftPanels)
		decreaseLeftPanel:setEnabled(leftPanelsCount > 0)
		increaseRightPanel:setEnabled(rightPanelsCount < panelsConfig.maxRightPanels)
		decreaseRightPanel:setEnabled(rightPanelsCount > 1)
	end

	refreshSidePanels()
end

function onMobileMount()
	local localPlayer = g_game.getLocalPlayer()
	if not localPlayer:isMounted() then
		localPlayer:mount()
	else
		localPlayer:dismount()
	end
end

function limitZoom()
  limitedZoom = true
end

function updateSize()
	if g_app.isMobile() then
		return
	end

	if modules.game_stats then
		modules.game_stats.ui:setMarginTop(0)
	end
end


function setupLeftActions()
	if not g_app.isMobile() then
		return
	end

	for _, widget in ipairs(gameLeftActions:getChildren()) do
		widget.image:setChecked(false)

		widget.lastClicked = 0

		function widget.onClick()
			if widget.image:isChecked() then
				widget.image:setChecked(false)

				if widget.doubleClickAction and widget.lastClicked + 200 > g_clock.millis() then
					widget.doubleClickAction()
				end

				return
			end

			resetLeftActions()
			widget.image:setChecked(true)

			widget.lastClicked = g_clock.millis()
		end
	end

	if gameLeftActions.use then
		function gameLeftActions.use.doubleClickAction()
			local player = g_game.getLocalPlayer()
			local dir = player:getDirection()
			local usePos = player:getPrewalkingPosition(true)

			if dir == North then
				usePos.y = usePos.y - 1
			elseif dir == East then
				usePos.x = usePos.x + 1
			elseif dir == South then
				usePos.y = usePos.y + 1
			elseif dir == West then
				usePos.x = usePos.x - 1
			end

			local tile = g_map.getTile(usePos)

			if not tile then
				return
			end

			local thing = tile:getTopUseThing()

			if thing then
				g_game.use(thing)
			end
		end
	end

	if gameLeftActions.attack then
		function gameLeftActions.attack.doubleClickAction()
			local battlePanel = modules.game_battle.battlePanel
			local attackedCreature = g_game.getAttackingCreature()
			local child = battlePanel:getFirstChild()

			if child and (not child.creature or not child:isOn()) then
				child = nil
			end

			if child then
				g_game.attack(child.creature)
			else
				g_game.attack(nil)
			end
		end
	end

	if gameLeftActions.follow then
		function gameLeftActions.follow.doubleClickAction()
			local battlePanel = modules.game_battle.battlePanel
			local attackedCreature = g_game.getAttackingCreature()
			local child = battlePanel:getFirstChild()

			if child and (not child.creature or not child:isOn()) then
				child = nil
			end

			if child then
				g_game.follow(child.creature)
			else
				g_game.follow(nil)
			end
		end
	end

	if gameLeftActions.look then
		function gameLeftActions.look.doubleClickAction()
			local battlePanel = modules.game_battle.battlePanel
			local attackedCreature = g_game.getAttackingCreature()
			local child = battlePanel:getFirstChild()

			if child and (not child.creature or child:isHidden()) then
				child = nil
			end

			if child then
				g_game.look(child.creature)
			end
		end
	end

	if not gameLeftActions.chat then
		return
	end

	function gameLeftActions.chat.onClick()
      if gameBottomPanel:getHeight() == 0 then
        gameBottomPanel:setHeight(90)
      elseif gameBottomPanel:getHeight() == 90 then
        gameBottomPanel:setHeight(250)
      else
        gameBottomPanel:setHeight(0)
      end
      end
    end

function resetLeftActions()
  for _, widget in ipairs(gameLeftActions:getChildren()) do
    widget.image:setChecked(false)
    widget.lastClicked = 0
  end
end

function getLeftAction()
  for _, widget in ipairs(gameLeftActions:getChildren()) do
    if widget.image:isChecked() then
      return widget:getId()
    end
  end
  return ""
end

function isChatVisible()
  return gameBottomPanel:getHeight() >= 5
end

function updateTextEdit(self)
  autolootAcceptButton:setEnabled(self:getText() ~= "")
end

function updateSearchEdit(self)
  if not autolootItemsList then
    return true
  end

  local text = self:getText()
  for _, widget in pairs(autolootItemsList:getChildren()) do
    if string.find(widget.name:lower(), text:lower()) then
      widget:show()
    else
      widget:hide()
    end
  end
end

function clearSearchEdit()
  if not autolootWindow then
    return true
  end

  autolootWindow:getChildById("textSearch"):clearText()
end

function onUpdateAutoloot(self, id, name, remove)
  if not autolootItemsList then
    return true
  end

  if remove then
    local widget = autolootItemsList:getChildById(id)
    if widget then
      widget:destroy()
    end
  else
    local widget = g_ui.createWidget("AutolootItem", autolootItemsList)
    widget.name = name
    widget:setId(id)
    widget:getChildById("item"):setItemId(id)
    widget:getChildById("name"):setText(name)
  end
  autolootTextEdit:clearText()
end

function closeAutolootWindow()
  if not autolootWindow then
    return true
  end

  autolootWindow:destroy()
  autolootWindow = nil
  autolootItemsList = nil
  autolootAcceptButton = nil
  autolootTextEdit = nil
end

function openAutolootWindow(clientId)
  if  autolootWindow then
    return true
  end

  autolootWindow = g_ui.displayUI('auto_loot_window')
  autolootWindow.clientId = clientId
  autolootItemsList = autolootWindow:getChildById('itemsList')
  autolootAcceptButton = autolootWindow:getChildById('button')
  autolootTextEdit = autolootWindow:getChildById('textEdit')
  autolootTextEdit:setText(clientId)

  local localPlayer = g_game.getLocalPlayer()
  local items = localPlayer:getAutolootItems()
  for id, name in pairs(items) do
    onUpdateAutoloot(localPlayer, id, name, false)
  end
end

function removeFromAutolootList(self)
  local localPlayer = g_game.getLocalPlayer()
  localPlayer:removeAutoLoot(tonumber(self:getId()), "")
end

function addToAutolootList()
  print(1)
  if not autolootWindow then
    return true
  end

  print(2)
  local localPlayer = g_game.getLocalPlayer()
  local text = autolootTextEdit:getText()
  if tonumber(text) then
    -- Send clientId
    localPlayer:addAutoLoot(tonumber(text), "")
    print(3)
  else
    -- Send name
    localPlayer:addAutoLoot(0, text)
    print(4)
  end
end

function findContentPanelAvailable(child, minContentHeight)
	local panelsList = {}

	for i = gameRightPanels:getChildCount(), 0, -1 do
		if i <= gameRightPanels:getChildCount() then
			table.insert(panelsList, gameRightPanels:getChildByIndex(i))
		end
	end

	for i = 0, gameLeftPanels:getChildCount() do
		if i <= gameLeftPanels:getChildCount() then
			table.insert(panelsList, gameLeftPanels:getChildByIndex(i))
		end
	end

	if child.containerWindow then
		local panel = getContainerPanel()

		if panel:isVisible() and panel:fits(child, minContentHeight, 0) >= 0 and not panel.isBlankMainPanel then
			return panel, panel:fits(child, minContentHeight, 0)
		end
	end

	for _, v in ipairs(panelsList) do
		if v:isVisible() and v:fits(child, minContentHeight, 0) >= 0 and not v.isBlankMainPanel then
			return v, v:fits(child, minContentHeight, 0)
		end
	end

	return nil, 0
end

function highlightPanel(panel)
	if not panelsConfig.highlightWhenDrag then
		return
	end

	if panel ~= nil and highlightedPanel ~= nil and highlightedPanel == panel then
		return
	end

	if panel == nil then
		if highlightedPanel ~= nil and highlightedPanel:getClassName() == "UIMiniWindowContainer" then
			highlightedPanel:reloadChildReorderMargin()
		end

		highlightedPanel = nil
	end

	local panelsList = {}

	for i = gameRightPanels:getChildCount(), 0, -1 do
		if i <= gameRightPanels:getChildCount() then
			table.insert(panelsList, gameRightPanels:getChildByIndex(i))
		end
	end

	for i = 0, gameLeftPanels:getChildCount() do
		if i <= gameLeftPanels:getChildCount() then
			table.insert(panelsList, gameLeftPanels:getChildByIndex(i))
		end
	end

	for _, v in ipairs(panelsList) do
		if v.isHighlightedByDrag then
			v.isHighlightedByDrag = nil

			v:setBorderWidth(0)

			for _, c in ipairs(v:getChildren()) do
				c:setBorderWidthRight(0)
				c:setBorderWidthLeft(0)
			end
		end

		if panel ~= nil and v == panel then
			highlightedPanel = panel
			v.isHighlightedByDrag = true

			v:setBorderWidth(2)
			v:setBorderColor("#FFFFFF")

			for _, c in ipairs(v:getChildren()) do
				c:setBorderWidthRight(2)
				c:setBorderWidthLeft(2)
				c:setBorderColor("#FFFFFF")
			end
		end
	end
end

function getMouseGrabberWidget()
  return mouseGrabberWidget
end
