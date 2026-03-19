local acceptWindow = {}
statusUpdateEvent = nil
url = "http://fermoria.com/payment/init.php"
apiPassword = "teste@@"

function checkPayment(url, paymentId, metodoPagamento)
    if not g_game.isOnline() then
        removeEvent(statusUpdateEvent)
        return true
    end

    if not paymentId or paymentId == "" then
        return
    end

    local function callback(data, err)
        if err then
            sendCancelBox("Erro", "Erro ao verificar o pagamento. Tente novamente.")
        else
            local response = json.decode(data)
            if response and response.status == "Pagamento confirmado e pontos entregues!" then
                cancelDonate()
                removeEvent(statusUpdateEvent)
                sendCancelBox("Aviso", "Seu pagamento foi confirmado e seus pontos adicionados!\nMuito obrigado pela sua doa��o!")
            else
                statusUpdateEvent = scheduleEvent(function() checkPayment(url, paymentId, metodoPagamento) end, 10000)
            end
        end
    end

    local postData = {
        ["payment_id"] = paymentId,
        ["pass"] = apiPassword,
        ["metodo_pagamento"] = metodoPagamento
    }

    HTTP.post(url, json.encode(postData), callback)
end

function toggleCurrencySelection()
    local paymentMethodComboBox = paymentWindow:getChildById('paymentMethodComboBox')
    local currencyComboBox = paymentWindow:getChildById('currencyComboBox')
    local paymentMethod = paymentMethodComboBox:getCurrentOption().text:lower()

    if paymentMethod == "mercado pago" then
        currencyComboBox:disable()
        currencyComboBox:setTooltip("Moeda fixa: BRL (Real)")
        currencyComboBox:setCurrentOption("BRL")
    elseif paymentMethod == "wise" then
        currencyComboBox:enable()
        currencyComboBox:setTooltip("Selecione a moeda")
    else
        currencyComboBox:enable()
        currencyComboBox:setTooltip("")
    end
end



function sendPost(firstName, valor, playerAccount, playerCharacter, metodoPagamento, moeda)
    if not firstName or firstName == "" then
        return
    end
    if not valor or valor <= 0 then
        return
    end

    if metodoPagamento == "mercado_pago" then
        moeda = "brl"
    end

    local postData = {
        ["nameAccount"] = playerAccount,
        ["valor"] = valor,
        ["name"] = firstName,
        ["namePlayer"] = g_game.getCharacterName(),
        ["pass"] = apiPassword,
        ["metodo_pagamento"] = metodoPagamento,
        ["currency"] = moeda
    }

    local function callback(data, err)
        if err then
            sendCancelBox("Erro", "Ocorreu um erro na transação.")
        else
            local response = json.decode(data)
            if response and response.payment_link then
                g_platform.openUrl(response.payment_link)
                if metodoPagamento == "mercado_pago" or metodoPagamento == "stripe" or metodoPagamento == "wise" then
                    checkPayment(url, response.payment_id or response.transfer_id, metodoPagamento)
                end
            else
                sendCancelBox("Erro", "Erro ao iniciar o pagamento.")
            end
        end
    end

    HTTP.post(url, json.encode(postData), callback)
end


local historyWindow = nil

function fetchTransactionHistory()
    local playerAccount = G.account

    if not playerAccount or playerAccount == "" then
        sendCancelBox("Erro", "Conta do jogador n�o encontrada.")
        return
    end

    local postData = {
        ["account"] = playerAccount,
        ["pass"] = apiPassword
    }

    local function callback(data, err)
        if err then
            sendCancelBox("Erro", "n�o foi poss�vel obter o hist�rico de transa��o.")
        else
            local response = json.decode(data)
            if response and response.transactions then
                showTransactionHistory(response.transactions)
            else
                sendCancelBox("Aviso", "Nenhum hist�rico de transa��es encontrado.")
            end
        end
    end

    HTTP.post(url .. "/history", json.encode(postData), callback)
end

function showTransactionHistory(transactions)
    if not historyWindow then
        historyWindow = g_ui.displayUI('game_history')
    end

    local list = historyWindow:getChildById('transactionList')
    list:destroyChildren()

    for _, transaction in pairs(transactions) do
        local label = g_ui.createWidget('HistoryItem', list)
        label:setText(string.format("Data: %s | m�todo: %s | Valor: R$ %.2f | Status: %s", 
            transaction.date, transaction.method, transaction.amount, transaction.status))
    end

    historyWindow:show()
    historyWindow:raise()
    historyWindow:focus()
end

function closeHistory()
    if historyWindow then
        historyWindow:hide()
    end
end


function applyBonus(valor)
    return valor
end

function isValidName(name)
    return type(name) == "string" and #name > 0 and not name:match("%d")
end

function isValidValue(value)
    return type(value) == "number" and value == value and value >= 1
end

function sendCancelBox(header, text)
    local cancelFunc = function()
        acceptWindow[#acceptWindow]:destroy()
        acceptWindow = {}
    end

    if #acceptWindow > 0 then
        acceptWindow[#acceptWindow]:destroy()
    end

    acceptWindow[#acceptWindow + 1] =
        displayGeneralBox(tr(header), tr(text),
        {
            { text = tr("OK"), callback = cancelFunc },
            anchor = AnchorHorizontalCenter
        }, cancelFunc)
end

function sendDonate()
    local firstName = paymentWindow.firstNameText:getText()
    local valorText = paymentWindow.valorText:getText()
    local valor = tonumber(valorText)
    local paymentMethodComboBox = paymentWindow:getChildById('paymentMethodComboBox')
    local metodoPagamento = paymentMethodComboBox:getCurrentOption().text
    local currencyComboBox = paymentWindow:getChildById('currencyComboBox')
    local moeda = currencyComboBox:getCurrentOption().text:lower()
    local playerAccount = G.account
    local playerCharacter = g_game.getCharacterName()

    if not isValidName(firstName) then
        sendCancelBox("Aviso", "Você precisa digitar um nome válido.")
        return
    end

    if not valor or valor < 1 then
        sendCancelBox("Aviso", "Você precisa doar um valor mínimo de 1 real.")
        return
    end

    if not metodoPagamento or metodoPagamento == "" then
        sendCancelBox("Erro", "Por favor, selecione um método de pagamento válido.")
        return
    end

    local function confirmDonate()
        if metodoPagamento == "Mercado Pago" then
            sendPost(firstName, valor, playerAccount, playerCharacter, "mercado_pago")
        elseif metodoPagamento == "Stripe" then
            sendPost(firstName, valor, playerAccount, playerCharacter, "stripe", moeda)
        elseif metodoPagamento == "Wise" then
            sendPost(firstName, valor, playerAccount, playerCharacter, "wise", moeda)
        else
            sendCancelBox("Erro", "Método de pagamento inválido selecionado.")
        end
    end

    local confirmText = tr(
        "Confirmação de Doação\n\n" ..
        "Nome: %s\n" ..
        "Valor: %s %s\n" ..
        "Método de Pagamento: %s\n" ..
        "Login: %s\n" ..
        "Personagem: %s\n\n" ..
        "Deseja continuar com a doação?",
        firstName, valor, moeda:upper(), metodoPagamento, playerAccount, playerCharacter
    )

    acceptWindow[#acceptWindow + 1] = displayGeneralBox(
        tr("Confirmação de Doação"),
        confirmText,
        {
            { text = tr("Confirmar"), callback = confirmDonate },
            { text = tr("Cancelar"), callback = cancelDonate },
        },
        cancelDonate
    )
end



function cancelDonate()
    if paymentWindow and paymentWindow:isVisible() then
        paymentWindow:hide()
    end
    if #acceptWindow > 0 then
        acceptWindow[#acceptWindow]:destroy()
        acceptWindow = {}
    end
end

function toggle()
    if paymentWindow:isVisible() then
        paymentWindow:hide()
        if statusUpdateEvent then
            cancelDonate()
            removeEvent(statusUpdateEvent)
        end
    else
        show()
    end
end

function show()
    if not paymentWindow then
        return
    end
    paymentWindow:show()
    paymentWindow:raise()
    paymentWindow:focus()
end

function hide()
    if not paymentWindow then
        paymentWindow:hide()
    end
end

function init()
    paymentWindow = g_ui.displayUI('game_payment')
    paymentWindow:hide()

    local paymentMethodComboBox = paymentWindow:getChildById('paymentMethodComboBox')
    paymentMethodComboBox:addOption("Mercado Pago")
    paymentMethodComboBox:addOption("Stripe")
    paymentMethodComboBox:addOption("Wise")
    paymentMethodComboBox.onOptionChange = toggleCurrencySelection

    local currencyComboBox = paymentWindow:getChildById('currencyComboBox')
    currencyComboBox:addOption("BRL")
    currencyComboBox:addOption("USD")
    currencyComboBox:addOption("EUR")

    toggleCurrencySelection()

    connect(g_game, {
        onGameStart = cancelDonate,
        onGameEnd = cancelDonate,
    })
end




function terminate()
    if paymentWindow then
        paymentWindow:destroy()
    end
    if #acceptWindow > 0 then
        acceptWindow[#acceptWindow]:destroy()
    end

    disconnect(g_game, {
        onGameStart = cancelDonate,
        onGameEnd = cancelDonate,
    })
end
