local OPCODE = 100

buffsPanel = nil
local timerEvent = {}
local server_time = 0
local server_timer = nil

function init()
  connect(
    g_game,
    {
      onGameStart = create,
      onGameEnd = destroy
    }
  )
end

function create()
  if buffsPanel then
    return
  end

  buffsPanel = g_ui.loadUI("buffs", modules.game_interface.getMapPanel())
  server_timer = scheduleEvent(doServerTime, 950)

  ProtocolGame.registerExtendedOpcode(OPCODE, onExtendedOpcode)
end

function doServerTime()
  server_time = server_time + 1000
  server_timer = scheduleEvent(doServerTime, 1000)
end

function onExtendedOpcode(protocol, code, buffer)
  local json_status, json_data =
    pcall(
    function()
      return json.decode(buffer)
    end
  )

  if not json_status then
    g_logger.error("[Buffs] JSON error: " .. json_data)
    return false
  end

  local action = json_data["action"]
  local data = json_data["data"]
  if not action then
    return false
  end

  if action == "add" then
    addBuff(data)
  elseif action == "update" then
    updateBuff(data)
  elseif action == "remove" then
    removeBuff(data)
  end
end

function addBuff(buff)
  local panelId = buff.debuff and 2 or 1
  local iconsPanel = buffsPanel:getChildByIndex(panelId)
  if buff.debuff then
    local t = buffsPanel:getChildByIndex(1)
    if t:getChildCount() == 0 then
      t:setHeight(0)
    end
  else
    iconsPanel:setHeight(50)
  end
  local oldBuff = iconsPanel:recursiveGetChildById("buff" .. buff.id)
  if oldBuff then
    if timerEvent[buff.id] then
      removeEvent(timerEvent[buff.id])
      timerEvent[buff.id] = nil
    end
    oldBuff:destroy()
  end

  local newBuff = g_ui.createWidget("Buff", buffsPanel:getChildByIndex(panelId))
  newBuff:setId("buff" .. buff.id)
  newBuff:setTooltip(buff.name .. "\n" .. buff.description)
  newBuff:getChildByIndex(1):setImageSource("/images/buffs/" .. buff.icon)
  newBuff:getChildByIndex(2):setImageSource("/images/buffs/" .. buff.border)
  if buff.stacks > 1 then
    newBuff:getChildByIndex(3):setText(buff.stacks)
    newBuff:getChildByIndex(3):show()
  else
    newBuff:getChildByIndex(3):hide()
  end
  if buff.ticks ~= -1 then
    server_time = buff.server_time * 1000

    newBuff:getChildByIndex(4):setText(SecondsToTime(buff.endTime - server_time))
    newBuff:getChildByIndex(4):show()

    timerEvent[buff.id] =
      scheduleEvent(
      function()
        doTimer(buff)
      end,
      1000
    )
  else
    newBuff:getChildByIndex(4):hide()
  end
end

function updateBuff(buff)
  local panelId = buff.debuff and 2 or 1
  local buffWidget = buffsPanel:getChildByIndex(panelId):recursiveGetChildById("buff" .. buff.id)

  if buffWidget then
    if buff.stacks > 1 then
      buffWidget:getChildByIndex(3):setText(buff.stacks)
      buffWidget:getChildByIndex(3):show()
    else
      buffWidget:getChildByIndex(3):hide()
    end
    if buff.ticks ~= -1 then
      server_time = buff.server_time * 1000

      buffWidget:getChildByIndex(4):setText(SecondsToTime(buff.endTime - server_time))
      buffWidget:getChildByIndex(4):show()

      if timerEvent[buff.id] then
        removeEvent(timerEvent[buff.id])
        timerEvent[buff.id] = nil
      end

      timerEvent[buff.id] =
        scheduleEvent(
        function()
          doTimer(buff)
        end,
        1000
      )
    else
      buffWidget:getChildByIndex(4):hide()
    end
  end
end

function removeBuff(buff)
  local panelId = buff.debuff and 2 or 1
  local iconsPanel = buffsPanel:getChildByIndex(panelId)
  local buffWidget = iconsPanel:recursiveGetChildById("buff" .. buff.id)
  if buffWidget then
    buffWidget:destroy()
    if timerEvent[buff.id] then
      removeEvent(timerEvent[buff.id])
      timerEvent[buff.id] = nil
    end
    local t = buffsPanel:getChildByIndex(1)
    if t:getChildCount() == 0 then
      t:setHeight(0)
    end
  end
end

function doTimer(buff)
  if not buffsPanel then
    return
  end

  local buffWidget = buffsPanel:recursiveGetChildById("buff" .. buff.id)

  if buffWidget then
    buffWidget:getChildByIndex(4):setText(SecondsToTime(buff.endTime - server_time))

    timerEvent[buff.id] =
      scheduleEvent(
      function()
        doTimer(buff)
      end,
      1000
    )
  else
    timerEvent[buff.id] = nil
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
end

function destroy()
  if server_timer then
    removeEvent(server_timer)
    server_timer = nil
  end

  for k, v in pairs(timerEvent) do
    removeEvent(v)
  end

  timerEvent = {}

  ProtocolGame.unregisterExtendedOpcode(OPCODE, onExtendedOpcode)

  if buffsPanel then
    buffsPanel:destroy()
    buffsPanel = nil
  end
end

function hide()
  buffsPanel:hide()
end

function show()
  buffsPanel:show()
end

function SecondsToTime(seconds)
  seconds = tonumber(seconds) / 1000

  if seconds <= 0 then
    return "00:00"
  else
    local hours = math.floor(seconds / 3600)
	if hours > 0 then
		return math.min(24, hours) .. "h+"
	end
    local mins = string.format("%01.f", math.floor(seconds / 60 - (hours * 60)))
    local secs = string.format("%02.f", math.floor(seconds - hours * 3600 - mins * 60))
    return mins .. ":" .. secs
  end
end
