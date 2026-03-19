RecoveryAccount = { }

local recoveryAccountWindow

function RecoveryAccount.init()
  recoveryAccountWindow = g_ui.displayUI('recoveryaccount')
  RecoveryAccount.hide()
end

function RecoveryAccount.terminate()
  recoveryAccountWindow:destroy()
  recoveryAccountWindow = nil
end

function RecoveryAccount.show()
  recoveryAccountWindow:show()
  recoveryAccountWindow:raise()
  recoveryAccountWindow:focus()
end

function RecoveryAccount.doOpenEnterGameWindow()
  RecoveryAccount.hide()
  EnterGame.show()
end

local function onError(protocol, message, errorCode)
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end

  local errorBox = displayErrorBox(tr('Recovery Account Error'), message)
  connect(errorBox, { onOk = RecoveryAccount.show })
end

local function onSuccess(message)
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end

  recoveryAccountSuccessWindow = displayInfoBox(tr('Recovery Account'), message)
  recoveryAccountSuccessWindow.onOk = {
    function()
      recoveryAccountSuccessWindow = nil
      RecoveryAccount.hide()
      EnterGame.show()
    end
  }
end

function RecoveryAccount.doRecoverAccount()
  local recoveryAccountName = recoveryAccountWindow:getChildById('accountNameTextEdit'):getText()
  local recoveryKey = recoveryAccountWindow:getChildById('recoveryKeyTextEdit'):getText()
  local newPassword = recoveryAccountWindow:getChildById('newPasswordTextEdit'):getText()
  local newPasswordConfirmation = recoveryAccountWindow:getChildById('newPasswordConfirmationTextEdit'):getText()
  local host = '190.102.40.237'
  local port = tonumber('7176')
  local clientVersion = tonumber('1098')

  RecoveryAccount.hide()

  if g_game.isOnline() then
    local errorBox = displayErrorBox(tr('Recovery Account Error'), tr('Cannot recover account while already in game.'))
    connect(errorBox, { onOk = RecoveryAccount.show() })
    return
  end

  protocolRecoverAccount = ProtocolRecoveryAccount.create()
  protocolRecoverAccount.onRecoverAccountError = onError
  protocolRecoverAccount.onRecoverAccountSuccess = onSuccess

  loadBox = displayCancelBox(tr('Please wait'), tr('Connecting to recovery account server...'))
  connect(loadBox, { onCancel = function(msgbox)
                                  loadBox = nil
                                  protocolRecoverAccount:cancelRecoverAccount()
                                  RecoveryAccount.show()
                                end})

  g_game.setClientVersion(clientVersion)
  g_game.setProtocolVersion(g_game.getClientProtocolVersion(clientVersion))
  g_game.chooseRsa(host)

  protocolRecoverAccount:recoverAccount(host, port, recoveryAccountName, recoveryKey, newPassword, newPasswordConfirmation)
end

function RecoveryAccount.hide()
  recoveryAccountWindow:hide()
end
