--[[
	Most of the functionality was taken from Circle Cast 2. Credits go to Greg Flynn (Nuckin)
]]

local addon = LibStub("AceAddon-3.0"):GetAddon("CC")
addon.donut = {}

local rad, sin, cos = math.rad, math.sin, math.cos

function addon.donut:New(direction, radius, thickness, color, bgColor, frame)
	local donut = {}
	----------------------------------------------Function--------------------------------------------------
	function donut:AttachTo(anchor)
		self.bgFrame:SetParent(anchor)
		self.bgFrame:SetAllPoints(anchor)
	end

	function donut:SetRadius(radius)
		self.radius = radius
		for _,v in ipairs(self.background) do
			v:SetWidth(radius)
			v:SetHeight(radius)
		end

		local s1, s2, s3 = self.segment1, self.segment2, self.segment3
		s1:SetWidth(radius)
		s1:SetHeight(radius)
		s2:SetWidth(radius)
		s2:SetHeight(radius)
		s3:SetWidth(radius)
		s3:SetHeight(radius)
	end

	function donut:SetThickness(thickness)
		self.thickness = thickness
		for _,v in ipairs(self.background) do
			v:SetTexture(addon.addonFolder.."\\Textures\\segment_" .. thickness)
		end

		self.segment1:SetTexture(addon.addonFolder.."\\Textures\\segment_" .. thickness)
		self.segment2:SetTexture(addon.addonFolder.."\\Textures\\segment_" .. thickness)
		self.segment3:SetTexture(addon.addonFolder.."\\Textures\\segment_" .. thickness)

		self.red:SetTexture(addon.addonFolder.."\\Textures\\segment_" .. thickness)
		self.blue:SetTexture(addon.addonFolder.."\\Textures\\segment_" .. thickness)
	end

	function donut:SetDirection(direction)
		self.direction = direction
		local texture
		local donutFrame = self.frame
		-- 1. Quarter
		texture = self.segment1
		if direction then
			texture:SetPoint("BOTTOMLEFT", donutFrame, "CENTER")
		else
			texture:SetPoint("BOTTOMRIGHT", donutFrame, "CENTER")
			texture:SetTexCoord(1, 0, 1, 1, 0, 0, 0, 1);
		end
		-- 2. Quarter
		texture = self.segment2
		if direction then
			texture:SetPoint("TOPLEFT", donutFrame, "CENTER")
			texture:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0);
		else
			texture:SetPoint("TOPRIGHT", donutFrame, "CENTER")
			texture:SetTexCoord(1, 1, 1, 0, 0, 1, 0, 0);
		end
		-- 3. Quarter
		texture = self.segment3
		if direction then
			texture:SetPoint("TOPRIGHT", donutFrame, "CENTER")
			texture:SetTexCoord(1, 1, 1, 0, 0, 1, 0, 0);
		else
			texture:SetPoint("TOPLEFT", donutFrame, "CENTER")
			texture:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0);
		end
	end

	function donut:SetBarColor(color)
		self.red:SetVertexColor(color.r, color.g, color.b, color.a)
		self.blue:SetVertexColor(color.r, color.g, color.b, color.a)
		self.slice:SetVertexColor(color.r, color.g, color.b, color.a)
		self.segment1:SetVertexColor(color.r, color.g, color.b, color.a)
		self.segment2:SetVertexColor(color.r, color.g, color.b, color.a)
		self.segment3:SetVertexColor(color.r, color.g, color.b, color.a)
	end

	function donut:SetBackgroundColor(color)
		for _,v in ipairs(self.background) do
			v:SetVertexColor(color.r, color.g, color.b, color.a)
		end
	end

	function donut:SetAngle(degree)
		local OR = 256
		local IR = OR - self.thickness
		local TS = 256

		if degree < 0 then
			degree = 0
		elseif degree > 360 then
			degree = 360
		end

		local quarter = ceil(degree / 90)
		degree = degree - (quarter - 1) * 90
		local radian = rad(degree)
		local Ix = math.sin(radian) * IR;
		local Iy = TS - math.cos(radian) * IR;
		local Ox = math.sin(radian) * OR;
		local Oy = TS - math.cos(radian) * OR;
		local IxCoord = Ix / TS;
		local IyCoord = Iy / TS;
		local OxCoord = Ox / TS;
		local OyCoord = Oy / TS;

		local radius = self.radius
		Ix = IxCoord * radius
		Iy = IyCoord * radius
		Ox = OxCoord * radius
		Oy = OyCoord * radius

		local red, blue, slice, s1, s2, s3, frame = self.red, self.blue, self.slice, self.segment1, self.segment2, self.segment3, self.frame

		red:ClearAllPoints()
		blue:ClearAllPoints()
		slice:ClearAllPoints()

		if quarter == 1 then
			s1:Hide();
			s2:Hide();
			s3:Hide();

			if self.direction then
				red:SetTexCoord(0, IxCoord, 0, IyCoord);
				red:SetPoint("TOPLEFT", frame, "CENTER", 0, radius);
				red:SetWidth(Ix);
				red:SetHeight(Iy);

				blue:SetTexCoord(IxCoord, OxCoord, 0, OyCoord);
				blue:SetPoint("TOPLEFT", frame, "CENTER", Ix, radius);
				blue:SetWidth(Ox - Ix);
				blue:SetHeight(Oy);

				slice:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1);
				slice:SetPoint("TOPLEFT", frame, "CENTER", Ix, radius - Oy);
				slice:SetWidth(Ox - Ix);
				slice:SetHeight(Iy - Oy);
			else
				red:SetTexCoord(IxCoord, 0, IxCoord, IyCoord, 0, 0, 0, IyCoord);
				red:SetPoint("TOPRIGHT", frame, "CENTER", 0, radius);
				red:SetWidth(Ix);
				red:SetHeight(Iy);

				blue:SetTexCoord(OxCoord, 0, OxCoord, OyCoord, IxCoord, 0, IxCoord, OyCoord);
				blue:SetPoint("TOPRIGHT", frame, "CENTER", -Ix, radius);
				blue:SetWidth(Ox - Ix);
				blue:SetHeight(Oy);

				slice:SetTexCoord(1, 0, 1, 1, 0, 0, 0, 1);
				slice:SetPoint("TOPRIGHT", frame, "CENTER", -Ix, radius - Oy);
				slice:SetWidth(Ox - Ix);
				slice:SetHeight(Iy - Oy);
			end
		elseif quarter == 2 then
			s1:Show();
			s2:Hide();
			s3:Hide();

			if self.direction then
				red:SetTexCoord(0, IyCoord, IxCoord, IyCoord, 0, 0, IxCoord, 0);
				red:SetPoint("TOPRIGHT", frame, "CENTER", radius, 0);
				red:SetWidth(Iy);
				red:SetHeight(Ix);

				blue:SetTexCoord(IxCoord, OyCoord, OxCoord, OyCoord, IxCoord, 0, OxCoord, 0);
				blue:SetPoint("TOPRIGHT", frame, "CENTER", radius, -Ix);
				blue:SetWidth(Oy);
				blue:SetHeight(Ox - Ix);

				slice:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0);
				slice:SetPoint("TOPRIGHT", frame, "CENTER", radius - Oy, -Ix);
				slice:SetWidth(Iy - Oy);
				slice:SetHeight(Ox - Ix);
			else --l,t,r,t,l,b,r,b
				red:SetTexCoord(0, 0, IxCoord, 0, 0, IyCoord, IxCoord, IyCoord);
				red:SetPoint("TOPLEFT", frame, "CENTER", -radius, 0);
				red:SetWidth(Iy);
				red:SetHeight(Ix);

				blue:SetTexCoord(IxCoord, 0, OxCoord, 0, IxCoord, OyCoord, OxCoord, OyCoord);
				blue:SetPoint("TOPLEFT", frame, "CENTER", -radius, -Ix);
				blue:SetWidth(Oy);
				blue:SetHeight(Ox - Ix);

				slice:SetTexCoord(0, 0, 1, 0, 0, 1, 1, 1);
				slice:SetPoint("TOPLEFT", frame, "CENTER", -radius + Oy, -Ix);
				slice:SetWidth(Iy - Oy);
				slice:SetHeight(Ox - Ix);
			end
		elseif quarter == 3 then
			s1:Show();
			s2:Show();
			s3:Hide();

			if self.direction then
				red:SetTexCoord(IxCoord, IyCoord, IxCoord, 0, 0, IyCoord, 0, 0);
				red:SetPoint("BOTTOMRIGHT", frame, "CENTER", 0, -radius);
				red:SetWidth(Ix);
				red:SetHeight(Iy);

				blue:SetTexCoord(OxCoord, OyCoord, OxCoord, 0, IxCoord, OyCoord, IxCoord, 0);
				blue:SetPoint("BOTTOMRIGHT", frame, "CENTER", -Ix, -radius);
				blue:SetWidth(Ox - Ix);
				blue:SetHeight(Oy);

				slice:SetTexCoord(1, 1, 1, 0, 0, 1, 0, 0);
				slice:SetPoint("BOTTOMRIGHT", frame, "CENTER", -Ix, -radius + Oy);
				slice:SetWidth(Ox - Ix);
				slice:SetHeight(Iy - Oy);
			else
				red:SetTexCoord(0, IyCoord, 0, 0, IxCoord, IyCoord, IxCoord, 0);
				red:SetPoint("BOTTOMLEFT", frame, "CENTER", 0, -radius);
				red:SetWidth(Ix);
				red:SetHeight(Iy);

				blue:SetTexCoord(IxCoord, OyCoord, IxCoord, 0, OxCoord, OyCoord, OxCoord, 0);
				blue:SetPoint("BOTTOMLEFT", frame, "CENTER", Ix, -radius);
				blue:SetWidth(Ox - Ix);
				blue:SetHeight(Oy);

				slice:SetTexCoord(0, 1, 0, 0, 1, 1, 1, 0);
				slice:SetPoint("BOTTOMLEFT", frame, "CENTER", Ix, -radius + Oy);
				slice:SetWidth(Ox - Ix);
				slice:SetHeight(Iy - Oy);
			end
		elseif quarter == 4 then
			s1:Show();
			s2:Show();
			s3:Show();

			if self.direction then
				red:SetTexCoord(IxCoord, 0, 0, 0, IxCoord, IyCoord, 0, IyCoord);
				red:SetPoint("BOTTOMLEFT", frame, "CENTER", -radius, 0);
				red:SetWidth(Iy);
				red:SetHeight(Ix);

				blue:SetTexCoord(OxCoord, 0, IxCoord, 0, OxCoord, OyCoord, IxCoord, OyCoord);
				blue:SetPoint("BOTTOMLEFT", frame, "CENTER", -radius, Ix);
				blue:SetWidth(Oy);
				blue:SetHeight(Ox - Ix);

				slice:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1);
				slice:SetPoint("BOTTOMLEFT", frame, "CENTER", -radius + Oy, Ix);
				slice:SetWidth(Iy - Oy);
				slice:SetHeight(Ox - Ix);
			else --r,b,l,b,r,t,l,t
				red:SetTexCoord(IxCoord, IyCoord, 0, IyCoord, IxCoord, 0, 0, 0);
				red:SetPoint("BOTTOMRIGHT", frame, "CENTER", radius, 0);
				red:SetWidth(Iy);
				red:SetHeight(Ix);

				blue:SetTexCoord(OxCoord, OyCoord, IxCoord, OyCoord, OxCoord, 0, IxCoord, 0);
				blue:SetPoint("BOTTOMRIGHT", frame, "CENTER", radius, Ix);
				blue:SetWidth(Oy);
				blue:SetHeight(Ox - Ix);

				slice:SetTexCoord(1, 1, 0, 1, 1, 0, 0, 0);
				slice:SetPoint("BOTTOMRIGHT", frame, "CENTER", radius - Oy, Ix);
				slice:SetWidth(Iy - Oy);
				slice:SetHeight(Ox - Ix);
			end
		end

		if degree == 90 or degree == 0 then
			slice:Hide()
		else
			slice:Show()
		end
	end

	function donut:Show()
		self.bgFrame:Show()
	end

	function donut:Hide()
		self.bgFrame:Hide()
		self:SetAngle(0)
	end
	-----------------------------------------------------------------------------------------------------------

	----------------------------------------------Frames----------------------------------------------------
	local bgFrame = frame or CreateFrame("Frame")
	donut.bgFrame = bgFrame
	local donutFrame = CreateFrame("Frame")
	donut.frame = donutFrame
	donutFrame:SetParent(bgFrame)
	donutFrame:SetAllPoints(bgFrame)
	-----------------------------------------------------------------------------------------------------------

	----------------------------------------------Background----------------------------------------------
	donut.background = {}
	-- 1. Quarter
	local texture = bgFrame:CreateTexture(nil, 'BACKGROUND')
	texture:SetPoint("BOTTOMLEFT", bgFrame, "CENTER")
	tinsert(donut.background, texture)
	-- 2. Quarter
	texture = bgFrame:CreateTexture(nil, 'BACKGROUND')
	texture:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0);
	texture:SetPoint("TOPLEFT", bgFrame, "CENTER")
	tinsert(donut.background, texture)
	-- 3. Quarter
	texture = bgFrame:CreateTexture(nil, 'BACKGROUND')
	texture:SetTexCoord(1, 1, 1, 0, 0, 1, 0, 0);
	texture:SetPoint("TOPRIGHT", bgFrame, "CENTER")
	tinsert(donut.background, texture)
	-- 4. Quarter
	texture = bgFrame:CreateTexture(nil, 'BACKGROUND')
	texture:SetTexCoord(1, 0, 1, 1, 0, 0, 0, 1);
	texture:SetPoint("BOTTOMRIGHT", bgFrame, "CENTER")
	tinsert(donut.background, texture)
	-----------------------------------------------------------------------------------------------------------

	----------------------------------------------Segments-------------------------------------------------
	-- 1. Quarter
	donut.segment1 = donutFrame:CreateTexture(nil, 'ARTWORK')
	-- 2. Quarter
	donut.segment2 = donutFrame:CreateTexture(nil, 'ARTWORK')
	-- 3. Quarter
	donut.segment3 = donutFrame:CreateTexture(nil, 'ARTWORK')
	-----------------------------------------------------------------------------------------------------------

	----------------------------------------------Parts------------------------------------------------------
	-- slice
	texture = donutFrame:CreateTexture(nil, 'ARTWORK')
	texture:SetTexture(addon.addonFolder.."\\Textures\\slice")
	donut.slice = texture
	-- Red part
	donut.red = donutFrame:CreateTexture(nil, 'ARTWORK')
	-- Blue part
	donut.blue = donutFrame:CreateTexture(nil, 'ARTWORK')
	-----------------------------------------------------------------------------------------------------------

	donut:SetThickness(thickness)
	donut:SetDirection(direction)
	donut:SetRadius(radius)
	donut:SetBarColor(color)
	donut:SetBackgroundColor(bgColor)
	donut:SetAngle(0)

	for _,v in ipairs(donut.background) do
		v:Show()
	end
	donut.slice:Show()
	donut.red:Show()
	donut.blue:Show()

	return donut
end
