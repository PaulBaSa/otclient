DeleteCharacter = {}

local deleteCharacterWindow
local confirmDeletionWindow

local function onError(protocol, message, errorCode)
  if deleteCharacterWindow then
    deleteCharacterWindow:destroy()
    deleteCharacterWindow = nil
  end

  local errorBox = displayErrorBox(tr('Delete Character Error'), message)
  connect(errorBox, { onOk = DeleteCharacter.show })
end

local function onSuccess(message)
  if deleteCharacterWindow then
    deleteCharacterWindow:destroy()
    deleteCharacterWindow = nil
  end

  if confirmDeletionWindow then
    confirmDeletionWindow:destroy()
    confirmDeletionWindow = nil
  end

  local successBox = displayInfoBox(tr('Delete Character'), message)
  successBox.onOk = {
    function()
      successBox = nil
      DeleteCharacter.hide()
      EnterGame.doLoginAgain()
    end
  }
end

function DeleteCharacter.init()
  g_ui.importStyle('deletecharacter.otui')
  deleteCharacterWindow = g_ui.createWidget('DeleteCharacterWindow', rootWidget)
  DeleteCharacter.hide()
end

function DeleteCharacter.terminate()
  if deleteCharacterWindow then
    deleteCharacterWindow:destroy()
    deleteCharacterWindow = nil
  end
end

function DeleteCharacter.show()
  if not deleteCharacterWindow then
    deleteCharacterWindow = g_ui.createWidget('DeleteCharacterWindow', rootWidget)
  end
  deleteCharacterWindow:show()
  deleteCharacterWindow:raise()
  deleteCharacterWindow:focus()
end

function DeleteCharacter.hide()
  if not deleteCharacterWindow then return end
  deleteCharacterWindow:hide()
end

function DeleteCharacter.doDeleteCharacter()
  if not deleteCharacterWindow then
    deleteCharacterWindow = g_ui.createWidget('DeleteCharacterWindow', rootWidget)
  end

  local characterName = deleteCharacterWindow:getChildById('characterNameTextEdit'):getText()
  local recoveryKey = deleteCharacterWindow:getChildById('recoveryKeyTextEdit'):getText()

  if characterName ~= '' and recoveryKey ~= '' then
    -- Show the confirmation dialog
    confirmDeletionWindow = displayGeneralBox(
      tr('Confirm Deletion'),
      tr('Are you sure you want to delete this character?'),
      {
        { text = tr('Yes'), callback = function() DeleteCharacter.confirmDeletion(characterName, recoveryKey) end },
        { text = tr('No'), callback = function() confirmDeletionWindow:destroy() confirmDeletionWindow = nil end }
      }
    )
  else
    displayErrorBox(tr('Error'), tr('Please enter a character name and recovery key.'))
  end
end

function DeleteCharacter.confirmDeletion(characterName, recoveryKey)
  local host = '191.96.225.178' -- Defina o host diretamente aqui
  local port = 7175 -- Defina a porta diretamente aqui

  protocolDeleteCharacter = ProtocolDeleteCharacter.create()
  protocolDeleteCharacter.onDeleteCharacterError = onError
  protocolDeleteCharacter.onDeleteCharacterSuccess = onSuccess

  protocolDeleteCharacter:deleteCharacter(host, port, characterName, recoveryKey)
  
  if confirmDeletionWindow then
    confirmDeletionWindow:destroy()
    confirmDeletionWindow = nil
  end
end
