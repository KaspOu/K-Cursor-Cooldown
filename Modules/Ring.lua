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
		texture = "165624",
		rotate = true,
		width = 75
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
		texture:SetTexture(string.gsub(self.db.profile.texture, "^%d+%-", ""))
		texture:SetVertexColor(self.db.profile.color.r,self.db.profile.color.g,self.db.profile.color.b,self.db.profile.color.a) -- 0,1,0,0.5
		texture:SetBlendMode('ADD')
		texture:SetWidth(self.db.profile.width)
		texture:SetHeight(self.db.profile.width)
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
	local GetAddOnInfo = C_AddOns.GetAddOnInfo or GetAddOnInfo
	local addonFolder = GetAddOnInfo("CursorCooldown")
	addonFolder = "Interface\\AddOns\\"..addonFolder
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
				type = "select",
				disabled = function() return not addon.db.profile.modules.ring end,
				get = function() return self.db.profile.texture end,
				set = function(_, val)
							self.db.profile.texture = val
							self:ApplyOptions()
						end,
				values = {
					["165624"] 	= "AuraRune 1 (default)",
					["165630"] 	= "AuraRune 1 glow",
					["165635"] 	= "AuraRune 8 (legacy)",
					[addonFolder.."\\Textures\\AuraSplit"] = "Aura - Split",
					[addonFolder.."\\Textures\\AuraHalf"] = "Aura - Half",
					["165633"] 	= "AuraRune 5",
					["165634"] 	= "AuraRune 7",
					["165631"] 	= "AuraRune 9",
					["165638"] 	= "AuraRune A",
					["165639"] 	= "AuraRune B",
					["165640"] 	= "AuraRune C",
					["165623"]	= "Halo",
					["165632"] 	= "Circle",
				},
				sorting = {
					"165624",
					"165630",
					"165635",
					addonFolder.."\\Textures\\AuraSplit",
					addonFolder.."\\Textures\\AuraHalf",
					"165633",
					"165634",
					"165631",
					"165638",
					"165639",
					"165640",
					"165623",
					"165632",
				},
				order = 11
			},
			texture2 = {
				name = "",
				type = "input",
				disabled = function() return not addon.db.profile.modules.ring end,
				get = function(_) return self.db.profile.texture end,
				set = function(_, val)
							self.db.profile.texture = val
							self:ApplyOptions()
						end,
				order = 12
			},
			width = {
			  name = L["Width"],
			  type = "range",
			  min = 40,
			  max = 100,
			  step = 5,
			  disabled = function() return not addon.db.profile.modules.ring end,
			  get = function(_) return self.db.profile.width end,
			  set = function(_, val)
				self.db.profile.width = val
				self:ApplyOptions()
			  end,
			  order = 13
			},
			color = {
				name = L["Color"],
				type = "color",
				disabled = function() return not addon.db.profile.modules.ring end,
				get = function(_) return self.db.profile.color.r, self.db.profile.color.g, self.db.profile.color.b, self.db.profile.color.a end,
				set = function(_, r, g, b, a)
							self.db.profile.color = {r=r, g=g, b=b, a=a}
							self:ApplyOptions()
						end,
				hasAlpha = true,
				order = 14
			},
			texturePreview = {
				name = "",
				type = "execute",
				image = function() return self.db.profile.texture end,
				imageWidth = 70,
				imageHeight = 70,
				disabled = true,
				order = 15
			},
			rotate = {
				name = L["Rotate"],
				type = "toggle",
				disabled = function() return not addon.db.profile.modules.ring end,
				get = function(_) return self.db.profile.rotate end,
				set = function(_, val) self.db.profile.rotate = val end,
				order = 16
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
