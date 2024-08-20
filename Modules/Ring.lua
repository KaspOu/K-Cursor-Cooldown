local addon = LibStub("AceAddon-3.0"):GetAddon("CC")
local module = addon:NewModule("ring")
local L = LibStub("AceLocale-3.0"):GetLocale("CC")
local dbVersion = 1

local GetTime = GetTime

local ringFrame
local options
local showRequests

local defaults = {
	profile = {
		color = {r=0, g=1, b=0, a=0.5},
		texture = 165630, -- "Spells\\AURARUNE8",
		rotate = false
	}
}

local function OnUpdate(self, elapsed)
	self.texture.timer = self.texture.timer + elapsed;
	if ( self.texture.timer > 0.02 ) then
		self.texture.hAngle = self.texture.hAngle + 0.5;
		self.texture:SetRotation(rad(self.texture.hAngle));
		self.texture.timer = 0;
	end
end

local function OnShow(self)
	if module.db.profile.rotate then
		self:SetScript('OnUpdate', OnUpdate)
	else
		self:SetScript('OnUpdate', nil)
	end
end

function module:ApplyOptions()
	local anchor = addon.anchor
	if self:IsEnabled() then
		if not ringFrame then
			ringFrame = CreateFrame("Frame")
			ringFrame:SetParent(anchor)
			ringFrame:SetAllPoints()
			ringFrame:SetScript('OnShow', OnShow)
			ringFrame.texture = ringFrame:CreateTexture(nil, 'ARTWORK')
			ringFrame.texture.timer = 0;
			ringFrame.texture.hAngle = 0;
		end
		local texture = ringFrame.texture
		texture:SetTexture(self.db.profile.texture) -- Spells\\AURARUNE8
		texture:SetVertexColor(self.db.profile.color.r,self.db.profile.color.g,self.db.profile.color.b,self.db.profile.color.a) -- 0,1,0,0.5
		texture:SetBlendMode('ADD')
		texture:SetWidth(80)
		texture:SetHeight(80)
		texture:SetPoint('CENTER', ringFrame, 'CENTER')
		texture:SetRotation(rad(texture.hAngle))
		texture:Show()
		ringFrame:Hide()
	end
end

function module:OnEnable()
	self:ApplyOptions()
	showRequests = {}
end

function module:OnDisable()
	ringFrame:Hide()
end

function module:FixDatabase()
	if self.db.profile.version then
		-- nothing to do yet
	end
	self.db.profile.version = dbVersion
end

function module:OnInitialize()
	self.db = addon.db:RegisterNamespace("Ring", defaults)
	self:FixDatabase()
end

function module:GetOptions()
	options = {
		name = L["Ring"],
		type = "group",
		args = {
			display = {
				name = L["Display"],
				type = "header",
				order = 10
			},
			texture = {
				name = L["Texture"],
				type = "input",
				disabled = function() return not addon.db.profile.modules.ring end,
				get = function(info) return self.db.profile.texture end,
				set = function(info, val)
							self.db.profile.texture = val
							self:ApplyOptions()
						end,
				order = 11
			},
			color = {
				name = L["Color"],
				type = "color",
				disabled = function() return not addon.db.profile.modules.ring end,
				get = function(info) return self.db.profile.color.r, self.db.profile.color.g, self.db.profile.color.b, self.db.profile.color.a end,
				set = function(info, r, g, b, a)
							self.db.profile.color = {r=r, g=g, b=b, a=a}
							self:ApplyOptions()
						end,
				hasAlpha = true,
				order = 12
			},
			rotate = {
				name = L["Rotate"],
				type = "toggle",
				disabled = function() return not addon.db.profile.modules.ring end,
				get = function(info) return self.db.profile.rotate end,
				set = function(info, val) self.db.profile.rotate = val end,
				order = 13
			},
			misc = {
				name = L["Miscellaneous"],
				type = "header",
				order = 20
			},
			defaults = {
				name = L["Restore defaults"],
				type = "execute",
				disabled = function() return not addon.db.profile.modules.ring end,
				func = function()
							self.db:ResetProfile()
							self:ApplyOptions()
						end,
				order = 21
			}
		}
	}

	return options
end

function module:Show(module)
	showRequests[module] = true;
	ringFrame:Show();
end

function module:Hide(module)
	showRequests[module] = false;

	local hide = true;
	for _,v in pairs(showRequests) do
		if v then
			hide = false
			break
		end
	end
	if hide then
		ringFrame:Hide()
	end
end

function module:Unlock(cursor)
	ringFrame:Hide()
	ringFrame:SetScript('OnShow', nil)
	ringFrame:ClearAllPoints()
	ringFrame:SetParent(cursor)
	ringFrame:SetPoint("CENTER", cursor, "CENTER")
	ringFrame:SetWidth(64)
	ringFrame:SetHeight(64)
	ringFrame:Show()
end

function module:Lock()
	ringFrame:Hide()
	ringFrame:SetScript('OnShow', OnShow)
	ringFrame:ClearAllPoints()
	ringFrame:SetParent(addon.anchor)
	ringFrame:SetAllPoints()
	ringFrame:Show()
end
