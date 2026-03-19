tradeWindow = nil

function init()
  g_ui.importStyle('tradewindow')

  connect(g_game, { onOwnTrade = onGameOwnTrade,
                    onCounterTrade = onGameCounterTrade,
                    onCloseTrade = onGameCloseTrade,
                    onGameEnd = onGameCloseTrade })
end

function terminate()
  disconnect(g_game, { onOwnTrade = onGameOwnTrade,
                       onCounterTrade = onGameCounterTrade,
                       onCloseTrade = onGameCloseTrade,
                       onGameEnd = onGameCloseTrade })

  if tradeWindow then
    tradeWindow:destroy()
  end
end

function createTrade()
  tradeWindow = g_ui.createWidget('TradeWindow', modules.game_interface.getRightPanel())
  tradeWindow.onClose = function()
    g_game.rejectTrade()
    tradeWindow:hide()
  end
  tradeWindow:setup()
end

function fillTrade(name, items, positions, counter)
  if not tradeWindow then
    createTrade()
  end

  local tradeItemWidget = tradeWindow:getChildById('tradeItem')
  tradeItemWidget:setItemId(items[1]:getId())

  local tradeContainer
  local label
  local countLabel
  if counter then
    tradeContainer = tradeWindow:recursiveGetChildById('counterTradeContainer')
    label = tradeWindow:recursiveGetChildById('counterTradeLabel')
    countLabel = tradeWindow:recursiveGetChildById('counterTradeCountLabel')
    tradeWindow:recursiveGetChildById('acceptButton'):enable()
  else
    tradeContainer = tradeWindow:recursiveGetChildById('ownTradeContainer')
    label = tradeWindow:recursiveGetChildById('ownTradeLabel')
    countLabel = tradeWindow:recursiveGetChildById('ownTradeCountLabel')
  end
  label:setText(name)
  countLabel:setText(tr("Items") .. ": " .. #items)
  for i = 1, #items do
    local itemWidget = g_ui.createWidget('PlayerTradeItem', tradeContainer)
    items[i].position = positions[i]
    items[i].counter = counter
    itemWidget:setItem(items[i])
    itemWidget:setMargin(0)
    g_game.updateRarityFrames(itemWidget, items[i]:getRarityId())
    itemWidget.onClick = function()
      g_game.inspectTrade(counter, i - 1)
    end
  end
end

function onGameOwnTrade(name, items, positions)
  fillTrade(name, items, positions, false)
end

function onGameCounterTrade(name, items, positions)
  fillTrade(name, items, positions, true)
end

function onGameCloseTrade()
  if tradeWindow then
    tradeWindow:destroy()
    tradeWindow = nil
  end
end
