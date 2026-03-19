UIMiniWindow = extends(UIWindow, "UIMiniWindow")

local config = {
    animatedWidgetMovementOnPanel = false
}

function UIMiniWindow.create()
    local miniwindow = UIMiniWindow.internalCreate()
    miniwindow.UIMiniWindowContainer = true
    return miniwindow
end

function UIMiniWindow:open(dontSave)
    if not self:getParent() then
        self:setParent(modules.game_interface.getMainRightPanel())
    end

    self:setVisible(true)

    if not dontSave then
        self:setSettings({ closed = false })
        if self:getParent() and self:getParent():isExplicitlyVisible() then
            self:getParent():saveChildren()
        end
    end

    if self:getParent() and self:getParent():getClassName() == "UIMiniWindowContainer" then
        self:getParent():reloadChildReorderMargin()
    end

    signalcall(self.onOpen, self)
end

function UIMiniWindow:close(dontSave)
	if not self:isExplicitlyVisible() then
		return
	end

	if self.forceOpen then
		return
	end

	self:setVisible(false)

	if not dontSave then
		self:setSettings({
			closed = true
		})

		if self:getParent() and self:getParent():isExplicitlyVisible() then
			self:getParent():saveChildren()
		end

		self:saveParentIndex(nil, nil)
	end

	if self:getParent() and self:getParent():getClassName() == "UIMiniWindowContainer" then
		self:getParent():reloadChildReorderMargin()
	end

	signalcall(self.onClose, self)
end


function UIMiniWindow:minimize(dontSave)
	self:setOn(true)
	self:getChildById("contentsPanel"):hide()
	self:getChildById("miniwindowScrollBar"):hide()
	self:getChildById("bottomResizeBorder"):hide()

	local triangle = self:getTriangle()

	if triangle then
		triangle:hide()
	end

	if self.minimizeButton then
		self.minimizeButton:setOn(true)
	end

	self.maximizedHeight = self:getHeight()

	self:setHeight(self.minimizedHeight)

	if not dontSave then
		self:setSettings({
			minimized = true
		})
	end

	if self:getParent() and self:getParent():getClassName() == "UIMiniWindowContainer" then
		self:getParent():reloadChildReorderMargin()
	end

	signalcall(self.onMinimize, self)
	self:getParent():updateChildrenIndexStates()
end

function UIMiniWindow:maximize(dontSave)
	self:setOn(false)
	self:getChildById("contentsPanel"):show()

	if not self.forceHideScrollBar then
		self:getChildById("bottomResizeBorder"):show()
		self:getChildById("miniwindowScrollBar"):show()
	end

	local triangle = self:getTriangle()

	if triangle then
		triangle:show()
	end

	if self.minimizeButton then
		self.minimizeButton:setOn(false)
	end

	self:setHeight(self:getSettings("height") or self.maximizedHeight)

	if not dontSave then
		self:setSettings({
			minimized = false
		})
	end

	local parent = self:getParent()

	if parent and parent:getClassName() == "UIMiniWindowContainer" then
		parent:fitAll(self)
	end

	signalcall(self.onMaximize, self)
	self:getParent():updateChildrenIndexStates()
end

function UIMiniWindow:lock(dontSave)
	local lockButton = self:getChildById("lockButton")

	if lockButton then
		lockButton:setOn(true)
	end

	self:setDraggable(false)

	if not dontsave then
		self:setSettings({
			locked = true
		})
	end

	signalcall(self.onLockChange, self)
end

function UIMiniWindow:unlock(dontSave)
	local lockButton = self:getChildById("lockButton")

	if lockButton then
		lockButton:setOn(false)
	end

	self:setDraggable(true)

	if not dontsave then
		self:setSettings({
			locked = false
		})
	end

	signalcall(self.onLockChange, self)
end

function UIMiniWindow:setup()
	self:getChildById("closeButton").onClick = function()
		if not self.isBlankMainPanel then
			self:close()
		end
	end

	if self.forceOpen and self.closeButton then
		self.closeButton:hide()
	end

	if self.minimizeButton then
		function self.minimizeButton.onClick()
			if self:isOn() then
				self:maximize()
			else
				self:minimize()
			end
		end
	end

	local lockButton = self:getChildById("lockButton")

	if lockButton then
		function lockButton.onClick()
			if self:isDraggable() then
				self:lock()
			else
				self:unlock()
			end
		end
	end

	self:getChildById("bottomResizeBorder").onDoubleClick = function()
		local resizeBorder = self:getChildById("bottomResizeBorder")

		self:setHeight(resizeBorder:getMinimum())
	end

	local oldParent = self:getParent()
	local settings = {}

	if self.save then
		settings = g_settings.getNode("MiniWindows")
	end

	if settings then
		local parentId = self:getSettings("parentId")
		local index = self:getSettings("parentIndex")
		local visible = self:getSettings("visible")

		if parentId and visible then
			local parent = rootWidget:recursiveGetChildById(parentId)

			if parent and parent:getClassName() == "UIMiniWindowContainer" then
				if parent ~= oldParent and oldParent ~= nil then
					oldParent:removeChild(self)
					parent:addChild(self)
				end

				parent:scheduleInsert(self, index)
			end
		end
	end

	if self:getParent() and self:getParent():isChildReOrderToggle() then
		self:getParent():fitAll()
	end

	local triangle = self:getChildById("bottomResizeBorderTriangle")

	if triangle then
		triangle:raise()
	end
end



function UIMiniWindow:onVisibilityChange(visible)
	self:fitOnParent()
end

local function createBlackPanelWidget(height, parent, index, highlight)
	local widget = g_ui.createWidget("MiniWindowShadow", nil)

	widget.isBlackPanel = true

	widget:setWidth(parent:getWidth())
	widget:setHeight(height)

	if highlight then
		widget:setBorderWidthRight(2)
		widget:setBorderWidthLeft(2)
		widget:setBorderColor("#FFFFFF")
	end

	if index == -1 then
		parent:addChild(widget)
	else
		parent:insertChild(index, widget)
	end

	parent:fitAll()

	return widget
end

function UIMiniWindow:onDragEnter(mousePos)
	local parent = self:getParent()

	if not parent then
		return false
	end

	if parent:getClassName() == "UIMiniWindowContainer" then
		local containerParent = parent:getParent():getParent()
		local index = parent:getChildIndex(self)

		parent:removeChild(self)
		containerParent:addChild(self)

		if not self:isFromMainPanel() then
			self.blackShadow = createBlackPanelWidget(self:getHeight(), parent, index, false)
		end
	end

	local oldPos = self:getPosition()

	self.movingReference = {
		x = mousePos.x - oldPos.x,
		y = mousePos.y - oldPos.y
	}

	self:setPosition(oldPos)

	self.free = true

	return true
end

function UIMiniWindow:onDragLeave(droppedWidget, mousePos)
	if not self:isFromMainPanel() then
		local shadowParent, hoverParent

		if self.blackShadow ~= nil then
			shadowParent = self.blackShadow:getParent()

			self.blackShadow:destroy()

			self.blackShadow = nil
		end

		if self.hoverBlackPanel ~= nil then
			hoverParent = self.hoverBlackPanel:getParent()

			self.hoverBlackPanel:destroy()

			self.hoverBlackPanel = nil
		end

		if shadowParent and shadowParent:getClassName() == "UIMiniWindowContainer" then
			shadowParent:reloadChildReorderMargin()
		end

		if hoverParent and hoverParent ~= shadowParent and hoverParent:getClassName() == "UIMiniWindowContainer" then
			hoverParent:reloadChildReorderMargin()
		end
	end

	local function moveWidgetUsingEffect(widget, mouse)
		if not widget.isOnMovingToTarget then
			local mousePosOverDiffTopLeft = widget.mousePosOverDiffTopLeft
			local origin = {
				x = mouse.x - mousePosOverDiffTopLeft.x,
				y = mouse.y - mousePosOverDiffTopLeft.y
			}
			local target = widget:getPosition()

			g_effects.moveWidgetWithSpeed(widget, origin, target)
		end

		widget.mousePosOverDiffTopLeft = nil
	end

	local movedWidget, movedIndex = self.movedWidget, self.movedIndex

	if movedWidget then
		self.setMovedChildMargin(self.movedOldMargin or 0)

		if self:getParent() and self:getParent():getClassName() == "UIMiniWindowContainer" then
			self:getParent():reloadChildReorderMargin()
		end

		self.movedWidget = nil
		self.setMovedChildMargin = nil
		self.movedOldMargin = nil
		self.movedIndex = nil
	end

	local children = rootWidget:recursiveGetChildrenByMarginPos(mousePos)
	local dropInPanel = 0

	for i = 1, #children do
		local child = children[i]

		if child:getId() == "gameLeftPanels" or child:getId() == "gameRightPanels" or child:getClassName() == "UIMiniWindowContainer" and child:isMainPanel() then
			dropInPanel = 1
		end
	end

	tmpp = self

	if droppedWidget == nil then
		dropInPanel = 0

		if self:isFromMainPanel() then
			local parent = modules.game_interface.getMainRightPanel()

			if parent then
				local pos = {
					x = parent:getPosition().x + parent:getWidth() / 2,
					y = math.max(parent:getPosition().y + 5, parent:getPosition().y + parent:getHeight() - 10)
				}

				if movedWidget == nil then
					movedWidget = parent:getChildByIndex(-1)
					movedIndex = parent:getChildIndex(movedWidget)
				end

				if movedWidget and movedIndex ~= nil then
					if movedWidget == self then
						return
					end

					local indexOffset = parent:getChildIndex(movedWidget)

					if mousePos.y >= movedWidget:getPosition().y + movedWidget:getRect().height / 2 then
						indexOffset = indexOffset + 1
					end

					if movedIndex ~= indexOffset then
						if self:getParent() == parent then
							parent:moveChildToIndex(self, indexOffset)
						else
							self:getParent():removeChild(self)
							parent:insertChild(indexOffset, self)
						end

						return
					end

					return
				end
			end
		end
	elseif not self:isFromMainPanel() and droppedWidget:isMainPanel() or self:isFromMainPanel() and not droppedWidget:isMainPanel() then
		dropInPanel = 0
	elseif droppedWidget.isBlankMainPanel then
		dropInPanel = 0
	elseif droppedWidget and self:isFromMainPanel() then
		return
	end

	if dropInPanel == 0 then
		local parent = self.movedFromParent
		local index = self.movedFromParentIndex

		addEvent(function()
			if parent == nil then
				tmpp:setParent(modules.game_interface.getMainRightPanel())

				parent = tmpp:getParent()
			else
				parent:insertChild(index, tmpp)
			end

			tmpp:saveParent(parent)

			index = nil
			parent = nil

			if tmpp and tmpp:getClassName() == "UIMiniWindowContainer" then
				tmpp:reloadChildReorderMargin()
			end
		end)
	else
		if self:getParent() and type(self:getParent().fits) == "function" and self:getParent():fits(self, self:getHeight(), 0) < 0 then
			self:getParent():fitAll()
		end

		if self.movedFromParent and self.movedFromParent:getClassName() == "UIMiniWindowContainer" then
			self.movedFromParent:saveChildren()
		end

		self.movedFromParent = nil
		self.movedFromParentIndex = nil
	end

	modules.game_interface.highlightPanel(nil)

	self.movedFromParentOrder = nil

	UIWindow:onDragLeave(self, droppedWidget, mousePos)
	self:saveParent(self:getParent())

	if config.animatedWidgetMovementOnPanel then
		if dropInPanel == 0 then
			addEvent(function()
				moveWidgetUsingEffect(tmpp, mousePos)
			end)
		else
			moveWidgetUsingEffect(tmpp, mousePos)
		end
	end
end

local function isOnSamePanel(origin, widget)
	if origin == nil or widget == nil then
		return false
	end

	local debugParent = widget:getParent()

	while debugParent ~= nil do
		if origin == debugParent then
			return true
		end

		debugParent = debugParent:getParent()
	end

	return false
end

function UIMiniWindow:isFromMainPanel()
	if self.movedFromParent ~= nil then
		return self.movedFromParent ~= nil and self.movedFromParent:getClassName() == "UIMiniWindowContainer" and self.movedFromParent:isMainPanel()
	end

	return self:getParent() ~= nil and self:getParent():getClassName() == "UIMiniWindowContainer" and self:getParent():isMainPanel()
end

local function getNextChildNotBlack(child)
	if child:isFromMainPanel() then
		return nil
	end

	while child ~= nil do
		if not child:getParent() then
			break
		end

		local oldChild = child

		child = child:getParent():getChildByIndex(child:getParent():getChildIndex(child) + 1)

		if child == oldChild then
			break
		end

		if child ~= nil and not child.isBlackPanel then
			return child
		end
	end

	return nil
end

local function updateDragHoverMargin(widget, child, v)
	if widget == nil or child == nil then
		return
	end

	local margin = widget.movedIndex
	local childParent = child:getParent()

	if not widget:isFromMainPanel() and not child:isFromMainPanel() and childParent and childParent:getClassName() == "UIMiniWindowContainer" then
		if v == 0 then
			if widget.hoverBlackPanel ~= nil and widget.hoverBlackPanel:getParent() ~= child:getParent() then
				local hoverParent = widget.hoverBlackPanel:getParent()

				widget.hoverBlackPanel:destroy()

				widget.hoverBlackPanel = nil

				if hoverParent:getClassName() == "UIMiniWindowContainer" then
					hoverParent:reloadChildReorderMargin()
				end
			end
		else
			if widget.blackShadow ~= nil and widget.blackShadow:getHeight() ~= 0 then
				widget.blackShadow:setHeight(0)

				if widget.blackShadow:getParent():getClassName() == "UIMiniWindowContainer" then
					widget.blackShadow:getParent():reloadChildReorderMargin()
				end
			end

			if widget.hoverBlackPanel ~= nil then
				local hoverParent = widget.hoverBlackPanel:getParent()

				if hoverParent ~= child:getParent() then
					widget.hoverBlackPanel:destroy()

					widget.hoverBlackPanel = nil
				elseif hoverParent:getChildIndex(widget.hoverBlackPanel) ~= childParent:getChildIndex(child) + margin then
					widget.hoverBlackPanel:destroy()

					widget.hoverBlackPanel = nil
				end

				if hoverParent:getClassName() == "UIMiniWindowContainer" then
					hoverParent:reloadChildReorderMargin()
				end
			end

			if widget.hoverBlackPanel == nil then
				widget.hoverBlackPanel = createBlackPanelWidget(widget:getHeight(), childParent, childParent:getChildIndex(child) + margin, childParent ~= widget.blackShadow:getParent())

				if childParent:getClassName() == "UIMiniWindowContainer" then
					childParent:reloadChildReorderMargin()
				end
			end
		end
	elseif margin == 1 then
		child:setMarginBottom(v)
	else
		child:setMarginTop(v)
	end

	if childParent ~= nil and childParent:getParent():getClassName() == "UIMiniWindowContainer" then
		childParent:getParent():fitAll()
	end
end

function UIMiniWindow:onDragMove(mousePos, mouseMoved)
	if self:isFromMainPanel() then
		local parent = modules.game_interface.getMainRightPanel()

		if parent then
			mousePos = {
				x = parent:getPosition().x + parent:getWidth() / 2,
				y = math.max(parent:getPosition().y + 5, math.min(parent:getPosition().y + parent:getHeight() - 5, mousePos.y))
			}
		end
	end

	local recursivePanel
	local oldMousePosY = mousePos.y - mouseMoved.y
	local children = rootWidget:recursiveGetChildrenByMarginPos(mousePos)
	local overAnyWidget, removeHighlight = false, true

	for i = 1, #children do
		do
			local child = children[i]

			if child.isBlackPanel then
				child = getNextChildNotBlack(child)

				if child == nil then
					goto label_24_0
				end
			end

			local isChildMainPanel = child:getParent():getClassName() == "UIMiniWindowContainer" and child:getParent():isMainPanel()

			if isChildMainPanel and not self:isFromMainPanel() then
				child = modules.game_interface.getFirstRightSidePanel()

				if child == nil then
					goto label_24_0
				end
			end

			if child:getClassName() == "UIMiniWindowContainer" then
				recursivePanel = child
			end

			local samePanel = isOnSamePanel(self.movedFromParent, child)

			if not self:isFromMainPanel() and removeHighlight and not samePanel and self.movedFromParent ~= nil and child:isChildReOrderToggle() and child:getId() ~= self.movedFromParent:getId() then
				modules.game_interface.highlightPanel(child)

				removeHighlight = false
			elseif not self:isFromMainPanel() and removeHighlight and not samePanel and self.movedFromParent ~= nil and child:getParent():isChildReOrderToggle() and child:getId() ~= self.movedFromParent:getId() then
				modules.game_interface.highlightPanel(child:getParent())

				removeHighlight = false
			end

			if child:getParent():getClassName() == "UIMiniWindowContainer" and (not self:isFromMainPanel() or isChildMainPanel) and (self:isFromMainPanel() or not isChildMainPanel) and not child.isBlankMainPanel then
				overAnyWidget = true

				local childCenterY = child:getY() + child:getHeight() / 2

				if child == self.movedWidget and childCenterY > mousePos.y and oldMousePosY < childCenterY then
					break
				end

				if self.movedWidget then
					self.setMovedChildMargin(self.movedOldMargin or 0)

					self.setMovedChildMargin = nil
				end

				if childCenterY > mousePos.y then
					self.movedOldMargin = child:getMarginTop()
					self.movedIndex = 0
				else
					self.movedOldMargin = child:getMarginBottom()
					self.movedIndex = 1
				end

				function self.setMovedChildMargin(v)
					updateDragHoverMargin(self, child, v)
				end

				self.movedWidget = child

				self.setMovedChildMargin(self:getHeight())

				if self:getParent() and self:getParent():getClassName() == "UIMiniWindowContainer" then
					self:getParent():reloadChildReorderMargin()
				end

				break
			end
		end

		::label_24_0::
	end

	if not overAnyWidget and not self:isFromMainPanel() then
		if recursivePanel ~= nil then
			local hoverParent

			if self.hoverBlackPanel ~= nil then
				hoverParent = self.hoverBlackPanel:getParent()

				self.hoverBlackPanel:destroy()

				self.hoverBlackPanel = nil
			end

			local highlight = false

			if self.blackShadow then
				highlight = recursivePanel ~= self.blackShadow:getParent()
			end

			self.hoverBlackPanel = createBlackPanelWidget(self:getHeight(), recursivePanel, -1, highlight)

			if self.blackShadow then
				self.blackShadow:setHeight(0)
			end

			if hoverParent ~= nil and hoverParent:getClassName() == "UIMiniWindowContainer" then
				hoverParent:reloadChildReorderMargin()
			end

			if hoverParent ~= nil and hoverParent ~= recursivePanel and recursivePanel:getClassName() == "UIMiniWindowContainer" then
				recursivePanel:reloadChildReorderMargin()
			end
		else
			local hoverParent

			if self.hoverBlackPanel ~= nil then
				hoverParent = self.hoverBlackPanel:getParent()

				self.hoverBlackPanel:destroy()

				self.hoverBlackPanel = nil
			end

			if self.blackShadow and self.blackShadow:getHeight() ~= self:getHeight() then
				self.blackShadow:setHeight(self:getHeight())

				if hoverParent ~= nil and hoverParent ~= self.blackShadow:getParent() and self.blackShadow:getParent():getClassName() == "UIMiniWindowContainer" then
					self.blackShadow:getParent():reloadChildReorderMargin()
				end
			end

			if hoverParent ~= nil and hoverParent:getClassName() == "UIMiniWindowContainer" then
				hoverParent:reloadChildReorderMargin()
			end
		end
	end

	if not overAnyWidget and self.movedWidget then
		self.setMovedChildMargin(self.movedOldMargin or 0)

		if self:getParent() and self:getParent():getClassName() == "UIMiniWindowContainer" then
			self:getParent():reloadChildReorderMargin()
		end

		self.movedWidget = nil
	end

	if removeHighlight then
		modules.game_interface.highlightPanel(nil)
	end

	return UIWindow.onDragMove(self, mousePos, mouseMoved)
end

function UIMiniWindow:onMousePress(mousePos)
	local parent = self:getParent()

	if not parent then
		return false
	end

	if self.mousePosOverDiffTopLeft == nil then
		self.mousePosOverDiffTopLeft = {
			x = mousePos.x - self:getPosition().x,
			y = mousePos.y - self:getPosition().y
		}
	end

	if parent:getClassName() ~= "UIMiniWindowContainer" then
		self:raise()

		return true
	end
end

function UIMiniWindow:onFocusChange(focused)
	self.movedFromParent = nil
	self.movedFromParentIndex = nil
	self.movedFromParentOrder = nil

	if not focused then
		return
	end

	local parent = self:getParent()

	if parent and parent:getClassName() ~= "UIMiniWindowContainer" then
		self:raise()
	end
end

function UIMiniWindow:onHeightChange(height)
	if not self:isOn() then
		self:setSettings({
			height = height
		})
	end

	self:fitOnParent()
end

function UIMiniWindow:getSettings(name)
	if not self.save then
		return nil
	end

	local settings = g_settings.getNode("MiniWindows")

	if settings then
		local selfSettings = settings[self:getId()]

		if selfSettings then
			return selfSettings[name]
		end
	end

	return nil
end

function UIMiniWindow:setSettings(data)
	if not self.save then
		return
	end

	local settings = g_settings.getNode("MiniWindows")

	settings = settings or {}

	local id = self:getId()

	if not settings[id] then
		settings[id] = {}
	end

	for key, value in pairs(data) do
		settings[id][key] = value
	end

	g_settings.setNode("MiniWindows", settings)
end

function UIMiniWindow:eraseSettings(data)
	if not self.save then
		return
	end

	local settings = g_settings.getNode("MiniWindows")

	settings = settings or {}

	local id = self:getId()

	if not settings[id] then
		settings[id] = {}
	end

	for key, value in pairs(data) do
		settings[id][key] = nil
	end

	g_settings.setNode("MiniWindows", settings)
end

function UIMiniWindow:clearSettings()
	if not self.save then
		return
	end

	local settings = g_settings.getNode("MiniWindows")

	settings = settings or {}

	local id = self:getId()

	settings[id] = {}

	g_settings.setNode("MiniWindows", settings)
end

function UIMiniWindow:saveParent(parent)
	local parent = self:getParent()

	if parent then
		if parent:getClassName() == "UIMiniWindowContainer" then
			parent:saveChildren()
		else
			self:saveParentPosition(parent:getId(), self:getPosition())
		end
	end
end

function UIMiniWindow:saveParentPosition(parentId, position)
	local selfSettings = {}

	selfSettings.parentId = parentId
	selfSettings.position = pointtostring(position)

	self:setSettings(selfSettings)
end

function UIMiniWindow:saveParentIndex(parentId, index)
	local selfSettings = {}

	selfSettings.parentId = parentId
	selfSettings.parentIndex = index
	selfSettings.visible = self:isVisible()

	if parentId == nil or index == nil then
		self:eraseSettings(selfSettings)
	else
		self:setSettings(selfSettings)
	end
end

function UIMiniWindow:disableResize()
	self:getChildById("bottomResizeBorder"):disable()

	local triangle = self:getTriangle()

	if triangle then
		triangle:disable()
	end
end

function UIMiniWindow:enableResize()
	self:getChildById("bottomResizeBorder"):enable()

	local triangle = self:getTriangle()

	if triangle then
		triangle:enable()
	end
end

function UIMiniWindow:fitOnParent()
	local parent = self:getParent()

	if self:isVisible() and parent and parent:getClassName() == "UIMiniWindowContainer" then
		parent:fitAll(self)
	end
end

function UIMiniWindow:setParent(parent, dontsave)
	UIWidget.setParent(self, parent)

	if not dontsave then
		self:saveParent(parent)
	end

	self:fitOnParent()
end

function UIMiniWindow:setHeight(height)
	UIWidget.setHeight(self, height)

	if self:getParent() and self:getParent():getClassName() == "UIMiniWindowContainer" then
		self:getParent():reloadChildReorderMargin()
	end

	signalcall(self.onHeightChange, self, height)
end

function UIMiniWindow:setContentHeight(height)
	local contentsPanel = self:getChildById("contentsPanel")
	local minHeight = contentsPanel:getMarginTop() + contentsPanel:getMarginBottom() + contentsPanel:getPaddingTop() + contentsPanel:getPaddingBottom()
	local resizeBorder = self:getChildById("bottomResizeBorder")

	resizeBorder:setParentSize(minHeight + height)
end

function UIMiniWindow:setContentMinimumHeight(height)
	local contentsPanel = self:getChildById("contentsPanel")
	local minHeight = 0

	if not self.ignoreExpandingHeight then
		minHeight = contentsPanel:getMarginTop() + contentsPanel:getMarginBottom() + contentsPanel:getPaddingTop() + contentsPanel:getPaddingBottom()
	end

	local resizeBorder = self:getChildById("bottomResizeBorder")

	resizeBorder:setMinimum(minHeight + height)
end

function UIMiniWindow:setContentMaximumHeight(height)
	local contentsPanel = self:getChildById("contentsPanel")
	local minHeight = 0

	if not self.ignoreExpandingHeight then
		minHeight = contentsPanel:getMarginTop() + contentsPanel:getMarginBottom() + contentsPanel:getPaddingTop() + contentsPanel:getPaddingBottom()
	end

	local resizeBorder = self:getChildById("bottomResizeBorder")

	resizeBorder:setMaximum(minHeight + height)
end

function UIMiniWindow:getMinimumHeight()
	if self.minimumheight then
		return self.minimumheight
	end

	local resizeBorder = self:getChildById("bottomResizeBorder")

	return resizeBorder:getMinimum()
end

function UIMiniWindow:getMaximumHeight()
	if self.maximumHeight then
		return self.maximumHeight
	end

	local resizeBorder = self:getChildById("bottomResizeBorder")

	return resizeBorder:getMaximum()
end

function UIMiniWindow:isResizeable()
	local resizeBorder = self:getChildById("bottomResizeBorder")

	return resizeBorder:isExplicitlyVisible() and resizeBorder:isEnabled()
end

function UIMiniWindow:getTriangle()
	return self:getChildById("bottomResizeBorderTriangle")
end
