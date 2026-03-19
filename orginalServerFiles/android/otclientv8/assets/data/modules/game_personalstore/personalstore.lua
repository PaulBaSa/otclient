--[[
  Adicionar essa funo em game_interface.lua

function getMouseGrabberWidget()
  return mouseGrabberWidget
end

]]

local MainWindow, MainButton, ItemStoreTooltip
local MainPanel, ItemEditPanel, BuyItemPanel, StartStorePanel
local ItemsPanel, EditStoreButton, StartStoreButton
local Key = "Menu"
local Opcode = 3

local editMode = true
local storeOpen = false

local CurrentStore = {}

local PersonalStoreModeOff = 0
local PersonalStoreModeOn  = 1

function init()
  connect(g_game, {
    onGameStart = refresh,
    onGameEnd = refresh,
  })
  connect(Creature, {
  	onPersonalStoreModeChange = onPersonalStoreModeChange,
  })
  MainWindow    = g_ui.displayUI('personalstore')
  MainPanel     = MainWindow:getChildById('mainPanel')
  ItemEditPanel = MainWindow:getChildById('itemEditPanel')
  BuyItemPanel  = MainWindow:getChildById('buyItemPanel')
  StartStorePanel  = MainWindow:getChildById('startStorePanel')
  
  ItemsPanel = MainPanel:getChildById('itemsPanel')
  EditStoreButton = MainPanel:getChildById('editStoreButton')
  StartStoreButton = MainPanel:getChildById('startStoreButton')

  ItemStoreTooltip = g_ui.displayUI('storetooltip')
  
  -- g_keyboard.bindKeyDown(Key, toggle)
  
  -- MainButton = modules.client_topmenu.addRightGameToggleButton('MainButton', 'Pass' .. ' ('..Key..')', '/images/topbuttons/pass', toggle)
  -- MainButton:setOn(false)
  ProtocolGame.registerExtendedOpcode(Opcode, parsePersonalStore)
  MainWindow:hide()
end

function terminate()
  disconnect(g_game, {
    onGameStart = refresh,
    onGameEnd = refresh,
  })
  
  -- g_keyboard.unbindKeyDown(Key)
  ProtocolGame.unregisterExtendedOpcode(Opcode)
  ItemStoreTooltip:destroy()
  ItemStoreTooltip = nil
  MainWindow:destroy()
  MainWindow = nil
  -- MainButton:destroy()
  -- MainButton = nil
end

function toggle()
  if MainWindow:isVisible() then
    hide()
  else
    show()
  end
  -- if MainButton:isOn() then
    -- hide()
  -- else
    -- show()
  -- end
end

function refresh()
  MainWindow:hide()
  -- MainButton:setOn(false)
end

function show()
  BuyItemPanel:hide()
  ItemEditPanel:hide()
  MainWindow:show()
  MainWindow:raise()
  MainWindow:focus()
  -- MainButton:setOn(true)
end

function hide()
  MainWindow:hide()
  -- MainButton:setOn(false)
end

-- player:setPersonalStore({name = "Teste", mode = 1})
-- player:canSellItemToPersonalStore( {y=65,x=65535,z=0})

function inEditMode()
  return editMode
end

function onPersonalStoreModeChange(creature, mode, name)
  print(mode, name)
end

function enableEditionModeOrOfflineMode()
  if CurrentStore.mode == PersonalStoreModeOn then
    g_game.getProtocolGame():sendExtendedOpcode(Opcode, json.encode({protocol = 'ClosePersonalStore'}))
  elseif CurrentStore.mode == PersonalStoreModeOff then
    editMode = not editMode
    local color = editMode and "#00FF21" or "alpha"
    for i, child in ipairs(ItemsPanel:getChildren()) do
      child:setBackgroundColor(color)
      if child.itemInfo and child.itemInfo.itemid and child.itemInfo.itemid > 0 then
        child:getChildById('buyOrEdit'):setText(editMode and "Edit" or child.itemInfo.price)
        child:getChildById('buyOrEdit'):enable()
        child:getChildById('remove'):setVisible(editMode and true or false)
        child:getChildById('remove').onClick = function()
          g_game.getProtocolGame():sendExtendedOpcode(Opcode, json.encode({protocol = 'RemoveItemFromPersonalStore', item_code = child.itemInfo.item_code}))
        end
      end
    end
    StartStoreButton:setText(editMode and "Select Item" or (CurrentStore.mode == PersonalStoreModeOff) and "Start Store" or ("Close Store"))
  end
end

function selectItemToSell()
  if itemsFull() then print("loja cheia") return end
  local gameInterface = modules.game_interface
  local mouseGrabberWidget = gameInterface.getMouseGrabberWidget()
  mouseGrabberWidget:grabMouse()
  g_mouse.pushCursor('target')
  mouseGrabberWidget.onMouseRelease = function(self, mousePosition, mouseButton)
    if mouseButton == MouseLeftButton then
	  local clickedWidget = gameInterface.getRootPanel():recursiveGetChildByPos(mousePosition, false)
	  if clickedWidget and clickedWidget:getClassName() == 'UIItem' and clickedWidget:getItem() and not clickedWidget:isVirtual() then
	    local item = clickedWidget:getItem()
		g_game.getProtocolGame():sendExtendedOpcode(Opcode, json.encode({protocol = 'SelectItemToSell', pos = item:getPosition()}))
	  end
	end
	while(g_mouse.isCursorChanged()) do
	  g_mouse.popCursor('target')
	end
	self:ungrabMouse()
	mouseGrabberWidget.onMouseRelease = nil
	mouseGrabberWidget.onMouseRelease = gameInterface.onMouseGrabberRelease
  end
end

function itemsFull()
  for i, child in ipairs(ItemsPanel:getChildren()) do
    if not child.itemInfo or not child.itemInfo.itemid or child.itemInfo.itemid == 0 then return false end
  end
  return true
end

local function doFormatMoney(money)
  local moneyMap = {
	100000, -- Thousand -- verificou esses vaalores, se suas moedas valem exatamente o que ta ali? n, mas o padrão é isso ai n ? o meu é oadrão jkk, eu n sei o padrão
	10000, -- Hundred
	100, -- Dollar
  }

  local formatMoney = {}
  local tmpMoney = 0
	
  for i, value in pairs(moneyMap) do
    tmpMoney = math.floor(money / value)
    money = money - (tmpMoney * value)     
    formatMoney[i] = tmpMoney
  end
  
  return formatMoney
end

function updatePrices(panel, price)
  if not price then price = 0 end
  for m, value in pairs(doFormatMoney(price)) do
    panel:getChildById(m):setText(value)
  end
end

function showEditItemPanel(itemInfo)
  MainPanel:hide()
  ItemEditPanel:getChildById('item'):setItemId(itemInfo.clientId)
  ItemEditPanel:getChildById('item').item_code = itemInfo.item_code
  g_game.updateRarityFrames(ItemEditPanel:getChildById('item'), itemInfo.rarity)
  ItemEditPanel:getChildById('item'):setItemCount(itemInfo.count)
  -- ItemEditPanel:getChildById('tooltip').itemInfo = itemInfo
  -- ItemEditPanel:getChildById('tooltip').onHoverChange = onStoreItemHoverChange
  -- ItemEditPanel:getChildById('tooltip').onMouseMove = updateStoreTooltipPosition
  ItemEditPanel:getChildById('count'):setMaximum(itemInfo.count)
  ItemEditPanel:getChildById('count'):setMinimum(1)
  ItemEditPanel:getChildById('count'):setValue(itemInfo.count)
  ItemEditPanel:getChildById('price'):getChildById('value'):setText(itemInfo.price)
  updatePrices(ItemEditPanel:getChildById('price'):getChildById('moneyPanel'), itemInfo.price)
  ItemEditPanel:getChildById('count').onValueChange = function(self, value)
	ItemEditPanel:getChildById('item'):setItemCount(value)
  end
  ItemEditPanel:getChildById('price'):getChildById('value').onTextChange = function(self, text, oldText)
    if tonumber(text) then
      updatePrices(ItemEditPanel:getChildById('price'):getChildById('moneyPanel'), tonumber(text))
    end
  end
  ItemEditPanel:getChildById('confirm').onClick = function()
    local count = tonumber(ItemEditPanel:getChildById('count'):getValue())
    g_game.getProtocolGame():sendExtendedOpcode(Opcode, json.encode({protocol = 'AddOrEditItemToPersonalStore', checking = itemInfo.checking, itemid = itemInfo.itemid, item_code = itemInfo.item_code, count = count, price = tonumber(ItemEditPanel:getChildById('price'):getChildById('value'):getText())}))
  end
  ItemEditPanel:show()
end

function showBuyItemPanel(itemInfo)
  MainPanel:hide()
  BuyItemPanel:getChildById('item'):setItemId(itemInfo.clientId)
  BuyItemPanel:getChildById('item').item_code = itemInfo.item_code
  g_game.updateRarityFrames(BuyItemPanel:getChildById('item'), itemInfo.rarity)
  BuyItemPanel:getChildById('item'):setItemCount(itemInfo.count)
  -- BuyItemPanel:getChildById('tooltip').itemInfo = itemInfo
  -- BuyItemPanel:getChildById('tooltip').onHoverChange = onStoreItemHoverChange
  -- BuyItemPanel:getChildById('tooltip').onMouseMove = updateStoreTooltipPosition
  BuyItemPanel:getChildById('count'):setMaximum(itemInfo.count)
  BuyItemPanel:getChildById('count'):setMinimum(1)
  BuyItemPanel:getChildById('count'):setValue(itemInfo.count)
  updatePrices(BuyItemPanel:getChildById('price'), (itemInfo.price*itemInfo.count))
  BuyItemPanel:getChildById('count').onValueChange = function(self, value)
    updatePrices(BuyItemPanel:getChildById('price'), (itemInfo.price*value))
    BuyItemPanel:getChildById('count'):setValue(value)
	BuyItemPanel:getChildById('item'):setItemCount(value)
  end
  BuyItemPanel:getChildById('confirm').onClick = function()
    g_game.getProtocolGame():sendExtendedOpcode(Opcode, json.encode({protocol = 'BuyItemFromPersonalStore', name = CurrentStore.ownername, item_code = itemInfo.item_code, count = BuyItemPanel:getChildById('count'):getValue()}))
  end
  BuyItemPanel:show()
end

function showStartStorePanel()
  MainPanel:hide()
  StartStorePanel:getChildById('description'):setText(CurrentStore.name)
  StartStorePanel:getChildById('confirm').onClick = function()
    g_game.getProtocolGame():sendExtendedOpcode(Opcode, json.encode({protocol = 'StartPersonalStore', name = StartStorePanel:getChildById('description'):getText()}))
  end
  StartStorePanel:show()
end

function showMainPanel()
  BuyItemPanel:hide()
  ItemEditPanel:hide()
  StartStorePanel:hide()
  MainPanel:show()
  local color = editMode and "#00FF21" or "alpha"
  for i, child in ipairs(ItemsPanel:getChildren()) do
    child:setBackgroundColor(color)
  end
end

function selectOrStartStore()
  if editMode then
    selectItemToSell()
  else
    if CurrentStore.mode == PersonalStoreModeOff then
  	  showStartStorePanel()
	else
	  g_game.getProtocolGame():sendExtendedOpcode(Opcode, json.encode({protocol = 'ClosePersonalStore'}))
	end
  end
end

function requestPersonalStore(name)
  g_game.getProtocolGame():sendExtendedOpcode(Opcode, json.encode({protocol = 'RequestPersonalStore', name = name}))
end

function parsePersonalStore(protocol, opcode, buffer)
  -- print(buffer)
  local personal_store = json.decode(buffer)
  if personal_store.protocol == "Close" then
    hide()
  elseif personal_store.protocol == "item_checked" then
    showEditItemPanel(personal_store)
  elseif personal_store.protocol == "ps" then
    editMode = false
    --local color = editMode and "#00FF21" or "alpha"
    for i, child in ipairs(ItemsPanel:getChildren()) do
      child:setBackgroundColor("#213C3F")
    end
    for i, child in ipairs(ItemsPanel:getChildren()) do
      child:getChildById('item'):setItemId(0)
      g_game.updateRarityFrames(child:getChildById('item'), 0)
      child:getChildById('item'):setItemCount(0)
	    child:getChildById('remove'):setVisible(false)
	    child:getChildById('buyOrEdit'):setText("")
	    child:getChildById('buyOrEdit'):disable()
	    child.onHoverChange = nil
	    child.onMouseMove = nil
      child.itemInfo = nil
    end
    MainWindow:setText(personal_store.name)
	CurrentStore = personal_store
    for n, itemInfo in ipairs(personal_store.items) do
      local child = ItemsPanel:getChildById('item'..n)
      child.itemInfo = itemInfo
      child:getChildById('item'):setItemId(itemInfo.clientId)
      child:getChildById('item').item_code = itemInfo.item_code
      g_game.updateRarityFrames(child:getChildById('item'), itemInfo.rarity)
      child:getChildById('item'):setItemCount(itemInfo.count)
      if personal_store.owner then
          child:getChildById('buyOrEdit'):setText(child.itemInfo.price)
      else
        child:getChildById('buyOrEdit'):setText("Buy")
      end
      child:getChildById('buyOrEdit'):enable()
      child:getChildById('buyOrEdit').onClick = function()
        if personal_store.owner then
          if editMode then showEditItemPanel(itemInfo) end
        else
          showBuyItemPanel(itemInfo)
        end
      end
      -- child.onHoverChange = onStoreItemHoverChange
      -- child.onMouseMove = updateStoreTooltipPosition
    end
    if personal_store.owner then
        EditStoreButton:show()
        StartStoreButton:show()
      if personal_store.mode == PersonalStoreModeOn then
        StartStoreButton:setText("Close Store")
        EditStoreButton:disable()
      else
        StartStoreButton:setText("Start Store")
        EditStoreButton:enable()
      end
    else
      EditStoreButton:hide()
      StartStoreButton:hide()
    end
	  showMainPanel()
    MainWindow:setText(personal_store.ownername.." Shop")
    MainWindow:show()
  end
end

function getPSWindow()
  return MainWindow
end

function onStoreItemHoverChange(widget, hovered)
  if hovered then
    -- ItemStoreTooltip:getChildById('image'):getChildById('item'):setItemId(widget.itemInfo.clientId)
    -- g_game.updateRarityFrames(ItemStoreTooltip:getChildById('image'):getChildById('item'), widget.itemInfo.rarity)
    -- ItemStoreTooltip:getChildById('image'):getChildById('item'):setItemCount(widget.itemInfo.count)
    -- ItemStoreTooltip:getChildById('name'):setText(widget.itemInfo.name)
    -- ItemStoreTooltip:getChildById('description'):setText("")
    -- ItemStoreTooltip:setHeight(80)
    -- updatePrices(ItemStoreTooltip:getChildById('price'), widget.itemInfo.price)
    -- ItemStoreTooltip:show()
    -- ItemStoreTooltip:raise()
    -- ItemStoreTooltip:enable()
    modules.game_tooltip.m_TooltipFunction.create(widget:getPosition(), widget, true)
  else
    -- ItemStoreTooltip:hide()
  end
end

function updateStoreTooltipPosition()
  local pos = g_window.getMousePosition()
  local windowSize = g_window.getSize()
  local widgetSize = ItemStoreTooltip:getSize()

  pos.x = pos.x + 1
  pos.y = pos.y + 1

  if windowSize.width - (pos.x + widgetSize.width) < 10 then
    pos.x = pos.x - widgetSize.width - 3
  else
    pos.x = pos.x + 10
  end

  if windowSize.height - (pos.y + widgetSize.height) < 10 then
    pos.y = pos.y - widgetSize.height - 3
  else
    pos.y = pos.y + 10
  end

  ItemStoreTooltip:setPosition(pos)
end