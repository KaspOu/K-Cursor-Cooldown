--[[
	Most of the functionality was taken from Circle Cast 2. Credits go to Greg Flynn (Nuckin)
	Rewritten to use a single UICooldown frame for radial fill, as suggested,
	leveraging WoW's built-in CooldownFrameTemplate for a more optimized approach.
]]

local addon = LibStub("AceAddon-3.0"):GetAddon("CC")
addon.donut = {}

local rad = math.rad -- Only math.rad is needed for handle rotation

function addon.donut:New(direction, radius, thickness, color, bgColor, frame, hasHand)
	assert(type(direction) == "boolean", "direction must be a boolean")
	assert(type(radius) == "number" and radius > 0, "radius must be a positive number")
	assert(type(thickness) == "number" and thickness > 0, "thickness must be a positive number")
	assert(type(color) == "table" and type(color.r) == "number" and type(color.g) == "number" and type(color.b) == "number" and type(color.a) == "number", "color must be a table with r, g, b, a number components")
	assert(type(bgColor) == "table" and type(bgColor.r) == "number" and type(bgColor.g) == "number" and type(bgColor.b) == "number" and type(bgColor.a) == "number", "bgColor must be a table with r, g, b, a number components")
	assert(frame == nil or type(frame) == "table", "frame must be nil or a table (UI frame), found:"..type(frame))
	assert(hasHand == nil or type(hasHand) == "boolean", "hasHand must be nil or a boolean, found:"..type(hasHand))
	local donut = {}
	donut.radius = radius
	donut.thickness = thickness
	donut.direction = direction
	donut.hasHand = hasHand

	----------------------------------------------Functions--------------------------------------------------
	function donut:AttachTo(anchor)
		self.bgFrame:SetParent(anchor)
		self.bgFrame:SetAllPoints(anchor)
	end

	function donut:SetRadius(radius)
		self.radius = radius
		local size = radius * 2
		self.backgroundTexture:SetSize(size, size)
		self.cooldown:SetSize(size, size)
		-- The inner background creates the "hole" of the donut
		self.innerBackgroundTexture:SetSize((radius - self.thickness) * 2, (radius - self.thickness) * 2)
		if self.handle then
			self.handle:SetHeight(radius)
		end
	end

	function donut:SetThickness(thickness)
		self.thickness = thickness
		-- Adjust the size of the inner background to change the donut's thickness
		self.innerBackgroundTexture:SetSize((self.radius - thickness) * 2, (self.radius - thickness) * 2)
	end

	function donut:SetDirection(direction)
		self.direction = direction
		-- If direction is true, the circle should empty (reverse fill)
		self.cooldown:SetReverse(direction)
	end

	function donut:SetBarColor(color)
		-- Set the color of the radial swipe fill. The last 'color.a' ensures the swipe is opaque.
		self.cooldown:SetSwipeColor(color.r, color.g, color.b, color.a, color.a)
		if self.handle then
			self.handle:SetVertexColor(color.r, color.g, color.b, color.a)
		end
	end

	function donut:SetBackgroundColor(color)
		-- Set the color of the static background and the inner hole
		self.backgroundTexture:SetVertexColor(color.r, color.g, color.b, color.a)
		self.innerBackgroundTexture:SetVertexColor(color.r, color.g, color.b, color.a)
	end

	-- New primary method for setting cooldown progress using standard WoW API
	-- `start` and `duration` are standard Cooldown frame parameters.
	-- `enable` can be used to explicitly show/hide the cooldown.
	function donut:SetCooldown(start, duration, enable, endExpected)
		local g = GetTime()*1000
		if enable then
			_, _, _, start, endExpected, _, _, _, _ = UnitCastingInfo("player")
			if (type(start) ~= "nil") then
				self.barFrame:Show()
				self.barFrame:SetMinMaxValues(start, endExpected)
				self.barFrame:SetValue(g)
			end
			return
		end
		if enable == false or duration == 0 then
			self.cooldown:Hide()
			if self.handle then self.handle:Hide() end
		else
			self.cooldown:Show()
			if self.handle then self.handle:Show() end
			self.barFrame:Show()
			self.cooldown:SetCooldown(start, duration)

			-- Update handle rotation based on current progress
			local elapsed = GetTime() - start
			local progress = math.min(1, math.max(0, elapsed / duration))
			local degree = progress * 360
			self.barFrame:SetMinMaxValues(0, duration)
			self.barFrame:SetValue(elapsed)

			if self.handle then
				-- Rotate around the bottom center of the handle texture (0.5, 0)
				local rotationVector = { x=.5, y = 0}
				if self.direction then -- If direction is true, it's depleting, so rotate inversely
					self.handle:SetRotation(-rad(degree), rotationVector)
				else
					self.handle:SetRotation(rad(degree), rotationVector)
				end
			end
		end
	end

	-- Retain SetAngle for compatibility, adapting it to the new system.
	-- This will simulate a cooldown based on a degree (0-360).
	function donut:SetAngle(degree, endTime)
		-- degree = math.max(0, math.min(degree, 360))
		-- local progress = degree / 360
		-- local simulatedDuration = 1 -- Use a fixed duration for angle-based setting
		-- local simulatedStart = GetTime() - (progress * simulatedDuration)
		-- self:SetCooldown(simulatedStart, simulatedDuration, true, endTime)
	end

	function donut:Show()
		self.bgFrame:Show()
		self.barFrame:Show()
		self.backgroundTexture:Show()
		self.cooldown:Show()
		self.innerBackgroundTexture:Show()
		if self.handle then self.handle:Show() end
	end

	function donut:Hide()
		self.bgFrame:Hide()
		self.barFrame:Hide()
		self:SetCooldown(0, 0, false) -- Reset and hide cooldown
	end
	-----------------------------------------------------------------------------------------------------------

	----------------------------------------------Frames----------------------------------------------------
	local bgFrame = frame or CreateFrame("Frame")
	donut.bgFrame = bgFrame
	local donutFrame = CreateFrame("Frame") -- Main frame for all donut elements
	donut.frame = donutFrame
	donutFrame:SetParent(bgFrame)
	donutFrame:SetAllPoints(bgFrame)

	local barFrame = CreateFrame("StatusBar", nil, donutFrame)

	donut.barFrame = barFrame
	if (hasHand) then
		-- Mixin(barFrame, SmoothStatusBarMixin)
		barFrame.attachedToPlayerFrame = false
		-- Mixin(barFrame, PlayerCastingBarMixin)

		barFrame:SetFrameLevel(3)
		-- barFrame:SetMinMaxValues(0, 100)
		-- barFrame:SetValue(100)
		barFrame:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar") -- Set a default texture to make the status bar visible
		barFrame:GetStatusBarTexture():SetVertexColor(0, 1, 0, .8)
		barFrame:SetHeight(10)
		barFrame:SetPoint("BOTTOM", donutFrame, "BOTTOM", 0, 5)
		barFrame:SetPoint("LEFT", donutFrame, "LEFT", 5, 0)
		barFrame:SetPoint("RIGHT", donutFrame, "RIGHT", -5, 0)
			-- local castingBarTemplateFrame = CreateFrame("Frame", nil, fra, "CastingBarFrameTemplate")
			-- castingBarTemplateFrame.attachedToPlayerFrame = false
			-- castingBarTemplateFrame:SetPoint("BOTTOM", donutFrame, "BOTTOM", 0, 5)
			-- castingBarTemplateFrame:SetPoint("LEFT", donutFrame, "LEFT", 5, 0)
			-- castingBarTemplateFrame:SetPoint("RIGHT", donutFrame, "RIGHT", -5, 0).
			-- -- barFrame = castingBarTemplateFrame.StatusBar

			-- -- Hide the default elements of the CastingBarFrameTemplate (text, timer, spark, icon)
			-- -- to prevent visual conflicts, as the main Cast module or other parts of the donut
			-- -- might handle these visuals separately.
			-- if castingBarTemplateFrame.Text then castingBarTemplateFrame.Text:Hide() end
			-- if castingBarTemplateFrame.Timer then castingBarTemplateFrame.Timer:Hide() end
			-- if castingBarTemplateFrame.Spark then castingBarTemplateFrame.Spark:Hide() end
			-- if castingBarTemplateFrame.Icon then castingBarTemplateFrame.Icon:Hide() end
	end

	-- barFrame:SetMinMaxValues(min, max)
	-- barFrame:SetValue(healthLost)
	-- barFrame:SetMinMaxSmoothedValue(min, max)
	-- barFrame:SetSmoothedValue(healthLost)
	-- applyBarTexture(barFrame, _G[ns.OPTIONS_NAME].Bar_Texture, DEFAULT_RAIDHEALTHBAR_TEXTURE)

	-----------------------------------------------------------------------------------------------------------

	----------------------------------------------Background----------------------------------------------
	-- Full circle background, representing the full extent of the donut
	donut.backgroundTexture = donutFrame:CreateTexture(nil, 'BACKGROUND')
	donut.backgroundTexture:SetTexture(addon.addonFolder.."\\Textures\\ping4.PNG") -- A solid circular texture
	donut.backgroundTexture:SetAllPoints(donutFrame)
	donut.backgroundTexture:SetVertexColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
	-----------------------------------------------------------------------------------------------------------

	----------------------------------------------Cooldown (Radial Fill)-----------------------------------
	-- This is the core element for the radial fill effect
	donut.cooldown = CreateFrame("Cooldown", nil, donutFrame, "CooldownFrameTemplate")
	donut.cooldown:SetAllPoints(donutFrame)
	donut.cooldown:SetDrawBling(false)
	donut.cooldown:SetDrawEdge(false)
	-- donut.cooldown:SetEdgeTexture(addon.addonFolder.."\\Textures\\ping4.PNG", color.r, color.g, color.b, color.a)
	donut.cooldown:SetUseCircularEdge(true)
	donut.cooldown:SetDrawSwipe(true) -- Enable the radial fill animation
	donut.cooldown:SetSwipeTexture(addon.addonFolder.."\\Textures\\ping4.PNG", color.r, color.g, color.b, color.a)

	donut.cooldown:SetHideCountdownNumbers(false)
	donut.cooldown:SetReverse(false)


	----------------------------------------------Inner Background (Donut Hole)----------------------------
	-- This texture is placed on top of the cooldown and background to create the transparent center,
	-- effectively making the full circle cooldown appear as a donut.
	donut.innerBackgroundTexture = donutFrame:CreateTexture(nil, 'OVERLAY')
	-- donut.innerBackgroundTexture:SetTexture(addon.addonFolder.."\\Textures\\ping4.PNG") -- A solid circular texture, used as the base for the ring color
	-- -- To create a "donut hole" effect, a mask texture is applied to shape the solid circular texture into a ring.
	-- -- This assumes a 'RingMask.PNG' texture exists, which is transparent in the center and opaque on the outside.
	-- -- donut.innerBackgroundTexture:SetMask(addon.addonFolder.."\\Textures\\ping4.PNG")
	-- donut.innerBackgroundTexture:SetPoint("CENTER", donutFrame, "CENTER")
	-- donut.innerBackgroundTexture:SetVertexColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
	-----------------------------------------------------------------------------------------------------------

	----------------------------------------------Hand-----------------------------------------------------
	-- Hand part: thickness pixels wide, radius pixels long, rotates like a clock hand.
	if (donut.hasHand) then
		donut.handle = donutFrame:CreateTexture(nil, 'OVERLAY')
		donut.handle:SetTexture(addon.addonFolder.."\\Textures\\2d") -- Assuming this is a line texture
		donut.handle:SetPoint("BOTTOM", donutFrame, "CENTER")
		donut.handle:SetWidth(3) -- Retain original width
		donut.handle:SetVertexColor(color.r, color.g, color.b, color.a)
	end
	-----------------------------------------------------------------------------------------------------------

	-- Initial setup calls to apply properties and hide the cooldown initially
	donut:SetThickness(thickness)
	donut:SetDirection(direction)
	donut:SetRadius(radius)
	donut:SetBarColor(color)
	donut:SetBackgroundColor(bgColor)
	donut:SetCooldown(0, 0, false) -- Initialize as hidden/empty

	return donut
end
