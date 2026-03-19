CreateAccount = { }

local createAccountWindow
local captchaCode

function CreateAccount.init()
  createAccountWindow = g_ui.displayUI('createaccount')
  CreateAccount.hide()
end

function CreateAccount.terminate()
  createAccountWindow:destroy()
  createAccountWindow = nil
end

function CreateAccount.show()
  captchaCode = CreateAccount.generateCaptchaCode()  -- Gera o código captcha
  createAccountWindow:show()
  createAccountWindow:raise()
  createAccountWindow:focus()
end

function CreateAccount.hide()
  createAccountWindow:hide()
end

function CreateAccount.generateCaptchaCode()
  local code = tostring(math.random(100000, 999999))
  local captchaLabel = createAccountWindow:getChildById('captchaLabel')
  if captchaLabel then
    captchaLabel:setText(code)
  else
    print("Erro: captchaLabel não encontrado.")
  end
  return code
end

function CreateAccount.doOpenEnterGameWindow()
  CreateAccount.hide()
  EnterGame.show()
end

local function onError(protocol, message, errorCode)
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end
  
  local errorBox = displayErrorBox(tr('Create Account Error'), message)
  connect(errorBox, { onOk = CreateAccount.show })
end

local function onSuccess(message)
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end

  createAccountSuccessWindow = displayInfoBox(tr('Create Account'), message)
  createAccountSuccessWindow.onOk = {
    function()
      createAccountSuccessWindow = nil
      CreateAccount.hide()
      EnterGame.show()
    end
  }
end

function CreateAccount.doCreateAccount()
  local enteredCaptcha = createAccountWindow:getChildById('captchaTextEdit'):getText()
  
  if enteredCaptcha ~= captchaCode then
    local errorBox = displayErrorBox(tr('Create Account Error'), tr('Invalid verification code. Please try again.'))
    connect(errorBox, { onOk = CreateAccount.show })
    return
  end

  local createAccountName = createAccountWindow:getChildById('accountNameTextEdit'):getText()
  local createEmail = createAccountWindow:getChildById('emailTextEdit'):getText()
  local createPassword = createAccountWindow:getChildById('passwordTextEdit'):getText()
  local createPasswordConfirmation = createAccountWindow:getChildById('passwordConfirmationTextEdit'):getText()
  local host = '127.0.0.1'
  local port = tonumber('7174')
  local clientVersion = tonumber('1098')

  CreateAccount.hide()

  if g_game.isOnline() then
    local errorBox = displayErrorBox(tr('Create Account Error'), tr('Cannot create account while already in game.'))
    connect(errorBox, { onOk = CreateAccount.show() })
    return
  end

  local protocolCreateAccount = ProtocolCreateAccount.create()
  protocolCreateAccount.onCreateAccountError = onError
  protocolCreateAccount.onCreateAccountSuccess = onSuccess

  loadBox = displayCancelBox(tr('Please wait'), tr('Connecting to create account server...'))
  connect(loadBox, { onCancel = function(msgbox)
                                  loadBox = nil
                                  protocolCreateAccount:cancelCreateAccount()
                                  CreateAccount.show()
                                end})

  g_game.setClientVersion(clientVersion)
  g_game.setProtocolVersion(g_game.getClientProtocolVersion(clientVersion))
  g_game.chooseRsa(host)

  protocolCreateAccount:createAccount(host, port, createAccountName, createEmail, createPassword, createPasswordConfirmation)
end
