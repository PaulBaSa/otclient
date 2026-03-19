OffsetManager = {}

local offsetWindow = nil
local offsetButton = nil
local outfitWidget = nil
local itemWidget = nil
local effectWidget = nil
local currentDirection = nil
local otmlData = { creatures = {}, items = {}, effects = {} }
local filename = "Tibia.otml"
local directory = "data/things/1098/"
local OffsetOptions = {"Outfit", "Item", "Effect"}
local currentDisplacementType = nil
local currentSubDisplacement = nil
local isSubOutfitEnabled = false

local function validateNumericInput(inputWidget)
  inputWidget:setText(inputWidget:getText():gsub("[^%d%-]", ""))
end

local offsets = {
    ["left"] = { offsetX = 0, offsetY = 0 },
    ["right"] = { offsetX = 0, offsetY = 0 },
    ["up"] = { offsetX = 0, offsetY = 0 },
    ["down"] = { offsetX = 0, offsetY = 0 }
}

function init()
  g_ui.importStyle('offset.otui')
  loadOtmlFile()
  backupOtmlFile()

  offsetButton = modules.client_topmenu.addLeftGameButton(
    'offsetButton', 
    tr('Offset Manager'), 
    '/images/game/offset/icon',  
    OffsetManager.toggle, 
    false, 
    1
  )

  offsetWindow = g_ui.createWidget('OffsetWindow', modules.game_interface.getRootPanel())

  setupComboBox()
  outfitWidget = offsetWindow:recursiveGetChildById('outfitView')
  itemWidget = offsetWindow:recursiveGetChildById('itemView')
  effectWidget = offsetWindow:recursiveGetChildById('effectView')

  outfitWidget:hide()
  itemWidget:hide()
  effectWidget:hide()
  offsetWindow:hide()

  setupNumericFields()
  setupIdInputValidation()

  local movementCheck = offsetWindow:recursiveGetChildById('movement')
  movementCheck.onCheckChange = function(checkBox, checked)
    if outfitWidget:isVisible() then
      outfitWidget:setAnimate(checked)
    end
  end
  OffsetManager.bindKeys()
end

function OffsetManager.toggleDirection(direction)
  if currentDirection == direction then
    return
  end

  if currentDirection then
    local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
    local offsetYField = offsetWindow:recursiveGetChildById('offsetY')
    local prevOffsetX = tonumber(offsetXField:getText()) or 0
    local prevOffsetY = tonumber(offsetYField:getText()) or 0
    offsets[currentDirection].offsetX = prevOffsetX
    offsets[currentDirection].offsetY = prevOffsetY
  end

  currentDirection = direction

  local offsetX = offsets[direction].offsetX or 0
  local offsetY = offsets[direction].offsetY or 0
  local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
  local offsetYField = offsetWindow:recursiveGetChildById('offsetY')

  offsetXField:setText(tostring(offsetX))
  offsetYField:setText(tostring(offsetY))

  local checkUp = offsetWindow:recursiveGetChildById('checkUp')
  local checkRight = offsetWindow:recursiveGetChildById('checkRight')
  local checkDown = offsetWindow:recursiveGetChildById('checkDown')
  local checkLeft = offsetWindow:recursiveGetChildById('checkLeft')

  checkUp:setChecked(direction == 'up')
  checkRight:setChecked(direction == 'right')
  checkDown:setChecked(direction == 'down')
  checkLeft:setChecked(direction == 'left')

  if outfitWidget:isVisible() then
    local directions = {
      up = Directions.North,
      right = Directions.East,
      down = Directions.South,
      left = Directions.West
    }

    local newDirection = directions[direction]
    if newDirection then
      outfitWidget:setDirection(newDirection)
    end
  end
end



function onMovementChange(checkBox, checked)
  previewCreature:setAnimate(checked)
  settings.movement = checked
end

function updateCheckboxes(selectedDirection)
  local checkUp = offsetWindow:recursiveGetChildById('checkUp')
  local checkRight = offsetWindow:recursiveGetChildById('checkRight')
  local checkDown = offsetWindow:recursiveGetChildById('checkDown')
  local checkLeft = offsetWindow:recursiveGetChildById('checkLeft')

  checkUp:setChecked(selectedDirection == 'up')
  checkRight:setChecked(selectedDirection == 'right')
  checkDown:setChecked(selectedDirection == 'down')
  checkLeft:setChecked(selectedDirection == 'left')
end


function setupIdInputValidation()
  local idInput = offsetWindow:getChildById('idInput')
  idInput.onTextChange = function() validateNumericInput(idInput) end
end

function terminate()
  if offsetWindow then offsetWindow:destroy() end
  if offsetButton then offsetButton:destroy() end
end

function OffsetManager.toggle()
  if offsetWindow:isVisible() then
    offsetWindow:hide()
    offsetButton:setOn(false)
  else
    offsetWindow:show()
    offsetWindow:raise()
    offsetWindow:focus()
    offsetButton:setOn(true)
  end
end

function setupComboBox()
  local offsetComboBox = offsetWindow:getChildById('offsetComboBox')
  local opacityComboBox = offsetWindow:getChildById('effectOpacityComboBox')
  local opacityOutfitPanel = offsetWindow:getChildById('OpacityOutfit')

  if not opacityOutfitPanel then
    return
  end

  for _, option in ipairs(OffsetOptions) do
    offsetComboBox:addOption(option)
  end

  offsetComboBox.onOptionChange = function(_, option)
    local displacementTypeComboBox = offsetWindow:getChildById('displacementTypeComboBox')
    local directionsPanel = offsetWindow:getChildById('DirectionsPanel')
    local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
    local offsetYField = offsetWindow:recursiveGetChildById('offsetY')
    local idInput = offsetWindow:getChildById('idInput')
    local chaseModeBox = offsetWindow:recursiveGetChildById('movement')
    local opacityField = offsetWindow:recursiveGetChildById('opacityInput')
    local offsetPanel = offsetWindow:getChildById('OffsetPanel')
    local opacityPanel = offsetWindow:getChildById('OpacityPanel')

    opacityField:setText('1.0')
    idInput:setText('')

    if effectWidget:isVisible() then
      effectWidget:hide()
      effectWidget:setEffect(nil)
    end

    if option == 'Outfit' then
      displacementTypeComboBox:setVisible(true)
      opacityComboBox:setVisible(false)
      opacityPanel:setVisible(false)
      offsetPanel:setVisible(true)
      outfitWidget:show()
      itemWidget:hide()
      effectWidget:hide()
      offsetWindow:getChildById('preview'):show()
      directionsPanel:setVisible(true)
      chaseModeBox:show()

      if displacementTypeComboBox:getText() == 'Outfit Displacement' then
        opacityOutfitPanel:setVisible(true)
      end

      outfitWidget:setOutfit({})
      OffsetManager.toggleDirection("down")
      OffsetManager.viewOffset()

    elseif option == 'Item' then
      outfitWidget:setOutfit({})
      outfitWidget:hide()
      itemWidget:show()
      effectWidget:hide()
      offsetWindow:getChildById('preview'):show()
      directionsPanel:setVisible(false)
      chaseModeBox:hide()
      displacementTypeComboBox:setVisible(false)
      opacityComboBox:setVisible(true)

      local selectedOpacityOption = opacityComboBox:getText()
      if selectedOpacityOption == 'None' then
        offsetPanel:setVisible(true)
        opacityPanel:setVisible(false)
      else
        offsetPanel:setVisible(false)
        opacityPanel:setVisible(true)
      end

      OffsetManager.viewOffset()

    elseif option == 'Effect' then
      outfitWidget:hide()
      itemWidget:hide()
      effectWidget:show()
      opacityComboBox:setVisible(true)

      local selectedOpacityOption = opacityComboBox:getText()
      if selectedOpacityOption == 'None' then
        offsetPanel:setVisible(true)
        opacityPanel:setVisible(false)
      else
        offsetPanel:setVisible(false)
        opacityPanel:setVisible(true)
      end

      directionsPanel:setVisible(false)
      chaseModeBox:hide()
      displacementTypeComboBox:setVisible(false)

      OffsetManager.viewOffset()
    end

    if option ~= 'Outfit' then
      opacityOutfitPanel:setVisible(false)
    end

    OffsetManager.resetOffset()
  end

  local displacementTypeComboBox = offsetWindow:getChildById('displacementTypeComboBox')
  displacementTypeComboBox:addOption("Outfit Displacement")
  displacementTypeComboBox:addOption("Name Displacement")
  displacementTypeComboBox:addOption("Target Displacement")

  opacityComboBox:addOption("None")
  opacityComboBox:addOption("Opacity")

  displacementTypeComboBox.onOptionChange = function(_, option)
    currentDisplacementType = option
    OffsetManager.toggleDirection("down")

    local id = tonumber(offsetWindow:getChildById('idInput'):getText())
    if currentDisplacementType == "Outfit Displacement" then
      opacityOutfitPanel:setVisible(true)

      OffsetManager.viewOffset()
    elseif currentDisplacementType == "Name Displacement" or currentDisplacementType == "Target Displacement" then
      opacityOutfitPanel:setVisible(false)

      local nameDisplacement = otmlData.creatures[id] and otmlData.creatures[id]["name-displacement"]
      if nameDisplacement then
        offsets["up"].offsetX = nameDisplacement.North and nameDisplacement.North[1] or 0
        offsets["up"].offsetY = nameDisplacement.North and nameDisplacement.North[2] or 0
        offsets["right"].offsetX = nameDisplacement.East and nameDisplacement.East[1] or 0
        offsets["right"].offsetY = nameDisplacement.East and nameDisplacement.East[2] or 0
        offsets["down"].offsetX = nameDisplacement.South and nameDisplacement.South[1] or 0
        offsets["down"].offsetY = nameDisplacement.South and nameDisplacement.South[2] or 0
        offsets["left"].offsetX = nameDisplacement.West and nameDisplacement.West[1] or 0
        offsets["left"].offsetY = nameDisplacement.West and nameDisplacement.West[2] or 0
      else
        offsets["up"].offsetX = 0
        offsets["up"].offsetY = 0
        offsets["right"].offsetX = 0
        offsets["right"].offsetY = 0
        offsets["down"].offsetX = 0
        offsets["down"].offsetY = 0
        offsets["left"].offsetX = 0
        offsets["left"].offsetY = 0
      end

      updateOffsetFields()
    end

    OffsetManager.viewOffset()
  end

  opacityComboBox.onOptionChange = function(_, option)
    local offsetPanel = offsetWindow:getChildById('OffsetPanel')
    local opacityPanel = offsetWindow:getChildById('OpacityPanel')

    if option == 'None' then
      offsetPanel:setVisible(true)
      opacityPanel:setVisible(false)
    else
      offsetPanel:setVisible(false)
      opacityPanel:setVisible(true)
    end
  end
end

function OffsetManager.bindKeys()
  local rootPanel = modules.game_interface.getRootPanel()

  g_keyboard.bindKeyPress('Shift+Up', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.onUp()
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Shift+Down', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.onDown()
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Shift+Left', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.onLeft()
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Shift+Right', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.onRight()
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Ctrl+Up', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.toggleDirection('up')
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Ctrl+Down', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.toggleDirection('down')
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Ctrl+Left', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.toggleDirection('left')
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Ctrl+Right', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.toggleDirection('right')
    end
  end, rootPanel)
end


function OffsetManager.onUp()
  local offsetYField = offsetWindow:recursiveGetChildById('offsetY')
  local currentY = tonumber(offsetYField:getText()) or 0
  offsetYField:setText(tostring(currentY - 1))
  OffsetManager.saveOffset()
end

function OffsetManager.onDown()
  local offsetYField = offsetWindow:recursiveGetChildById('offsetY')
  local currentY = tonumber(offsetYField:getText()) or 0
  offsetYField:setText(tostring(currentY + 1))
  OffsetManager.saveOffset()
end

function OffsetManager.onLeft()
  local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
  local currentX = tonumber(offsetXField:getText()) or 0
  offsetXField:setText(tostring(currentX - 1))
  OffsetManager.saveOffset()
end

function OffsetManager.onRight()
  local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
  local currentX = tonumber(offsetXField:getText()) or 0
  offsetXField:setText(tostring(currentX + 1))
  OffsetManager.saveOffset()
end


function setupNumericFields()
  local panel = offsetWindow:getChildById('OffsetPanel')

  local numericFields = {'offsetX', 'offsetY'}
  for _, fieldId in ipairs(numericFields) do
    local field = panel:getChildById(fieldId)
    if field then
      field.onTextChange = function() validateNumericInput(field) end
    end
  end
end

function OffsetManager.reloadOtmlFile()
  local version = g_game.getClientVersion()
  local otmlPath = resolvepath('/things/' .. version .. '/Tibia.otml')

  if g_things.loadOtml(otmlPath) then
    OffsetManager.viewOffset()
  end
end


function OffsetManager.toggleOpacityMode()
  local selectedOption = offsetWindow:getChildById('effectOpacityComboBox'):getText()
  local opacityPanel = offsetWindow:getChildById('OpacityPanel')
  local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
  local offsetYField = offsetWindow:recursiveGetChildById('offsetY')

  if selectedOption == 'Opacity' then
    opacityPanel:setVisible(true)
    offsetXField:setVisible(false)
    offsetYField:setVisible(false)
  else
    opacityPanel:setVisible(false)
    offsetXField:setVisible(true)
    offsetYField:setVisible(true)
  end
end

function updateOffsetFields()
  local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
  local offsetYField = offsetWindow:recursiveGetChildById('offsetY')

  if not currentDirection then
    return
  end

  local currentOffsetX = offsets[currentDirection].offsetX or 0
  local currentOffsetY = offsets[currentDirection].offsetY or 0

  offsetXField:setText(tostring(currentOffsetX))
  offsetYField:setText(tostring(currentOffsetY))
end

function OffsetManager.loadAndShowOutfit(outfitId)
  if not outfitId or outfitId == 0 then
    outfitWidget:hide()
    return
  end

  local outfit = { type = outfitId, head = 78, body = 68, legs = 58, feet = 76, direction = currentDirection }
  outfitWidget:show()
  itemWidget:hide()
  outfitWidget:setOutfit(outfit)
end

function OffsetManager.loadAndShowItem(itemId)
  local item = Item.create(itemId, 1)
  if item then
    itemWidget:show()
    outfitWidget:hide()
    itemWidget:setItem(item)
  end
end

function OffsetManager.loadAndShowEffect(effectId)
  if not effectId or effectId == 0 then
    effectWidget:hide()
    return
  end

  local effect = Effect.create()
  if not effect then
    return
  end

  effect:setEffect(effectId)

  effectWidget:show()
  outfitWidget:hide()
  itemWidget:hide()

  if effectWidget.setEffect then
    effectWidget:setEffect(effect)
  end
end

function OffsetManager.toggleSubOutfitDisplacement()
  isSubOutfitEnabled = not isSubOutfitEnabled

  updateSubOutfitCheckbox(isSubOutfitEnabled)

end

function updateSubOutfitCheckbox(enabled)
  -- Obt�m o CheckBox de forma segura e atualiza seu estado visual
  local checkBox = offsetWindow:recursiveGetChildById('subOutfitCheckBox')
  if checkBox then
    checkBox:setChecked(enabled)
  else
    print("Error: Could not find subOutfitCheckBox")
  end
end

function OffsetManager.viewOffset()
  local id = tonumber(offsetWindow:getChildById('idInput'):getText())
  local subId = tonumber(offsetWindow:getChildById('subIdInput') and offsetWindow:getChildById('subIdInput'):getText())
  local isSubOutfitChecked = offsetWindow:recursiveGetChildById('subOutfitCheckBox'):isChecked()

  if not id or id <= 0 then
    return
  end

  local selectedOption = offsetWindow:getChildById('offsetComboBox'):getText()
  local displacementTypeComboBox = offsetWindow:getChildById('displacementTypeComboBox')
  local displacementType = displacementTypeComboBox:getText()

  local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
  local offsetYField = offsetWindow:recursiveGetChildById('offsetY')

  local opacityOutfitPanel = offsetWindow:getChildById('OpacityOutfit')
  local opacityFieldOutfit = opacityOutfitPanel and opacityOutfitPanel:getChildById('opacityInput')

  local opacityPanel = offsetWindow:getChildById('OpacityPanel')
  local opacityFieldPanel = opacityPanel and opacityPanel:getChildById('opacityInput')

  if not opacityFieldOutfit or not opacityFieldPanel then
    return
  end

  if isSubOutfitChecked and subId and subId > 0 then
    local subOutfitDisplacement = otmlData.creatures[id]
      and otmlData.creatures[id]["subOutfitDisplacements"]
      and otmlData.creatures[id]["subOutfitDisplacements"][subId]

    if subOutfitDisplacement then
      local northOffset = subOutfitDisplacement.North or "0 0"
      local eastOffset = subOutfitDisplacement.East or "0 0"
      local southOffset = subOutfitDisplacement.South or "0 0"
      local westOffset = subOutfitDisplacement.West or "0 0"

      offsets["up"].offsetX, offsets["up"].offsetY = northOffset:match("(%-?%d+)%s+(%-?%d+)")
      offsets["right"].offsetX, offsets["right"].offsetY = eastOffset:match("(%-?%d+)%s+(%-?%d+)")
      offsets["down"].offsetX, offsets["down"].offsetY = southOffset:match("(%-?%d+)%s+(%-?%d+)")
      offsets["left"].offsetX, offsets["left"].offsetY = westOffset:match("(%-?%d+)%s+(%-?%d+)")

      offsetXField:setText(tostring(offsets["down"].offsetX or 0))
      offsetYField:setText(tostring(offsets["down"].offsetY or 0))
      opacityFieldOutfit:setText(string.format("%.1f", subOutfitDisplacement.opacity or 1.0))
    else
      offsets["up"].offsetX, offsets["up"].offsetY = 0, 0
      offsets["right"].offsetX, offsets["right"].offsetY = 0, 0
      offsets["down"].offsetX, offsets["down"].offsetY = 0, 0
      offsets["left"].offsetX, offsets["left"].offsetY = 0, 0

      offsetXField:setText('0')
      offsetYField:setText('0')
      opacityFieldOutfit:setText('1.0')
    end

    updateOffsetFields()
    OffsetManager.loadAndShowOutfit(subId)
    return
  end

  if selectedOption == 'Outfit' then
    if displacementType == 'Outfit Displacement' then
      local outfitDisplacement = otmlData.creatures[id] and otmlData.creatures[id]["outfit-displacement"]
      if outfitDisplacement then
        local northOffset = outfitDisplacement.North or "0 0"
        local eastOffset = outfitDisplacement.East or "0 0"
        local southOffset = outfitDisplacement.South or "0 0"
        local westOffset = outfitDisplacement.West or "0 0"

        offsets["up"].offsetX, offsets["up"].offsetY = northOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["right"].offsetX, offsets["right"].offsetY = eastOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["down"].offsetX, offsets["down"].offsetY = southOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["left"].offsetX, offsets["left"].offsetY = westOffset:match("(%-?%d+)%s+(%-?%d+)")

        opacityFieldOutfit:setText(string.format("%.1f", outfitDisplacement.opacity or 1.0))
      else
        offsets["up"].offsetX, offsets["up"].offsetY = 0, 0
        offsets["right"].offsetX, offsets["right"].offsetY = 0, 0
        offsets["down"].offsetX, offsets["down"].offsetY = 0, 0
        offsets["left"].offsetX, offsets["left"].offsetY = 0, 0

        opacityFieldOutfit:setText('1.0')
      end

      updateOffsetFields()
      OffsetManager.loadAndShowOutfit(id)

    elseif displacementType == 'Target Displacement' then
      local targetDisplacement = otmlData.creatures[id] and otmlData.creatures[id]["target-displacement"]
      if targetDisplacement then
        local northOffset = targetDisplacement.North or "0 0"
        local eastOffset = targetDisplacement.East or "0 0"
        local southOffset = targetDisplacement.South or "0 0"
        local westOffset = targetDisplacement.West or "0 0"

        offsets["up"].offsetX, offsets["up"].offsetY = northOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["right"].offsetX, offsets["right"].offsetY = eastOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["down"].offsetX, offsets["down"].offsetY = southOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["left"].offsetX, offsets["left"].offsetY = westOffset:match("(%-?%d+)%s+(%-?%d+)")
      else
        offsets["up"].offsetX, offsets["up"].offsetY = 0, 0
        offsets["right"].offsetX, offsets["right"].offsetY = 0, 0
        offsets["down"].offsetX, offsets["down"].offsetY = 0, 0
        offsets["left"].offsetX, offsets["left"].offsetY = 0, 0
      end

      updateOffsetFields()
    end
    OffsetManager.loadAndShowOutfit(id)
  end

  if selectedOption == 'Item' then
    local itemDisplacement = otmlData.items[id] and otmlData.items[id]["item-displacement"]
    if itemDisplacement then
      offsetXField:setText(tostring(itemDisplacement.x or 0))
      offsetYField:setText(tostring(itemDisplacement.y or 0))
      opacityFieldPanel:setText(string.format("%.1f", itemDisplacement.opacity or 1.0))
    else
      offsetXField:setText('0')
      offsetYField:setText('0')
      opacityFieldPanel:setText('1.0')
    end
    OffsetManager.loadAndShowItem(id)

  elseif selectedOption == 'Effect' then
    local effectDisplacement = otmlData.effects[id] and otmlData.effects[id]["effect-displacement"]
    if effectDisplacement then
      offsetXField:setText(tostring(effectDisplacement.x or 0))
      offsetYField:setText(tostring(effectDisplacement.y or 0))
      opacityFieldPanel:setText(string.format("%.1f", effectDisplacement.opacity or 1.0))
    else
      offsetXField:setText('0')
      offsetYField:setText('0')
      opacityFieldPanel:setText('1.0')
    end
    OffsetManager.loadAndShowEffect(id)
  end

  OffsetManager.toggleDirection("down")
  offsetWindow:recursiveGetChildById('checkDown'):setChecked(true)
end




function OffsetManager.saveOffset()
  local id = tonumber(offsetWindow:getChildById('idInput'):getText())
  local isSubOutfitChecked = offsetWindow:recursiveGetChildById('subOutfitCheckBox'):isChecked()
  local subId = nil
  local selectedDirection = currentDirection

  if isSubOutfitChecked then
    local subIdInput = offsetWindow:getChildById('subIdInput')
    if subIdInput then
      subId = tonumber(subIdInput:getText())
    end
  end

  if not id or id <= 0 then return end

  local opacityOutfitPanel = offsetWindow:getChildById('OpacityOutfit')
  local opacityFieldOutfit = opacityOutfitPanel and opacityOutfitPanel:getChildById('opacityInput')
  local opacityPanel = offsetWindow:getChildById('OpacityPanel')
  local opacityFieldPanel = opacityPanel and opacityPanel:getChildById('opacityInput')

  local subOutfitOpacityValue = 1.0
  if opacityFieldOutfit and isSubOutfitChecked then
    subOutfitOpacityValue = tonumber(opacityFieldOutfit:getText()) or 1.0
  end

  local outfitOpacityValue = 1.0
  if not isSubOutfitChecked and opacityFieldOutfit then
    outfitOpacityValue = tonumber(opacityFieldOutfit:getText()) or 1.0
  end

  local itemEffectOpacityValue = 1.0
  if opacityFieldPanel then
    itemEffectOpacityValue = tonumber(opacityFieldPanel:getText()) or 1.0
  end

  local previousDirection = currentDirection
  if previousDirection then
    offsets[previousDirection].offsetX = tonumber(offsetWindow:recursiveGetChildById('offsetX'):getText()) or 0
    offsets[previousDirection].offsetY = tonumber(offsetWindow:recursiveGetChildById('offsetY'):getText()) or 0
  end

  local displacement = {
    North = {offsets["up"].offsetX or 0, offsets["up"].offsetY or 0},
    East = {offsets["right"].offsetX or 0, offsets["right"].offsetY or 0},
    South = {offsets["down"].offsetX or 0, offsets["down"].offsetY or 0},
    West = {offsets["left"].offsetX or 0, offsets["left"].offsetY or 0}
  }

  if isSubOutfitChecked and subId and subId > 0 then
    otmlData.creatures[id] = otmlData.creatures[id] or {}
    otmlData.creatures[id]["subOutfitDisplacements"] = otmlData.creatures[id]["subOutfitDisplacements"] or {}
    otmlData.creatures[id]["subOutfitDisplacements"][subId] = otmlData.creatures[id]["subOutfitDisplacements"][subId] or {}

    for direction, coords in pairs(displacement) do
      otmlData.creatures[id]["subOutfitDisplacements"][subId][direction] = string.format("%d %d", coords[1], coords[2])
    end

    otmlData.creatures[id]["subOutfitDisplacements"][subId].opacity = subOutfitOpacityValue
    saveOtmlFile()
    OffsetManager.reloadOtmlFile()

    if selectedDirection then
      OffsetManager.toggleDirection(selectedDirection)
    end
    return
  end

  local selectedOption = offsetWindow:getChildById('offsetComboBox'):getText()
  local displacementType = offsetWindow:getChildById('displacementTypeComboBox'):getText()

  if selectedOption == 'Outfit' then
    otmlData.creatures[id] = otmlData.creatures[id] or {}
    if displacementType == 'Outfit Displacement' then
      otmlData.creatures[id]["outfit-displacement"] = otmlData.creatures[id]["outfit-displacement"] or {}

      for direction, coords in pairs(displacement) do
        otmlData.creatures[id]["outfit-displacement"][direction] = string.format("%d %d", coords[1], coords[2])
      end

      otmlData.creatures[id]["outfit-displacement"].opacity = outfitOpacityValue
    elseif displacementType == 'Name Displacement' then
      otmlData.creatures[id]["name-displacement"] = otmlData.creatures[id]["name-displacement"] or {}

      for direction, coords in pairs(displacement) do
        otmlData.creatures[id]["name-displacement"][direction] = string.format("%d %d", coords[1], coords[2])
      end
    elseif displacementType == 'Target Displacement' then
      otmlData.creatures[id]["target-displacement"] = otmlData.creatures[id]["target-displacement"] or {}

      for direction, coords in pairs(displacement) do
        otmlData.creatures[id]["target-displacement"][direction] = string.format("%d %d", coords[1], coords[2])
      end
    end

  elseif selectedOption == 'Item' then
    otmlData.items[id] = otmlData.items[id] or {}
    otmlData.items[id]["item-displacement"] = otmlData.items[id]["item-displacement"] or {}

    otmlData.items[id]["item-displacement"].x = tonumber(offsetWindow:recursiveGetChildById('offsetX'):getText()) or 0
    otmlData.items[id]["item-displacement"].y = tonumber(offsetWindow:recursiveGetChildById('offsetY'):getText()) or 0
    otmlData.items[id]["item-displacement"].opacity = itemEffectOpacityValue

  elseif selectedOption == 'Effect' then
    otmlData.effects[id] = otmlData.effects[id] or {}
    otmlData.effects[id]["effect-displacement"] = otmlData.effects[id]["effect-displacement"] or {}

    otmlData.effects[id]["effect-displacement"].x = tonumber(offsetWindow:recursiveGetChildById('offsetX'):getText()) or 0
    otmlData.effects[id]["effect-displacement"].y = tonumber(offsetWindow:recursiveGetChildById('offsetY'):getText()) or 0
    otmlData.effects[id]["effect-displacement"].opacity = itemEffectOpacityValue
  end

  saveOtmlFile()
  OffsetManager.reloadOtmlFile()

  if selectedDirection then
    OffsetManager.toggleDirection(selectedDirection)
  end
end



function OffsetManager.deleteOffset()
  local id = tonumber(offsetWindow:getChildById('idInput'):getText())
  local subId = tonumber(offsetWindow:getChildById('subIdInput') and offsetWindow:getChildById('subIdInput'):getText())
  local isSubOutfitChecked = offsetWindow:recursiveGetChildById('subOutfitCheckBox'):isChecked()

  if not id or id <= 0 then
    displayErrorBox("Erro", "Por favor, insira um ID v�lido para deletar.")
    return
  end

  local selectedOption = offsetWindow:getChildById('offsetComboBox'):getText()
  local displacementType = offsetWindow:getChildById('displacementTypeComboBox'):getText()

  if isSubOutfitChecked and subId and subId > 0 then
    if otmlData.creatures[id] and otmlData.creatures[id]["subOutfitDisplacements"] and otmlData.creatures[id]["subOutfitDisplacements"][subId] then
      otmlData.creatures[id]["subOutfitDisplacements"][subId] = {
        opacity = 1.0,
        North = "0 0",
        East = "0 0",
        South = "0 0",
        West = "0 0"
      }
      displayInfoBox("Reset", "SubOutfit displacement redefinido com sucesso!")
    else
      displayErrorBox("Erro", "Nenhum subOutfit displacement encontrado para o ID e SubID fornecidos.")
    end

  elseif selectedOption == 'Outfit' then
    if displacementType == 'Outfit Displacement' then
      if otmlData.creatures[id] then
        otmlData.creatures[id]["outfit-displacement"] = {
          opacity = 1.0,
          North = "0 0",
          East = "0 0",
          South = "0 0",
          West = "0 0"
        }
        displayInfoBox("Reset", "Outfit displacement redefinido com sucesso!")
      else
        displayErrorBox("Erro", "Nenhum outfit displacement encontrado para o ID fornecido.")
      end
    elseif displacementType == 'Name Displacement' then
      if otmlData.creatures[id] then
        otmlData.creatures[id]["name-displacement"] = {
          North = "0 0",
          East = "0 0",
          South = "0 0",
          West = "0 0"
        }
        displayInfoBox("Reset", "Name displacement redefinido com sucesso!")
      else
        displayErrorBox("Erro", "Nenhum name displacement encontrado para o ID fornecido.")
      end
    elseif displacementType == 'Target Displacement' then
      if otmlData.creatures[id] then
        otmlData.creatures[id]["target-displacement"] = {
          North = "0 0",
          East = "0 0",
          South = "0 0",
          West = "0 0",
        }
        displayInfoBox("Reset", "Target displacement redefinido com sucesso!")
      else
        displayErrorBox("Erro", "Nenhum target displacement encontrado para o ID fornecido.")
      end
    end

  elseif selectedOption == 'Item' then
    if otmlData.items[id] then
      otmlData.items[id]["item-displacement"] = {
        opacity = 1.0,
        x = 0,
        y = 0
      }
      displayInfoBox("Reset", "Item displacement redefinido com sucesso!")
    else
      displayErrorBox("Erro", "Nenhum item displacement encontrado para o ID fornecido.")
    end

  elseif selectedOption == 'Effect' then
    if otmlData.effects[id] then
      otmlData.effects[id]["effect-displacement"] = {
        opacity = 1.0,
        x = 0,
        y = 0
      }
      displayInfoBox("Reset", "Effect displacement redefinido com sucesso!")
    else
      displayErrorBox("Erro", "Nenhum effect displacement encontrado para o ID fornecido.")
    end

  else
    displayErrorBox("Erro", "Op��o selecionada inv�lida.")
    return
  end

  saveOtmlFile()
  OffsetManager.reloadOtmlFile()
end

function saveOtmlFile()
  local otmlPath = resolveOtmlPath()
  local directoryPath = otmlPath:match("(.+)/[^/]+$")
  if not g_resources.directoryExists(directoryPath) then
    g_resources.makeDir(directoryPath)
  end

  local fileContents = generateOtmlString(otmlData)
  local file, err = io.open(otmlPath, "w+")
  if file then
    file:write(fileContents)
    file:close()
  else
  end
end


function resolveOtmlPath()
  return directory .. filename
end

function loadOtmlFile()
  local fileContents = g_resources.readFileContents('/things/1098/Tibia.otml')
  if fileContents then
    local existingData = parseOtml(fileContents)
    otmlData = mergeOtmlData(otmlData, existingData)
  else
    otmlData = {creatures = {}, items = {}, effects = {}}
  end
end

function mergeOtmlData(newData, existingData)
  for category, data in pairs(existingData) do
    newData[category] = newData[category] or {}
    for id, values in pairs(data) do
      newData[category][id] = newData[category][id] or {}
      for key, displacement in pairs(values) do
        if category == "items" or category == "effects" then
          newData[category][id][key] = newData[category][id][key] or {}
          newData[category][id][key].x = displacement.x or newData[category][id][key].x
          newData[category][id][key].y = displacement.y or newData[category][id][key].y
          newData[category][id][key].opacity = displacement.opacity or newData[category][id][key].opacity
        elseif category == "creatures" then
          if key == "outfit-displacement" or key == "name-displacement" or key == "target-displacement" then
            newData[category][id][key] = newData[category][id][key] or {}
            newData[category][id][key].opacity = displacement.opacity or newData[category][id][key].opacity
            for direction, coords in pairs(displacement) do
              if direction ~= "opacity" then
                newData[category][id][key][direction] = coords
              end
            end
          elseif key == "subOutfitDisplacements" then
            newData[category][id]["subOutfitDisplacements"] = newData[category][id]["subOutfitDisplacements"] or {}
            for subId, subDisplacement in pairs(displacement) do
              newData[category][id]["subOutfitDisplacements"][subId] = newData[category][id]["subOutfitDisplacements"][subId] or {}
              newData[category][id]["subOutfitDisplacements"][subId].opacity = subDisplacement.opacity or newData[category][id]["subOutfitDisplacements"][subId].opacity
              for direction, coords in pairs(subDisplacement) do
                if direction ~= "opacity" then
                  newData[category][id]["subOutfitDisplacements"][subId][direction] = coords
                end
              end
            end
          end
        end
      end
    end
  end
  return newData
end



function parseOtml(contents)
  local data = { creatures = {}, items = {}, effects = {} }
  local currentCategory, currentId, currentDisplacementType, currentSubId

  for line in contents:gmatch("[^\r\n]+") do
    if line:find("creatures:") then
      currentCategory = "creatures"
    elseif line:find("items:") then
      currentCategory = "items"
    elseif line:find("effects:") then
      currentCategory = "effects"

    elseif line:match("^%s*(%d+):") and not (line:find("subOutfitDisplacements") or currentDisplacementType == "subOutfitDisplacements") then
      currentId = tonumber(line:match("(%d+):"))
      data[currentCategory][currentId] = data[currentCategory][currentId] or {}
      currentDisplacementType, currentSubId = nil, nil

    elseif line:match("displacement:") then
      currentDisplacementType = line:match("(%w+%-displacement):")
      data[currentCategory][currentId][currentDisplacementType] = data[currentCategory][currentId][currentDisplacementType] or {}
      currentSubId = nil

    elseif line:find("subOutfitDisplacements:") then
      currentDisplacementType = "subOutfitDisplacements"
      data[currentCategory][currentId][currentDisplacementType] = data[currentCategory][currentId][currentDisplacementType] or {}
      currentSubId = nil

    elseif currentDisplacementType == "subOutfitDisplacements" and line:match("^%s*(%d+):") then
      currentSubId = tonumber(line:match("(%d+):"))
      data[currentCategory][currentId][currentDisplacementType][currentSubId] = data[currentCategory][currentId][currentDisplacementType][currentSubId] or {}

    elseif line:find("opacity:") then
      local opacity = tonumber(line:match("opacity:%s*(%-?%d+%.?%d*)"))
      if currentDisplacementType then
        local target = currentSubId and data[currentCategory][currentId][currentDisplacementType][currentSubId] 
                      or data[currentCategory][currentId][currentDisplacementType]
        target.opacity = opacity
      end

    elseif currentDisplacementType == "subOutfitDisplacements" and currentSubId then
      local direction, x, y = line:match("%s*(%w+):%s*(%-?%d+)%s*(%-?%d+)")
      if direction and x and y then
        data[currentCategory][currentId][currentDisplacementType][currentSubId][direction] = string.format("%s %s", x, y)
      end

    elseif currentCategory == "creatures" and currentDisplacementType then
      local direction, x, y = line:match("%s*(%w+):%s*(%-?%d+)%s*(%-?%d+)")
      if direction and x and y then
        data[currentCategory][currentId][currentDisplacementType][direction] = string.format("%s %s", x, y)
      end

    elseif currentCategory == "items" or currentCategory == "effects" then
      local key, value = line:match("%s*(%w+):%s*(%-?%d+%.?%d*)")
      if key and value then
        data[currentCategory][currentId][currentDisplacementType][key] = tonumber(value)
      end
    end
  end

  return data
end



function generateOtmlString(data)
  local contents = {}

  local function addLine(line)
    table.insert(contents, line)
  end

  for category, entries in pairs(data) do
    addLine(category .. ":")
    
    local sortedIds = {}
    for id in pairs(entries) do
      table.insert(sortedIds, id)
    end
    table.sort(sortedIds)
    
    for _, id in ipairs(sortedIds) do
      local entryData = entries[id]
      addLine("  " .. id .. ":")
      
      for entryType, displacement in pairs(entryData) do
        if category == "items" or category == "effects" then
          addLine("    " .. entryType .. ":")
          if displacement.opacity ~= nil then
            addLine("      opacity: " .. tostring(displacement.opacity))
          end
          if displacement.x ~= nil then
            addLine("      x: " .. tostring(displacement.x))
          end
          if displacement.y ~= nil then
            addLine("      y: " .. tostring(displacement.y))
          end
        elseif entryType == "outfit-displacement" or entryType == "name-displacement" or entryType == "target-displacement" then
          addLine("    " .. entryType .. ":")
          if displacement.opacity ~= nil then
            addLine("      opacity: " .. tostring(displacement.opacity))
          end
          for direction, coords in pairs(displacement) do
            if direction ~= "opacity" then
              addLine("      " .. direction .. ": " .. coords)
            end
          end
        elseif entryType == "subOutfitDisplacements" then
          addLine("    subOutfitDisplacements:")
          local sortedSubIds = {}
          for subId in pairs(displacement) do
            table.insert(sortedSubIds, subId)
          end
          table.sort(sortedSubIds)
          for _, subId in ipairs(sortedSubIds) do
            local subDisplacement = displacement[subId]
            addLine("      " .. subId .. ":")
            if subDisplacement.opacity ~= nil then
              addLine("        opacity: " .. tostring(subDisplacement.opacity))
            end
            for direction, coords in pairs(subDisplacement) do
              if direction ~= "opacity" then
                addLine("        " .. direction .. ": " .. coords)
              end
            end
          end
        end
      end
    end
  end

  return table.concat(contents, "\n")
end





function backupOtmlFile()
  local originalPath = resolveOtmlPath()
  local backupPath = directory .. "Tibia_backup.otml"

  local backupContents = generateOtmlString(otmlData)

  local backupFile, err = io.open(backupPath, "w+")
  if backupFile then
    backupFile:write(backupContents)
    backupFile:close()
  else
  end
end

function OffsetManager.resetOffset()
  offsetWindow:recursiveGetChildById('offsetX'):setText('0')
  offsetWindow:recursiveGetChildById('offsetY'):setText('0')

  local opacityOutfitPanel = offsetWindow:getChildById('OpacityOutfit')
  local opacityFieldOutfit = opacityOutfitPanel and opacityOutfitPanel:getChildById('opacityInput')
  
  local opacityPanel = offsetWindow:getChildById('OpacityPanel')
  local opacityFieldPanel = opacityPanel and opacityPanel:getChildById('opacityInput')

  if opacityFieldOutfit then
    opacityFieldOutfit:setText('1.0')
  end

  if opacityFieldPanel then
    opacityFieldPanel:setText('1.0')
  end

  outfitWidget:hide()
  itemWidget:hide()

  offsets["up"].offsetX = 0
  offsets["up"].offsetY = 0
  offsets["right"].offsetX = 0
  offsets["right"].offsetY = 0
  offsets["down"].offsetX = 0
  offsets["down"].offsetY = 0
  offsets["left"].offsetX = 0
  offsets["left"].offsetY = 0

  offsetWindow:recursiveGetChildById('idInput'):setText('')
end
