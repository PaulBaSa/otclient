local GAME_STORE_CODE = 102
local DONATION_URL = nil

gameStoreWindow = nil
offersGrid = nil
msgWindow = nil
local gameStoreButton = nil
local giftWindow = nil
local withdrawWindow = nil
local selectedButton = nil


local categories = nil
local offers = {}

local selectedOffer = nil

modules.game_store = modules.game_store or {}

function init()
    connect(
        g_game,
        {
            onGameStart = create,
            onGameEnd = destroy
        }
    )

    ProtocolGame.registerExtendedOpcode(GAME_STORE_CODE, onExtendedOpcode)

    if g_game.isOnline() then
        create()
    end
end

function terminate()
    disconnect(
        g_game,
        {
            onGameStart = create,
            onGameEnd = destroy
        }
    )

    ProtocolGame.unregisterExtendedOpcode(GAME_STORE_CODE, onExtendedOpcode)

    destroy()
end

function onExtendedOpcode(protocol, code, buffer)
    local json_status, json_data =
        pcall(
        function()
            return json.decode(buffer)
        end
    )
    if not json_status then
        g_logger.error("SHOP json error: " .. json_data)
        return false
    end

    local action = json_data["action"]
    local data = json_data["data"]
    if not action or not data then
        return false
    end

    if action == "fetchBase" then
        onGameStoreFetchBase(data)
    elseif action == "clearOffers" then
        onGameStoreClearOffers(data)
    elseif action == "fetchOffers" then
        onGameStoreFetchOffers(data)
    elseif action == "points" then
        onGameStoreUpdatePoints(data)
    elseif action == "history" then
        onGameStoreUpdateHistory(data)
    elseif action == "msg" then
        onGameStoreMsg(data)
    end
end

function onGameStoreClearOffers(data)
    offers[data.category] = {}
end

function create()
    if gameStoreWindow then
        return
    end

    gameStoreWindow = g_ui.displayUI("store")
    gameStoreWindow:hide()

    gameStoreButton = modules.client_topmenu.addLeftButton("gameStoreButton", tr("Store"), "/images/topbuttons/store_large", toggle, true)

    connect(gameStoreWindow:getChildById("categories"), {onChildFocusChange = changeCategory})
    connect(gameStoreWindow:getChildById("offers"), {onChildFocusChange = offerFocus})

    offersGrid = gameStoreWindow:recursiveGetChildById("offers") -- Certifique-se de inicializar o offersGrid aqui

    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
        protocolGame:sendExtendedOpcode(GAME_STORE_CODE, json.encode({action = "fetch", data = {}}))
    end
end


function destroy()
    if gameStoreButton then
        gameStoreButton:destroy()
        gameStoreButton = nil
    end

    if gameStoreWindow then
        disconnect(gameStoreWindow:getChildById("categories"), {onChildFocusChange = changeCategory})
        disconnect(gameStoreWindow:getChildById("offers"), {onChildFocusChange = offerFocus})
        offersGrid = nil
        gameStoreWindow:destroy()
        gameStoreWindow = nil
    end

    if msgWindow then
        msgWindow:destroy()
        msgWindow = nil
    end

    if giftWindow then
        giftWindow:destroy()
        giftWindow = nil
    end

    if withdrawWindow then
        withdrawWindow:destroy()
        withdrawWindow = nil
    end
end

function onGameStoreFetchBase(data)
    categories = data.categories
    for i = 1, #categories do
        addCategory(categories[i], i == 1)
    end
    DONATION_URL = data.url
end

function onGameStoreFetchOffers(data)
    if not offers[data.category] then
        offers[data.category] = {}
    end

    for i = 1, #data.offers do
        table.insert(offers[data.category], data.offers[i])
    end

    if data.category == "Items" and #offers[data.category] > 0 then
        offersGrid = gameStoreWindow:recursiveGetChildById("offers")
        addOffers(offers[data.category])
        gameStoreWindow:getChildById("categories"):getChildByIndex(1):focus()
    end
end


function onGameStoreUpdatePoints(data)
    local pointsWidget = gameStoreWindow:recursiveGetChildById("points")
    local points = comma_value(tonumber(data))
    pointsWidget:setText(string.format(pointsWidget.baseText, points))
end

function onGameStoreUpdateHistory(history)
    local historyPanel = gameStoreWindow:getChildById("history")
    historyPanel:destroyChildren()
    scheduleEvent(
        function()
            for i = 1, #history do
                local category = g_ui.createWidget("HistoryLabel", historyPanel)
                category:setText(history[i])
            end
        end,
        250
    )
end

function purchase()
    if not selectedOffer then
        displayInfoBox("Error", "Something went wrong, make sure to select category and offer.")
        return
    end

    local title = "Purchase Confirmation"
    local msg = "Do you want to buy " .. selectedOffer.title .. " for " .. selectedOffer.price .. " points?"
    msgWindow =
        displayGeneralBox(
        title,
        msg,
        {
            {text = "Yes", callback = buyConfirmed},
            {text = "No", callback = buyCanceled},
            anchor = AnchorHorizontalCenter
        },
        buyConfirmed,
        buyCanceled
    )

    -- Garante que a janela de mensagem esteja acima da janela do shop
    if msgWindow then
        msgWindow:raise()   -- Eleva a janela para o topo
        msgWindow:focus()   -- Foca na janela para garantir que ela receba a entrada do usuÃ¡rio
    end
end

function buyConfirmed()
    if msgWindow then
        msgWindow:destroy()
        msgWindow = nil
    end
    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
        protocolGame:sendExtendedOpcode(GAME_STORE_CODE, json.encode({action = "purchase", data = selectedOffer}))
    end
end

function buyCanceled()
    if msgWindow then
        msgWindow:destroy()
        msgWindow = nil
    end
end


function gift()
    if giftWindow then
        return
    end
    if not selectedOffer then
        displayInfoBox("Error", "Something went wrong, make sure to select category and offer.")
        return
    end

    giftWindow = g_ui.displayUI("gift")
end

function confirmGift()
    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
        local targetName = giftWindow:getChildById("targetName")
        selectedOffer.target = targetName:getText()
        protocolGame:sendExtendedOpcode(GAME_STORE_CODE, json.encode({action = "gift", data = selectedOffer}))
        targetName = nil
        giftWindow:destroy()
        giftWindow = nil
    end
end

function cancelGift()
    giftWindow:destroy()
    giftWindow = nil
end

function onGameStoreMsg(data)
    local type = data.type
    local text = data.msg

    local title = nil
    local close = false
    if type == "info" then
        title = "Store Information"
        close = data.close
    elseif type == "error" then
        title = "Store Error"
        close = true
    end

    if close then
        gameStoreWindow:getChildById("purchaseButton"):disable()
        gameStoreWindow:getChildById("giftButton"):disable()
        gameStoreWindow:getChildById("offers"):focusChild(nil)
    end

    displayInfoBox(title, text, {{text = "Ok", callback = defaultCallback}}, defaultCallback, defaultCallback)
end


function changeCategory(widget, newCategory)
    if not newCategory then
        return
    end

    local id = newCategory:getId()
    offersGrid:destroyChildren()
    addOffers(offers[id])

    local category = nil
    for i = 1, #categories do
        if categories[i].title == id then
            category = categories[i]
            break
        end
    end

    if category then
        updateTopPanel(category)
        gameStoreWindow:getChildById("purchaseButton"):disable()
        gameStoreWindow:getChildById("giftButton"):disable()
        gameStoreWindow:getChildById("search"):setText("")
    end
end

function offerFocus(widget, offerWidget)
    if offerWidget then
        local category = gameStoreWindow:getChildById("categories"):getFocusedChild():getChildById("name"):getText()
        local title = offerWidget:getChildById("offerNameHidden"):getText()
        local priceLabel = offerWidget:getChildById("offerPrice"):getText()
        local price = priceLabel:split(" points")[1]:gsub("%,", "")
        selectedOffer = {category = category, title = title, price = tonumber(price)}
        gameStoreWindow:getChildById("purchaseButton"):enable()
        gameStoreWindow:getChildById("giftButton"):enable()
    end
end

function addCategory(data, first)
    local category = g_ui.createWidget("ShopCategory", gameStoreWindow:getChildById("categories"))
    category:setId(data.title)
    category:getChildById("name"):setText(data.title)

    if first then
        updateTopPanel(data)
    end
end

function showHistory()
    gameStoreWindow:getChildById("historyButton"):hide()
    gameStoreWindow:getChildById("purchaseButton"):hide()
    gameStoreWindow:getChildById("giftButton"):hide()
    gameStoreWindow:getChildById("offers"):hide()
    gameStoreWindow:getChildById("offersScrollBar"):hide()
    gameStoreWindow:getChildById("topPanel"):hide()
    gameStoreWindow:getChildById("categories"):hide()
    gameStoreWindow:getChildById("infoPanel"):hide()
    gameStoreWindow:getChildById("search"):hide()
    gameStoreWindow:getChildById("searchLabel"):hide()

    gameStoreWindow:getChildById("historyScrollBar"):show()
    gameStoreWindow:getChildById("history"):show()
    gameStoreWindow:getChildById("backButton"):show()

    gameStoreWindow:getChildById("purchaseButton"):disable()
    gameStoreWindow:getChildById("giftButton"):disable()
    gameStoreWindow:getChildById("offers"):focusChild(nil)
end

function hideHistory()
    gameStoreWindow:getChildById("historyButton"):show()
    gameStoreWindow:getChildById("purchaseButton"):show()
    gameStoreWindow:getChildById("giftButton"):show()
    gameStoreWindow:getChildById("offers"):show()
    gameStoreWindow:getChildById("offersScrollBar"):show()
    gameStoreWindow:getChildById("topPanel"):show()
    gameStoreWindow:getChildById("categories"):show()
    gameStoreWindow:getChildById("infoPanel"):show()
    gameStoreWindow:getChildById("search"):show()
    gameStoreWindow:getChildById("searchLabel"):show()

    gameStoreWindow:getChildById("historyScrollBar"):hide()
    gameStoreWindow:getChildById("history"):hide()
    gameStoreWindow:getChildById("backButton"):hide()

    gameStoreWindow:getChildById("categories"):getChildByIndex(1):focus()
end

function updateTopPanel(data)
    local topPanel = gameStoreWindow:getChildById("topPanel")
    local categoryItemBg = topPanel:getChildById("categoryItemBg")
    categoryItemBg:destroyChildren()
    if data.iconType == "sprite" then
        local spriteIcon = g_ui.createWidget("CategoryIconSprite", categoryItemBg)
        spriteIcon:setSpriteId(data.iconData)
    elseif data.iconType == "item" then
        local spriteIcon = g_ui.createWidget("CategoryIconItem", categoryItemBg)
        spriteIcon:setItemId(data.iconData)
    elseif data.iconType == "outfit" or data.iconType == "wing" or data.iconType == "aura" then
        local spriteIcon = g_ui.createWidget("CategoryIconCreature", categoryItemBg)
        spriteIcon:setOutfit({type = data.iconData})
    elseif data.iconType == "shader" then
        local spriteIcon = g_ui.createWidget("CategoryIconCreature", categoryItemBg)
        local player = g_game.getLocalPlayer()
        if player then
            local outfit = player:getOutfit()
            outfit.shader = data.shaderName
            spriteIcon:setOutfit(outfit)
        end
    elseif data.iconType == "mount" then
        local spriteIcon = g_ui.createWidget("CategoryIconCreature", categoryItemBg)
        spriteIcon:setOutfit({type = data.iconData})
    end

    topPanel:getChildById("selectedCategory"):setText(data.title)
    topPanel:getChildById("categoryDescription"):setText(data.description)
end

function addOffers(offerData)
    offersGrid:destroyChildren()
    for i = 1, #offerData do
        local offer = offerData[i]
        local panel = g_ui.createWidget("OfferWidget")
        panel:setTooltip(offer.description)
        local nameHidden = panel:recursiveGetChildById("offerNameHidden")
        if offer.title:len() > 20 then
            local shorter = offer.title:sub(1, 20) .. "..."
            panel:setText(shorter)
        else
            panel:setText(offer.title)
        end
        nameHidden:setText(offer.title)

        local priceLabel = panel:recursiveGetChildById("offerPrice")
        local price = comma_value(offer.price)
        priceLabel:setText(string.format(priceLabel.baseText, price))

        local offerTypePanel = panel:getChildById("offerTypePanel")
        if offer.type == "item" then
            local offerIcon = g_ui.createWidget("OfferIconItem", offerTypePanel)
            offerIcon:setItemId(offer.clientId)
            offerIcon:setItemCount(offer.count)
        elseif offer.type == "outfit" then
            local offerIcon = g_ui.createWidget("OfferIconCreature", offerTypePanel)
            offerIcon:setOutfit(offer.outfit)
        elseif offer.type == "mount" then
            local offerIcon = g_ui.createWidget("OfferIconCreature", offerTypePanel)
            offerIcon:setOutfit({type = offer.clientId})
        elseif offer.type == "wing" then
            local offerIcon = g_ui.createWidget("OfferIconCreature", offerTypePanel)
            offerIcon:setOutfit({type = offer.clientId})
        elseif offer.type == "aura" then
            local offerIcon = g_ui.createWidget("OfferIconCreature", offerTypePanel)
            offerIcon:setOutfit({type = offer.clientId})
        elseif offer.type == "shader" then
            local offerIcon = g_ui.createWidget("OfferIconCreature", offerTypePanel)
            local player = g_game.getLocalPlayer()
            if player then
                local outfit = player:getOutfit()
                outfit.shader = offer.shaderName
                offerIcon:setOutfit(outfit)
            end
        end

        offersGrid:addChild(panel)
    end
end


function onSearch()
    scheduleEvent(
        function()
            local searchWidget = gameStoreWindow:getChildById("search")
            local text = searchWidget:getText()
            if text:len() >= 1 then
                local children = offersGrid:getChildCount()
                for i = 1, children do
                    local child = offersGrid:getChildByIndex(i)
                    local offerName = child:getChildById("offerNameHidden"):getText():lower()
                    if offerName:find(text) then
                        child:show()
                    else
                        child:hide()
                    end
                end
            else
                local children = offersGrid:getChildCount()
                for i = 1, children do
                    local child = offersGrid:getChildByIndex(i)
                    child:show()
                end
            end
        end,
        50
    )
end

function withdraw()
    if not withdrawWindow then
        withdrawWindow = g_ui.displayUI("withdraw")
    end

    withdrawWindow:show()
    withdrawWindow:raise()
    withdrawWindow:focus()
end

function confirmWithdraw()
    local amount = tonumber(withdrawWindow:getChildById("withdrawAmount"):getText())
    if not amount or amount <= 0 then
        displayInfoBox("Error", "Please enter a valid amount.")
        return
    end

    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
        protocolGame:sendExtendedOpcode(GAME_STORE_CODE, json.encode({action = "withdraw", data = {amount = amount}}))
    end

    withdrawWindow:hide()
end


function cancelWithdraw()
    if withdrawWindow then
        withdrawWindow:hide()
    end
end


function buyPoints()
    g_platform.openUrl(DONATION_URL)
end

function toggle()
    if not gameStoreWindow then
        return
    end
    if gameStoreWindow:isVisible() then
        return hide()
    end
    show()
end

function show()
    if not gameStoreWindow or not gameStoreButton then
        return
    end
    gameStoreWindow:getChildById("categories"):getChildByIndex(1):focus()
    hideHistory()
    gameStoreWindow:show()
    gameStoreWindow:raise()
    gameStoreWindow:focus()
end

function modules.game_store.toggleButtonImage(button)
    -- Se já houver um botão selecionado e ele for diferente do botão clicado
    if selectedButton and selectedButton ~= button then
        selectedButton:setImageSource("images/button-grey-up") -- Restaura o estado "off" no botão anterior
        selectedButton:setOn(false) -- Marca o botão anterior como desativado
    end

    -- Atualiza o estado do botão clicado
    if button:isOn() then
        button:setImageSource("images/button-grey-up") -- Marca o estado "off" no botão clicado
        button:setOn(false) -- Desativa o estado "on" no botão clicado
        selectedButton = nil -- Limpa a seleção, pois nenhum botão está selecionado
    else
        button:setImageSource("images/button-grey-down2") -- Marca o estado "on" no botão clicado
        button:setOn(true) -- Ativa o estado "on" no botão clicado
        selectedButton = button -- Atualiza o botão selecionado
    end
end



function hide()
    if not gameStoreWindow then
        return
    end
    gameStoreWindow:hide()
end

function comma_value(n)
    local left, num, right = string.match(n, "^([^%d]*%d)(%d*)(.-)$")
    return left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end
