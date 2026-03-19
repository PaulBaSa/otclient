-- chunkname: @/modules/game_healthinfo/healthinfo.lua

healthInfoWindow = nil
healthInfoWindow = nil
healthBar = nil
manaBar = nil
healthTooltip = "Your character health is %d out of %d."
manaTooltip = "Your character mana is %d out of %d."
overlay = nil
healthCircleFront = nil
manaCircleFront = nil
healthCircle = nil
manaCircle = nil
topHealthBar = nil
topManaBar = nil

function init()
	connect(LocalPlayer, {
		onHealthChange = onHealthChange,
		onManaChange = onManaChange
	})

	healthInfoWindow = g_ui.loadUI("healthinfo", modules.game_interface.getMainRightPanel())
	healthInfoWindow.forceHideScrollBar = true
	healthInfoWindow.ignoreExpandingHeight = true

	healthInfoWindow:getChildById("miniwindowScrollBar"):hide()
	healthInfoWindow:disableResize()
	healthInfoWindow:setContentMinimumHeight(36)
	healthInfoWindow:setContentMaximumHeight(36)

	healthInfoWindow.health = healthInfoWindow:getChildById("contentsPanel"):getChildById("health")
	healthInfoWindow.health.icon = healthInfoWindow.health:getChildById("icon")
	healthInfoWindow.health.text = healthInfoWindow.health:getChildById("text")
	healthInfoWindow.health.total = healthInfoWindow.health:getChildById("total")
	healthInfoWindow.health.current = healthInfoWindow.health:getChildById("current")
	healthInfoWindow.mana = healthInfoWindow:getChildById("contentsPanel"):getChildById("mana")
	healthInfoWindow.mana.icon = healthInfoWindow.mana:getChildById("icon")
	healthInfoWindow.mana.text = healthInfoWindow.mana:getChildById("text")
	healthInfoWindow.mana.total = healthInfoWindow.mana:getChildById("total")
	healthInfoWindow.mana.current = healthInfoWindow.mana:getChildById("current")


	healthBar = healthInfoWindow:recursiveGetChildById("health")
	manaBar = healthInfoWindow:recursiveGetChildById("mana")
	overlay = g_ui.createWidget("HealthOverlay", modules.game_interface.getMapPanel())
	healthCircleFront = overlay:getChildById("healthCircleFront")
	manaCircleFront = overlay:getChildById("manaCircleFront")
	healthCircle = overlay:getChildById("healthCircle")
	manaCircle = overlay:getChildById("manaCircle")
	topHealthBar = overlay:getChildById("topHealthBar")
	topManaBar = overlay:getChildById("topManaBar")

	connect(overlay, {
		onGeometryChange = onOverlayGeometryChange
	})

	if g_game.isOnline() then
		local localPlayer = g_game.getLocalPlayer()

		onHealthChange(localPlayer, localPlayer:getHealth(), localPlayer:getMaxHealth())
		onManaChange(localPlayer, localPlayer:getMana(), localPlayer:getMaxMana())
	end

	healthInfoWindow:setup()

	if g_app.isMobile() then
		healthInfoWindow:close()
	end

	if not g_app.isMobile() then
		modules.game_healthinfo.topHealthBar:setVisible(false)
		modules.game_healthinfo.topManaBar:setVisible(false)
	end
end

function terminate()
	disconnect(LocalPlayer, {
		onHealthChange = onHealthChange,
		onManaChange = onManaChange
	})
	disconnect(overlay, {
		onGeometryChange = onOverlayGeometryChange
	})
	healthInfoWindow:destroy()

	if healthInfoButton then
		healthInfoButton:destroy()
	end

	overlay:destroy()
end

function toggle()
	if not healthInfoButton then
		return
	end

	if healthInfoButton:isOn() then
		healthInfoWindow:close()
		healthInfoButton:setOn(false)
	else
		healthInfoWindow:open()
		healthInfoButton:setOn(true)
	end
end

function onMiniWindowClose()
	if healthInfoButton then
		healthInfoButton:setOn(false)
	end
end

function onHealthChange(localPlayer, health, maxHealth)
	local player = g_game.getLocalPlayer()

	if not player then
		return
	end

	if maxHealth < health then
		maxHealth = health
	end

	local Yhppc = math.floor(208 * (1 - math.floor((maxHealth - (maxHealth - health)) * 100 / maxHealth) / 100))

	healthInfoWindow.health.text:setText(player:getHealth())
	healthInfoWindow.health.current:setWidth(math.max(1, math.ceil(healthInfoWindow.health.total:getWidth() * player:getHealth() / player:getMaxHealth())))

	local rect = {
		x = 0,
		width = 63,
		y = Yhppc,
		height = 208 - Yhppc + 1
	}

	healthCircleFront:setImageClip(rect)
	healthCircleFront:setImageRect(rect)

	local healthPercent = math.floor(g_game.getLocalPlayer():getHealthPercent())

	if healthPercent > 92 then
		healthCircleFront:setImageColor("#00BC00FF")
	elseif healthPercent > 60 then
		healthCircleFront:setImageColor("#50A150FF")
	elseif healthPercent > 30 then
		healthCircleFront:setImageColor("#A1A100FF")
	elseif healthPercent > 8 then
		healthCircleFront:setImageColor("#BF0A0AFF")
	elseif healthPercent > 3 then
		healthCircleFront:setImageColor("#910F0FFF")
	else
		healthCircleFront:setImageColor("#850C0CFF")
	end
end

function onManaChange(localPlayer, mana, maxMana)
	local player = g_game.getLocalPlayer()

	if not player then
		return
	end

	if maxMana < mana then
		maxMana = mana
	end

	local currentWidth = 0
	local Ymppc = 0

	if maxMana ~= 0 then
		currentWidth = math.max(1, math.ceil(healthInfoWindow.mana.total:getWidth() * mana / maxMana))
		Ymppc = math.floor(208 * (1 - math.floor((maxMana - (maxMana - mana)) * 100 / maxMana) / 100))
	else
		currentWidth = healthInfoWindow.mana.total:getWidth()
	end

	healthInfoWindow.mana.text:setText(player:getMana())
	healthInfoWindow.mana.current:setWidth(currentWidth)

	local rect = {
		x = 0,
		width = 63,
		y = Ymppc,
		height = 208 - Ymppc + 1
	}

	manaCircleFront:setImageClip(rect)
	manaCircleFront:setImageRect(rect)
end

function setHealthTooltip(tooltip)
	healthTooltip = tooltip

	local localPlayer = g_game.getLocalPlayer()

	if localPlayer then
		healthBar:setTooltip(tr(healthTooltip, localPlayer:getHealth(), localPlayer:getMaxHealth()))
	end
end

function setManaTooltip(tooltip)
	manaTooltip = tooltip

	local localPlayer = g_game.getLocalPlayer()

	if localPlayer then
		manaBar:setTooltip(tr(manaTooltip, localPlayer:getMana(), localPlayer:getMaxMana()))
	end
end

function onOverlayGeometryChange()
	if g_app.isMobile() then
		topHealthBar:setMarginTop(35)
		topManaBar:setMarginTop(35)

		local width = overlay:getWidth()
		local margin = width / 3 + 10

		topHealthBar:setMarginLeft(margin)
		topManaBar:setMarginRight(margin)

		return
	end

	local minMargin = 40

	topHealthBar:setMarginTop(15)
	topManaBar:setMarginTop(15)

	local height = overlay:getHeight()
	local width = overlay:getWidth()

	topHealthBar:setMarginLeft(math.max(minMargin, (width - height + 50) / 2 + 2))
	topManaBar:setMarginRight(math.max(minMargin, (width - height + 50) / 2 + 2))
end
