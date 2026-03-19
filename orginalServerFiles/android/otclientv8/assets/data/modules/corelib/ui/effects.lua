-- chunkname: @/modules/corelib/ui/effects.lua

g_effects = {}

function g_effects.moveWidgetWithSpeed(widget, origin, target)
	if widget.movementFadeEvent then
		removeEvent(widget.movementFadeEvent)

		widget.movementFadeEvent = nil
	end

	widget:setPosition(origin)

	local fps = math.max(30, math.min(g_app.getFps(), 60))
	local startX, startY = origin.x, origin.y
	local deltaX, deltaY = target.x - startX, target.y - startY
	local numFrames = fps / 2
	local stepX, stepY = deltaX / numFrames, deltaY / numFrames
	local frameCount = 0
	local oldParent = widget:getParent()
	local oldIndex = oldParent:getChildIndex(widget)

	widget:setParent(modules.game_interface.getRootPanel())

	local blank = g_ui.createWidget("UIWidget")

	blank:setRect(widget:getRect())
	blank:setParent(oldParent)
	oldParent:moveChildToIndex(blank, oldIndex)
	widget:breakAnchors()

	widget.static = true
	widget.isOnMovingToTarget = true

	local function moveFrame()
		if widget.movementFadeEvent then
			removeEvent(widget.movementFadeEvent)

			widget.movementFadeEvent = nil
		end

		frameCount = frameCount + 1

		local newX = startX + frameCount * stepX
		local newY = startY + frameCount * stepY
		local currentX, currentY = widget:getPosition().x, widget:getPosition().y
		local lerpedX = (currentX * (numFrames - frameCount) + newX * frameCount) / numFrames
		local lerpedY = (currentY * (numFrames - frameCount) + newY * frameCount) / numFrames

		widget:setPosition({
			x = lerpedX,
			y = lerpedY
		})

		if frameCount < numFrames then
			widget.movementFadeEvent = scheduleEvent(moveFrame, fps / 24)
		else
			widget.static = nil
			widget.isOnMovingToTarget = nil

			oldParent:removeChild(blank)
			widget:setParent(oldParent)
			oldParent:moveChildToIndex(widget, oldIndex)
			widget:bindRectToParent()
			blank:destroy()
		end
	end

	widget.movementFadeEvent = scheduleEvent(moveFrame, fps / 24)
end

function g_effects.fadeIn(widget, time, elapsed)
	elapsed = elapsed or 0
	time = time or 300

	widget:setOpacity(math.min(elapsed / time, 1))
	removeEvent(widget.fadeEvent)

	if elapsed < time then
		removeEvent(widget.fadeEvent)

		widget.fadeEvent = scheduleEvent(function()
			g_effects.fadeIn(widget, time, elapsed + 30)
		end, 30)
	else
		widget.fadeEvent = nil
	end
end

function g_effects.fadeOut(widget, time, elapsed)
	elapsed = elapsed or 0
	time = time or 300
	elapsed = math.max((1 - widget:getOpacity()) * time, elapsed)

	removeEvent(widget.fadeEvent)
	widget:setOpacity(math.max((time - elapsed) / time, 0))

	if elapsed < time then
		widget.fadeEvent = scheduleEvent(function()
			g_effects.fadeOut(widget, time, elapsed + 30)
		end, 30)
	else
		widget.fadeEvent = nil
	end
end

function g_effects.cancelFade(widget)
	removeEvent(widget.fadeEvent)

	widget.fadeEvent = nil
end

function g_effects.startBlink(widget, duration, interval, clickCancel)
	duration = duration or 0
	interval = interval or 500
	clickCancel = clickCancel or true

	removeEvent(widget.blinkEvent)
	removeEvent(widget.blinkStopEvent)

	widget.blinkEvent = cycleEvent(function()
		widget:setOn(not widget:isOn())
	end, interval)

	if duration > 0 then
		widget.blinkStopEvent = scheduleEvent(function()
			g_effects.stopBlink(widget)
		end, duration)
	end

	connect(widget, {
		onClick = g_effects.stopBlink
	})
end

function g_effects.stopBlink(widget)
	disconnect(widget, {
		onClick = g_effects.stopBlink
	})
	removeEvent(widget.blinkEvent)
	removeEvent(widget.blinkStopEvent)

	widget.blinkEvent = nil
	widget.blinkStopEvent = nil

	widget:setOn(false)
end
