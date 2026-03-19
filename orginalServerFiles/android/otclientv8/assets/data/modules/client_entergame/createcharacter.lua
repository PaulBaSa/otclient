-- createcharacter.lua

CreateCharacter = {}

local createCharacterWindow
local loadBox

local Towns = {"Rookgaard"}
local Sexes = {"Male", "Female"}
local Vocations = {"None"}

local CitysList = {
  ["Rookgaard"] = 11,
}

local VocationsList = {
  ["None"] = 0,
  -- ["Sorcerer"] = 1,
  -- ["Druid"] = 2,
  -- ["Knight"] = 4,
  -- ["Paladin"] = 3,
}

local function onError(protocol, message, errorCode)
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end

  local errorBox = displayErrorBox(tr('Create Character Error'), message)
  connect(errorBox, { onOk = CreateCharacter.show })
end

local function onSuccess(message)
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end

  createCharacterSuccessWindow = displayInfoBox(tr('Create Character'), message)
  createCharacterSuccessWindow.onOk = {
    function()
      createCharacterSuccessWindow = nil
      CreateCharacter.hide()
      EnterGame.doLoginAgain()
    end
  }
end

function CreateCharacter.init()
  createCharacterWindow = g_ui.displayUI('createcharacter.otui')

  local townIdComboBox = createCharacterWindow:getChildById('townIdComboBox')
  for _, town in ipairs(Towns) do
    townIdComboBox:addOption(town)
  end

  local sexComboBox = createCharacterWindow:getChildById('sexComboBox')
  for _, sex in ipairs(Sexes) do
    sexComboBox:addOption(sex)
  end

  local vocationComboBox = createCharacterWindow:getChildById('vocationComboBox')
  for _, vocation in ipairs(Vocations) do
    vocationComboBox:addOption(vocation)
  end

  CreateCharacter.hide()
end

function CreateCharacter.terminate()
  if createCharacterWindow then
    createCharacterWindow:destroy()
    createCharacterWindow = nil
  end
  loadBox = nil
end

function CreateCharacter.show()
  createCharacterWindow:show()
  createCharacterWindow:raise()
  createCharacterWindow:focus()
end

function CreateCharacter.doOpenCharacterList()
  CreateCharacter.hide()
  CharacterList.show()
end

function CreateCharacter.doCreateCharacter()
  local characterName = createCharacterWindow:getChildById('characterNameTextEdit'):getText()
  local town = createCharacterWindow:getChildById('townIdComboBox'):getCurrentOption().text
  local sex = createCharacterWindow:getChildById('sexComboBox'):getCurrentOption().text
  local vocation = createCharacterWindow:getChildById('vocationComboBox'):getCurrentOption().text
  
  local townId = CitysList[town]
  local sexId = (sex == "Male") and 1 or 0
  local vocationId = VocationsList[vocation]

  -- print("Creating character with sex:", sexId)  -- Adicionando print

  CreateCharacter.hide()
  local host = '127.0.0.1'
  local port = tonumber('7173')

  if g_game.isOnline() then
    local errorBox = displayErrorBox(tr('Create Character Error'), tr('Cannot create character while already in game.'))
    connect(errorBox, { onOk = CreateCharacter.show() })
    return
  end

  protocolCreateCharacter = ProtocolCreateCharacter.create()
  protocolCreateCharacter.onCreateCharacterError = onError
  protocolCreateCharacter.onCreateCharacterSuccess = onSuccess

  loadBox = displayCancelBox(tr('Please wait'), tr('Connecting to create character server'))
  connect(loadBox, { onCancel = function(msgbox)
                                  loadBox = nil
                                  CreateCharacter.show()
                                end})

  protocolCreateCharacter:createCharacter(host, port, G.account, G.password, characterName, townId, sexId, vocationId)
end


function CreateCharacter.hide(showCharacterList)
  if not createCharacterWindow then return end
  showCharacterList = showCharacterList or false

  createCharacterWindow:hide()

  if showCharacterList and CharacterList then
    CharacterList.show()
  end
end
