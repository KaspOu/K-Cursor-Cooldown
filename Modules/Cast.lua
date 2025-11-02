local addon = LibStub("AceAddon-3.0"):GetAddon("CC")
local module = addon:NewModule("cast")
local media = LibStub("LibSharedMedia-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("CC")
local dbVersion = 1

local GetTime = GetTime
local castStartTime, castEndTime, castDuration, castInterrupted, castLatency, castSent, isCasting
local castFrame
local options
local ringMod


local defaults = {
	profile = {
		barColor = {r=1, g=1, b=1, a=0.8},
		backgroundColor = {r=0.4, g=0.4, b=0.4, a=0.8},
		sparkColor = {r = 0.9, g = 0.8, b = 1, a = 1},
		latencyColor = {r=1, g=0, b=0, a=1},
		radius = 22,
		thickness = 25,
		sparkOnly = false,
		spellText = {
			enabled = false,
			font = "Calibri",
			fontSize = 12,
			fontColor = {r=1, g=1, b=1, a=0.8},
			relativeX = 0,
			relativeY = 0,
		},
		hideCastBar = false
	}
}

function module:FixDatabase()
	if self.db.profile.version then
		-- nothing to do yet
	end
	self.db.profile.version = dbVersion
end

function module:OnInitialize()
	self.db = addon.db:RegisterNamespace("Cast", defaults)
	self:FixDatabase()
	ringMod = addon:GetModule("ring", true)
end

function module:GetOptions()
	options = {
		name = L["Casttime"],
		type = "group",
		args = {
			sparkOnly = {
				name = L["Show spark only"],
				type = "toggle",
				disabled = function() return not addon.db.profile.modules.cast end,
				get = function(info) return self.db.profile.sparkOnly end,
				set = function(info, val)
							self.db.profile.sparkOnly = val
							self:ApplyOptions()
						end,
				order = 1
			},
			radius = {
				name = L["Radius"],
				type = "range",
				min = 10,
				max = 256,
				step = 1,
				disabled = function() return not addon.db.profile.modules.cast end,
				get = function(info) return self.db.profile.radius end,
				set = function(info, val)
							self.db.profile.radius = val
							self:ApplyOptions()
						end,
				order = 2
			},
			thickness = {
				name = L["Thickness"],
				type = "range",
				min = 15,
				max = 35,
				step = 5,
				disabled = function() return not addon.db.profile.modules.cast end,
				get = function(info) return self.db.profile.thickness end,
				set = function(info, val)
							self.db.profile.thickness = val
							self:ApplyOptions()
						end,
				order = 3
			},
			reverseChanneling = {
				name = L["Reverse channeling"],
				type = "toggle",
				disabled = function() return not addon.db.profile.modules.cast end,
				get = function(info) return self.db.profile.reverseChanneling end,
				set = function(info,val)
						self.db.profile.reverseChanneling = val
						self:ApplyOptions()
					end,
				order = 4,
				width = "double"
			},
			colors = {
				name = L["Colors"],
				type = "header",
				order = 20
			},
			barColor = {
				name = L["Bar"],
				type = "color",
				disabled = function() return not addon.db.profile.modules.cast end,
				get = function(info) return self.db.profile.barColor.r, self.db.profile.barColor.g, self.db.profile.barColor.b, self.db.profile.barColor.a end,
				set = function(info, r, g, b, a)
							self.db.profile.barColor = {r=r, g=g, b=b, a=a}
							self:ApplyOptions()
						end,
				hasAlpha = true,
				order = 21
			},
			bgColor = {
				name = L["Background"],
				type = "color",
				disabled = function() return not addon.db.profile.modules.cast end,
				get = function(info) return self.db.profile.backgroundColor.r, self.db.profile.backgroundColor.g, self.db.profile.backgroundColor.b, self.db.profile.backgroundColor.a end,
				set = function(info, r, g, b, a)
							self.db.profile.backgroundColor = {r=r, g=g, b=b, a=a}
							self:ApplyOptions()
						end,
				hasAlpha = true,
				order = 22
			},
			sparkColor = {
				name = L["Spark"],
				type = "color",
				disabled = function() return not addon.db.profile.modules.cast end,
				get = function(info) return self.db.profile.sparkColor.r, self.db.profile.sparkColor.g, self.db.profile.sparkColor.b, self.db.profile.sparkColor.a end,
				set = function(info, r, g, b, a)
							self.db.profile.sparkColor = {r=r, g=g, b=b, a=a}
							self:ApplyOptions()
						end,
				hasAlpha = true,
				order = 23
			},
			latencyColor = {
				name = L["Latency color"],
				type = "color",
				disabled = function() return not addon.db.profile.modules.cast end,
				get = function(info) return self.db.profile.latencyColor.r, self.db.profile.latencyColor.g, self.db.profile.latencyColor.b, self.db.profile.latencyColor.a end,
				set = function(info, r, g, b, a)
							self.db.profile.latencyColor = {r=r, g=g, b=b, a=a}
							self:ApplyOptions()
						end,
				hasAlpha = true,
				order = 24
			},
			spellText = {
				name = L["Spell Text"],
				type = "header",
				order = 30
			},
			spellTextEnabled = {
				name = L["Enabled"],
				type = "toggle",
				disabled = function() return not addon.db.profile.modules.cast end,
				get = function(info) return self.db.profile.spellText.enabled end,
				set = function(info,val)
						self.db.profile.spellText.enabled = val
						self:ApplyOptions()
					end,
				order = 31
			},
			font = {
				name = L["Font"],
				type = "select",
				disabled = function() return (not addon.db.profile.modules.cast or not self.db.profile.spellText.enabled) end,
				dialogControl = 'LSM30_Font',
				get = function() return self.db.profile.spellText.font end,
				set = function(_, value)
							self.db.profile.spellText.font = value
							self:ApplyOptions()
						end,
				values = media:HashTable("font"),
				order = 32,
				width= "double"
			},
			fontSize = {
				name = L["Font Size"],
				type = "range",
				disabled = function() return (not addon.db.profile.modules.cast or not self.db.profile.spellText.enabled) end,
				min = 1,
				max = 30,
				step = 1,
				get = function() return self.db.profile.spellText.fontSize end,
				set = function(_, value)
							self.db.profile.spellText.fontSize = value
							self:ApplyOptions()
						end,
				order = 33
			},
			fontColor = {
				name = L["Color"],
				type = "color",
				disabled = function() return (not addon.db.profile.modules.cast or not self.db.profile.spellText.enabled) end,
				get = function(info) return self.db.profile.spellText.fontColor.r, self.db.profile.spellText.fontColor.g, self.db.profile.spellText.fontColor.b, self.db.profile.spellText.fontColor.a end,
				set = function(info, r, g, b, a)
							self.db.profile.spellText.fontColor = {r=r, g=g, b=b, a=a}
							self:ApplyOptions()
						end,
				hasAlpha = true,
				order = 34
			},
			relativeX = {
				name = L["Horizontal Offset"],
				type = "range",
				disabled = function() return (not addon.db.profile.modules.cast or not self.db.profile.spellText.enabled) end,
				min = -60,
				max = 60,
				step = 2,
				get = function() return self.db.profile.spellText.relativeX end,
				set = function(_, value)
							self.db.profile.spellText.relativeX = value
							self:ApplyOptions()
						end,
				order = 37
			},
			relativeY = {
				name = L["Vertical Offset"],
				type = "range",
				disabled = function() return (not addon.db.profile.modules.cast or not self.db.profile.spellText.enabled) end,
				min = -80,
				max = 80,
				step = 2,
				get = function() return self.db.profile.spellText.relativeY end,
				set = function(_, value)
							self.db.profile.spellText.relativeY = value
							self:ApplyOptions()
						end,
				order = 38
			},
			misc = {
				name = L["Miscellaneous"],
				type = "header",
				order = 40
			},
			hideCastBar = {
				name = L["Hide default castbar"],
				type = "toggle",
				disabled = function() return not addon.db.profile.modules.cast end,
				get = function(info) return self.db.profile.hideCastBar end,
				set = function(info,val)
						self.db.profile.hideCastBar = val
						if val then
							addon.BlizzardCastingBarFrame:UnregisterAllEvents()
							addon.BlizzardCastingBarFrame:Hide()
						else
							addon.BlizzardCastingBarFrame:UnregisterAllEvents()
							addon.BlizzardCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_START")
							addon.BlizzardCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
							addon.BlizzardCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
							addon.BlizzardCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
							addon.BlizzardCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
							addon.BlizzardCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
							addon.BlizzardCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
							addon.BlizzardCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")

							addon.BlizzardCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_SENT")
							if RAID_CLASS_COLORS.EVOKER ~= nil then
								addon.BlizzardCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
								addon.BlizzardCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
								addon.BlizzardCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_UPDATE")
							end
							addon.BlizzardCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
							addon.BlizzardCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
							addon.BlizzardCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
						end
					end,
				order = 42,
				width = "double"
			},
			defaults = {
				name = L["Restore defaults"],
				type = "execute",
				disabled = function() return not addon.db.profile.modules.cast end,
				func = function()
							self.db:ResetProfile()
							self:ApplyOptions()
						end,
				order = 43
			}
		}
	}
	return options
end

function module:RegisterUnitEvent(event, unit)
	AceAddon30Frame:RegisterUnitEvent(event, unit)
	if (not AceAddon30Frame._RegisterUnitEvents) then
		AceAddon30Frame._RegisterUnitEvents = true
		AceAddon30Frame:SetScript("OnEvent", function(self, event, unit, ...)
			if type(module[event]) == "function" then
				module[event](module, event, unit, ...)
			end
		end)
	end
end

function module:OnEnable()
	self:ApplyOptions()
	self:RegisterEvent("UNIT_SPELLCAST_SENT")
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	self:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
	self:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
	self:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
	self:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
	-- UNIT_SPELLCAST_FAILED_QUIET
	-- UNIT_SPELLCAST_SUCCEEDED
	self:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
	self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
	self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
	self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
	if RAID_CLASS_COLORS.EVOKER ~= nil then
		self:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", "player")
		self:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "player")
		self:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", "player")
	end
end

function module:OnDisable()
	self:UnregisterAllEvents()
	self:Hide()
end

function module:Show()
	addon:Show("cast")
	if ringMod and ringMod:IsEnabled() then ringMod:Show("cast") end
	if self.db.profile.spellText.enabled then
		castFrame.spellText:Show()
	else
		castFrame.spellText:Hide()
	end

	castFrame:Show()

	local angle =  math.max(.1, castLatency * 360)
	if not module.db.profile.sparkOnly then
		castFrame.latencyDonut:SetAngle(angle)
	end
end

function module:Hide(hideGcd)
	castFrame:Hide()

	if ringMod and ringMod:IsEnabled() then ringMod:Hide("cast") end
	addon:Hide("cast")
	if (hideGcd) then
		addon:Hide("gcd")
	end
end

local function OnUpdate(self, elapsed)
	castFrame.donut:SetCooldown(castStartTime, castDuration, true, castEndTime)
	-- local castPerc = castDuration == 0 and 0 or ((1000 * GetTime() - castStartTime) / castDuration)
	-- if castDuration ~= 0 and castPerc < 1 then
	-- 	local angle = castPerc * 360
	-- 	if (module.db.profile.reverseChanneling and addon.BlizzardCastingBarFrame.channeling) then
	-- 		angle = (1 - castPerc) * 360
	-- 	end
	-- 	if not module.db.profile.sparkOnly then
	-- 		-- castFrame.donut:SetAngle(angle, castEndTime)
	-- 		castFrame.donut:SetCooldown(castStartTime, castDuration, true, castEndTime)
	-- 	end
	-- 	angle = 360 -(-90 + angle)

	-- 	local x = cos(angle) * module.db.profile.radius * 0.95
	-- 	local y = sin(angle) * module.db.profile.radius * 0.95
	-- 	local spark = castFrame.sparkTexture
	-- 	spark:SetRotation(rad(angle+90))
	-- 	spark:ClearAllPoints()
	-- 	spark:SetPoint("CENTER", castFrame, "CENTER", x, y)

	-- 	if module.db.profile.sparkOnly and castPerc > 1-castLatency then
	-- 		spark:SetVertexColor(module.db.profile.latencyColor.r, module.db.profile.latencyColor.g, module.db.profile.latencyColor.b, module.db.profile.latencyColor.a)
	-- 	else
	-- 		spark:SetVertexColor(module.db.profile.sparkColor.r, module.db.profile.sparkColor.g, module.db.profile.sparkColor.b, module.db.profile.sparkColor.a)
	-- 	end
	-- else
	-- 	module:Hide()
	-- end
end

function module:UNIT_SPELLCAST_SENT(_, unit)
	-- if not UnitIsPlayer(unit) then return end
	if (addon.isSecret(unit) or unit ~= "player") then return end
	castSent = GetTime() * 1000
end
function module:UNIT_SPELLCAST_SUCCEEDED(evt, unit)
	self:UNIT_SPELLCAST_SENT(evt, unit)
end

function module:UNIT_SPELLCAST_START(_, unit, action)
	-- if not UnitIsPlayer(unit) then return end
	local text, spell
	spell, text, _, castStartTime, castEndTime, _, _, _, _ = UnitCastingInfo(unit)
	local sendLag = (castSent and castSent > 0) and GetTime() * 1000 - castSent or 0
	if not addon.isSecret(castEndTime) then
		castDuration = castEndTime and castEndTime - castStartTime or 0
		sendLag = sendLag > castDuration and castDuration or sendLag
		castLatency = castDuration == 0 and 0 or sendLag / castDuration
	else
		castDuration = 1000
		sendLag = 0
		castLatency = 0
	end

	if castFrame.spellText then
		if (type(text) ~= "nil") then
			castFrame.spellText:SetText(text)
		else
			castFrame.spellText:SetText(spell)
		end
	end
	self:Show()
end

function module:UNIT_SPELLCAST_STOP(_, unit)
	-- if not UnitIsPlayer(unit) then return end
	self:Hide(true)
end

function module:UNIT_SPELLCAST_FAILED(_, unit)
	-- if not UnitIsPlayer(unit) then return end
	self:Hide(true)
end

function module:UNIT_SPELLCAST_INTERRUPTED(_, unit)
	-- if not UnitIsPlayer(unit) then return end
	self:Hide()
end

function module:UNIT_SPELLCAST_DELAYED(_, unit)
	-- if not UnitIsPlayer(unit) then return end
	_, _, _, _, castStartTime, castEndTime = UnitCastingInfo(unit)
	castDuration = castEndTime and castEndTime - castStartTime or 0
end

function module:UNIT_SPELLCAST_CHANNEL_START(_,unit)
	-- if not UnitIsPlayer(unit) then return end
	local text, spell
	spell, text, _, castStartTime, castEndTime = UnitChannelInfo(unit)
	local sendLag = (castSent and castSent > 0) and GetTime() * 1000 - castSent or 0
	castDuration = castEndTime and castEndTime - castStartTime or 0
	sendLag = sendLag > castDuration and castDuration or sendLag
	castLatency = sendLag / castDuration
	if (type(text) ~= "nil") then
		castFrame.spellText:SetText(text)
	else
		castFrame.spellText:SetText(spell)
	end
	self:Show()
end

function module:UNIT_SPELLCAST_CHANNEL_STOP(_,unit)
	-- if not UnitIsPlayer(unit) then return end
	self:Hide(true)
end

function module:UNIT_SPELLCAST_CHANNEL_UPDATE(_,unit)
	-- if not UnitIsPlayer(unit) then return end
	_, _, _, castStartTime, castEndTime = UnitChannelInfo(unit)
	castDuration = castEndTime - castStartTime
end

function module:UNIT_SPELLCAST_EMPOWER_START(event,unit)
	module:UNIT_SPELLCAST_CHANNEL_START(event,unit)
end
function module:UNIT_SPELLCAST_EMPOWER_STOP(event,unit)
	module:UNIT_SPELLCAST_CHANNEL_STOP(event,unit)
end
function module:UNIT_SPELLCAST_EMPOWER_UPDATE(event,unit)
	module:UNIT_SPELLCAST_CHANNEL_UPDATE(event,unit)
end

function module:ApplyOptions()
	local anchor = addon.anchor
	if self:IsEnabled() then
		if not castFrame then
			-- FIXME: Duplicate frame for Midnight?
			castFrame = CreateFrame("Frame")
			castFrame:SetParent(anchor)
			castFrame:SetAllPoints()

			castFrame.sparkTexture = castFrame:CreateTexture(nil, 'OVERLAY')
			castFrame.sparkTexture:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
			castFrame.sparkTexture:SetBlendMode("ADD")
		end
		self:Hide()

		if not self.db.profile.sparkOnly then
			if not castFrame.donut then
				local donut = addon.donut:New(false, self.db.profile.radius, self.db.profile.thickness, self.db.profile.latencyColor, self.db.profile.backgroundColor, nil, false)
				donut:AttachTo(castFrame)
				castFrame.latencyDonut = donut

				local bgcm = {}
				bgcm.r = 0
				bgcm.g = 0
				bgcm.b = 0
				bgcm.a = 0
				donut = addon.donut:New(true, self.db.profile.radius, self.db.profile.thickness, self.db.profile.barColor, bgcm, donut.frame, true)
				donut:AttachTo(castFrame)
				castFrame.donut = donut
			else
				local donut = castFrame.donut
				donut:SetRadius(self.db.profile.radius)
				donut:SetThickness(self.db.profile.thickness)
				donut:SetBarColor(self.db.profile.barColor)
				donut:SetBackgroundColor(self.db.profile.backgroundColor)

				donut = castFrame.latencyDonut
				donut:SetRadius(self.db.profile.radius)
				donut:SetThickness(self.db.profile.thickness)
				donut:SetBarColor(self.db.profile.latencyColor)
				donut:SetBackgroundColor(self.db.profile.backgroundColor)
			end

			castFrame:SetScript("OnShow", function(self) self.donut:Show() self.latencyDonut:Show() end)
			castFrame:SetScript("OnHide", function(self) self.donut:Hide() self.latencyDonut:Hide() end)
		elseif castFrame.donut then
			castFrame.donut:Hide()
			castFrame.latencyDonut:Hide()
			castFrame:SetScript("OnShow", nil)
			castFrame:SetScript("OnHide", nil)
		end

		castFrame.sparkTexture:SetVertexColor(self.db.profile.sparkColor.r, self.db.profile.sparkColor.g, self.db.profile.sparkColor.b, self.db.profile.sparkColor.a)
		castFrame.sparkTexture:SetWidth(self.db.profile.radius)
		castFrame.sparkTexture:SetHeight(self.db.profile.radius)
		castFrame.sparkTexture:Show()

		if self.db.profile.spellText then
			local spellText = castFrame.spellText or castFrame:CreateFontString(nil, "OVERLAY")
			spellText:ClearAllPoints()
			spellText:SetPoint("BOTTOM", castFrame, "CENTER", 0 + self.db.profile.spellText.relativeX, self.db.profile.radius + 5 + self.db.profile.spellText.relativeY)
			spellText:SetFont(media:Fetch("font", self.db.profile.spellText.font), self.db.profile.spellText.fontSize)
			spellText:SetTextColor(self.db.profile.spellText.fontColor.r, self.db.profile.spellText.fontColor.g, self.db.profile.spellText.fontColor.b, self.db.profile.spellText.fontColor.a)
			spellText:Show()
			castFrame.spellText = spellText
		elseif castFrame.spellText then
			castFrame.spellText:ClearAllPoints()
			castFrame.spellText:Hide()
		end

		if self.db.profile.hideCastBar then
			addon.BlizzardCastingBarFrame:UnregisterAllEvents()
			addon.BlizzardCastingBarFrame:Hide()
		end

		castFrame:SetScript('OnUpdate', OnUpdate)
	end
end

function module:Unlock(cursor)
	if not self.db.profile.sparkOnly then
		castFrame:SetScript("OnUpdate", nil)
		castFrame.donut:SetAngle(320)
		castFrame.latencyDonut:SetAngle(60)
		castFrame:SetParent(cursor)
		castFrame:SetAllPoints()
		castFrame:Show()
	end
end

function module:Lock()
	if not self.db.profile.sparkOnly then
		castFrame:Hide()
		castFrame:SetParent(addon.anchor)
		castFrame:SetAllPoints()
		castFrame:SetScript("OnUpdate", OnUpdate)
	end
end
