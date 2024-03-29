local Task = Class{
	init = function(self, pos, text, scene)
		self.pos = pos
		self.text = text
		self.loveText = love.graphics.newText(love.graphics.getFont(), text)
		self.above = nil
		self.below = nil
		-- Flags/states, multiple can be set at the same time
		self.hovered = false
		self.edited = false
		self.done = false -- Strikethrough

		self:updateStyle() -- Get padding from style before making bounds
		self.scene = scene or Scene or error('Scene must be provided or made global')
		self.bounds = self.scene:newRectangle(
			self.pos.x - self.PlanPadding/2,
			self.pos.y - self.PlanPadding/2,
			self.loveText:getWidth() + self.PlanPadding,
			self.loveText:getHeight() + self.PlanPadding
		)
		self.bounds.parent = self -- Set parent ref for collision callbacks
	end
}


function Task:draw()
	for i=0,1 do
		-- Draw background then border
		love.graphics.setColor(i==0 and
			self.PlanBackgroundColor or self.PlanBorderColor)
		love.graphics.rectangle(i==0 and 'fill' or 'line',
			self:getBounds())
	end
	
	love.graphics.setColor(self.PlanTextColor)
	love.graphics.draw(self.loveText, self.pos.x, self.pos.y)

	if self.done then
		local x,y,w,h = self:getBounds()
		love.graphics.line(x, y+h/2, x+w, y+h/2)
	end
end

function Task:update(dt)
end

-- Style updating functions
function Task:setHovered(b) self.hovered=b; self:updateStyle(); return self end
function Task:setDone(b) self.done=b; self:updateStyle(); return self end
function Task:setEdited(b) self.edited=b; self:updateStyle(); return self end
function Task:updateStyle()
	-- Restore default
	local default = Theme.Plan.Default or error('No default theme')
	local modified =
		self.edited and 'Edited' or
		self.hovered and 'Hovered' or
		self.done and 'Done'
	for k,v in pairs(default) do
		self[k] = Theme.Plan[modified] and Theme.Plan[modified][k] or v -- Use modified val if exists
	end
end

-- Text updating functions
function Task:keypressed(char, ctrl)
	if char == 'backspace' then
		if ctrl then
			local rev = string.reverse(self.text)
			local i = string.find(rev, ' ')
			local to = i and string.len(self.text)-i or 0
			self.text = string.sub(self.text, 1, to)
		else
			self.text = string.sub(self.text, 1, #self.text-1)
		end
	else
		self.text = self.text .. char
	end
	self.loveText:set(self.text)
	self:updateDimensions()
end

-- Relationship and snapping functions
function Task:snapToAbove(other)
	other.below = self
	self.above = other

	local x,y,w,h = other:getBounds()
	self:moveTo(x, y+h)

	if self.below then
		self.below:snapToAbove(self)
	end
end
function Task:unsnapToAbove()
	self.above.below = nil
	self.above = nil
end
function Task:getLowest()
	if not self.below then
		return self
	end

	local next = self.below
	while next.below do -- Keep going until you can't :(
		next = next.below
	end
	return next
end

-- Movement and bounds functions
function Task:getBounds()
	local b = self.bounds
	return b.x,b.y,b.w,b.h
end
function Task:move(x,y)
	-- Reposition and/or resize depending on what changed
	self.pos.x = self.pos.x + x
	self.pos.y = self.pos.y + y
	self.bounds:move(x and x or 0, y and y or 0)

	if self.below then
		self.below:move(x,y)
	end
end
function Task:moveTo(x,y)
	self.pos.x = x + self.PlanPadding/2
	self.pos.y = y + self.PlanPadding/2
	self.bounds:moveTo(x, y)
end
function Task:updateDimensions()
	-- Resize on text change event
	self.bounds:updateDimensions(
		self.loveText:getWidth() + self.PlanPadding,
		self.loveText:getHeight() + self.PlanPadding)
end

-- Representation functions
function Task:save(t)
	local children = t or {}
	if self.below then -- Save children
		table.insert(children, self.below:save(children))
	end
	return {
		x = self.pos.x,
		y = self.pos.y,
		text = self.text,
		done = self.done,
		children = (not t) and children or nil -- Save all children
	}
end

return Task