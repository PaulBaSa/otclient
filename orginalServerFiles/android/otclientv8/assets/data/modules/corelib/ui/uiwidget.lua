-- chunkname: @/modules/corelib/ui/uiwidget.lua

function UIWidget:setMargin(...)
	local params = {
		...
	}

	if #params == 1 then
		self:setMarginTop(params[1])
		self:setMarginRight(params[1])
		self:setMarginBottom(params[1])
		self:setMarginLeft(params[1])
	elseif #params == 2 then
		self:setMarginTop(params[1])
		self:setMarginRight(params[2])
		self:setMarginBottom(params[1])
		self:setMarginLeft(params[2])
	elseif #params == 4 then
		self:setMarginTop(params[1])
		self:setMarginRight(params[2])
		self:setMarginBottom(params[3])
		self:setMarginLeft(params[4])
	end
end

function UIWidget:onGeometryChangeByReorder(oldRect, newRect)
	if g_keyboard.isShiftPressed() then
		return
	end

	local parent = self:getParent()

	if oldRect.height == 0 or newRect.height == 0 or oldRect.height == newRect.height or parent == nil or not parent:isChildReOrderToggle() or not self:isVisible() or parent:isMainPanel() or self.isBlankMainPanel then
		return
	end

	if self.minimizedHeight ~= nil and newRect.height == self.minimizedHeight then
		return
	end

	local function getNextVisibleChild(widget, anchor, position, fromBottom)
		if position > anchor:getChildCount() then
			return nil
		end

		if position == -1 then
			local child

			while true do
				child = anchor:getChildByIndex(position)

				if not child or child:getId() == widget:getId() then
					child = nil

					break
				end

				if child:isVisible() then
					break
				end

				position = anchor:getChildIndex(child)

				if position == -1 then
					child = nil

					break
				end

				if fromBottom then
					position = position + 1
				else
					position = position - 1
				end
			end

			return child
		end

		if fromBottom then
			for i = position, anchor:getChildCount() do
				local child = anchor:getChildByIndex(i)

				if child and child:getId() ~= widget:getId() and child:isVisible() then
					return child
				end
			end
		else
			for i = position, 1, -1 do
				local child = anchor:getChildByIndex(i)

				if child and child:getId() ~= widget:getId() and child:isVisible() then
					return child
				end
			end
		end
	end

	if oldRect.height < newRect.height then
		local fits = parent:fits(self, newRect.height, 0)

		if fits > 0 then
			return
		end

		local index = parent:getChildIndex(self)

		if index == parent:getChildCount() then
			return
		end

		local nextWidget = getNextVisibleChild(self, parent, -1, false)

		if nextWidget == nil then
			return
		end

		local nextIndex = parent:getChildIndex(nextWidget)

		if index == nextIndex then
			return
		end

		local function increase(current, widget, diff, anchor)
			local minHeight = widget:getMinimumHeight()

			if minHeight <= 0 then
				minHeight = 24
			end

			local nextHeight = widget:getHeight() - diff

			if nextHeight == minHeight then
				return diff
			end

			if nextHeight < minHeight then
				nextHeight = minHeight
				diff = diff - (widget:getHeight() - nextHeight)

				local rect = current:getRect()

				minHeight = current:getMinimumHeight()

				if minHeight <= 0 then
					minHeight = 24
				end

				rect.height = math.min(newRect.height, anchor:fits(current, minHeight, 0))

				current:setRect(rect, true)

				if current:getParent() and current:getParent():getClassName() == "UIMiniWindowContainer" then
					current:getParent():reloadChildReorderMargin()
				end
			else
				diff = 0
			end

			local rect = widget:getRect()

			rect.height = nextHeight

			widget:setRect(rect, true)

			if widget:getParent() and widget:getParent():getClassName() == "UIMiniWindowContainer" then
				widget:getParent():reloadChildReorderMargin()
			end

			return diff
		end

		local heightToRemoveFromNextWindow = newRect.height - oldRect.height
		local left = increase(self, nextWidget, heightToRemoveFromNextWindow, parent)

		while left > 0 do
			nextIndex = nextIndex - 1
			nextWidget = getNextVisibleChild(self, parent, nextIndex)

			if nextWidget == nil or nextIndex == index then
				local rect = self:getRect()

				rect.height = newRect.height - left

				self:setRect(rect, true)

				if self:getParent() and self:getParent():getClassName() == "UIMiniWindowContainer" then
					self:getParent():reloadChildReorderMargin()
				end

				break
			end

			left = increase(self, nextWidget, left, parent)
		end
	else
		local index = parent:getChildIndex(self)

		if index == parent:getChildCount() then
			return
		end

		local nextWidget = getNextVisibleChild(self, parent, index, true)

		if nextWidget == nil then
			return
		end

		local nextIndex = parent:getChildIndex(nextWidget)

		if index == nextIndex then
			return
		end

		local function decrease(current, widget, diff, anchor, useMax)
			local max

			if useMax then
				max = widget:getMaximumHeight()
			else
				max = widget:getOriginHeight()
			end

			local maxHeight = math.max(24, max)
			local nextHeight = widget:getHeight() + diff

			if maxHeight < nextHeight then
				return diff
			end

			if maxHeight < nextHeight then
				local fits = anchor:fits(current, math.max(24, newRect.height), 0)

				if fits > 0 then
					return diff
				end

				nextHeight = maxHeight

				local recursive = diff - (nextHeight - maxHeight)

				diff = diff - recursive

				local rect = current:getRect()

				rect.height = newRect.height + recursive

				current:setRect(rect, true)

				if current:getParent() and current:getParent():getClassName() == "UIMiniWindowContainer" then
					current:getParent():reloadChildReorderMargin()
				end
			else
				diff = 0
			end

			local rect = widget:getRect()

			rect.height = nextHeight

			widget:setRect(rect, true)

			if widget:getParent() and widget:getParent():getClassName() == "UIMiniWindowContainer" then
				widget:getParent():reloadChildReorderMargin()
			end

			return diff
		end

		local recursive = false
		local oldIndex = nextIndex
		local heightToAddOnNextWindow = oldRect.height - newRect.height

		::label_2_0::

		local left = decrease(self, nextWidget, heightToAddOnNextWindow, parent, recursive)

		while left > 0 do
			nextIndex = nextIndex + 1
			nextWidget = getNextVisibleChild(self, parent, nextIndex)

			if nextWidget == nil or nextIndex == index then
				break
			end

			left = decrease(self, nextWidget, left, parent, recursive)
		end

		if not recursive and left > 0 then
			recursive = true
			nextIndex = oldIndex
			nextWidget = getNextVisibleChild(self, parent, nextIndex)
			heightToAddOnNextWindow = left

			goto label_2_0
		end
	end
end

function UIWidget:getWidgetsWithScheduler()
    local containers = {}

    for _, child in pairs(self:getChildren()) do
        if child.scheduledWidgets ~= nil and type(child.loadScheduledInserts) == "function" then
            table.insert(containers, child)
        elseif type(child.getWidgetsWithScheduler) == "function" then
            local childContainers = child:getWidgetsWithScheduler()
            table.insertArray(containers, childContainers)
        end
    end

    return containers
end


function UIWidget:removeWidgetFromScheduler(widget)
	for _, child in pairs(self:getChildren()) do
		if child.scheduledWidgets ~= nil then
			table.removevalue(child.scheduledWidgets, widget)
		else
			child:removeWidgetFromScheduler(widget)
		end
	end
end
