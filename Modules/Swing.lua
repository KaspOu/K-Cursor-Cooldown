--[[
	Most of the functionality was taken from the Quartz - Swing Module. Credits go to Nymbia and Nevcairiel
]]

local addon = LibStub("AceAddon-3.0"):GetAddon("CC")
local module = addon:NewModule("swing")
local L = LibStub("AceLocale-3.0"):GetLocale("CC")
local dbVersion = 1

local GetTime = GetTime
local swingFrame
local options
local ringMod

local swingMode
local playerClass

local autoshot = addon.GetSpellInfo(75)
local shoot = addon.GetSpellInfo(5019)
local slam = addon.GetSpellInfo(1464)
local slamStart
local startTime, duration

local defaults = {
	profile = {
		barColor = {r=1, g=1, b=1, a=0.8},
		backgroundColor = {r=0.4, g=0.4, b=0.4, a=0.8},
		sparkColor = {r = 0.9, g = 0.8, b = 1, a = 1},
		radius = 18,
		thickness = 25,
		sparkOnly = false
	}
}

function module:OnEnable()
	self:ApplyOptions()
	self:RegisterEvent("PLAYER_ENTER_COMBAT")
	self:RegisterEvent("PLAYER_LEAVE_COMBAT")

	self:RegisterEvent("START_AUTOREPEAT_SPELL")
	self:RegisterEvent("STOP_AUTOREPEAT_SPELL")

	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

	if playerClass == "WARRIOR" then
		self:RegisterEvent("UNIT_SPELLCAST_START")
		self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	end
	if playerClass == "EVOKER" then
		self:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
		self:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
	end

	self:RegisterEvent("UNIT_ATTACK")
end

function module:OnDisable()
	self:UnregisterAllEvents()
	self:Hide()
end

function module:FixDatabase()
	if self.db.profile.version then
		-- nothing to do yet
	end
	self.db.profile.version = dbVersion
end

function module:OnInitialize()
	self.db = addon.db:RegisterNamespace("Swing", defaults)
	self:FixDatabase()
	ringMod = addon:GetModule("ring", true)
	_, playerClass = UnitClass("player")
end

function module:GetOptions()
	options = {
		name = "Swing",
		type = "group",
		args = {
			sparkOnly = {
				name = L["Show spark only"],
				type = "toggle",
				disabled = function() return not addon.db.profile.modules.swing end,
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
				disabled = function() return not addon.db.profile.modules.swing end,
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
				max = 25,
				step = 5,
				disabled = function() return not addon.db.profile.modules.swing end,
				get = function(info) return self.db.profile.thickness end,
				set = function(info, val)
							self.db.profile.thickness = val
							self:ApplyOptions()
						end,
				order = 3
			},
			colors = {
				name = L["Colors"],
				type = "header",
				order = 10
			},
			barColor = {
				name = L["Bar"],
				type = "color",
				disabled = function() return not addon.db.profile.modules.swing end,
				get = function(info) return self.db.profile.barColor.r, self.db.profile.barColor.g, self.db.profile.barColor.b, self.db.profile.barColor.a end,
				set = function(info, r, g, b, a)
							self.db.profile.barColor = {r=r, g=g, b=b, a=a}
							self:ApplyOptions()
						end,
				hasAlpha = true,
				order = 11
			},
			bgColor = {
				name = L["Background"],
				type = "color",
				disabled = function() return not addon.db.profile.modules.swing end,
				get = function(info) return self.db.profile.backgroundColor.r, self.db.profile.backgroundColor.g, self.db.profile.backgroundColor.b, self.db.profile.backgroundColor.a end,
				set = function(info, r, g, b, a)
							self.db.profile.backgroundColor = {r=r, g=g, b=b, a=a}
							self:ApplyOptions()
						end,
				hasAlpha = true,
				order = 12
			},
			sparkColor = {
				name = L["Spark"],
				type = "color",
				disabled = function() return not addon.db.profile.modules.swing end,
				get = function(info) return self.db.profile.sparkColor.r, self.db.profile.sparkColor.g, self.db.profile.sparkColor.b, self.db.profile.sparkColor.a end,
				set = function(info, r, g, b, a)
							self.db.profile.sparkColor = {r=r, g=g, b=b, a=a}
							self:ApplyOptions()
						end,
				hasAlpha = true,
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
				disabled = function() return not addon.db.profile.modules.swing end,
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

function module:Show()
	addon:Show("swing")
	if ringMod and ringMod:IsEnabled() then ringMod:Show("swing") end
	startTime = GetTime()
	if swingMode == 1 then
		duration = UnitAttackSpeed("player")
	elseif swingMode == 2 then
		duration = UnitRangedDamage("player")
	end
	swingFrame:Show()
end

function module:Hide()
	swingFrame:Hide()

	if ringMod and ringMod:IsEnabled() then ringMod:Hide("swing") end
	startTime, duration = nil, nil
	addon:Hide("swing")
end

local function OnUpdate(self, elapsed)
	local perc = (GetTime() - startTime) / duration
	if perc < 1 then
		local angle = perc * 360
		if not module.db.profile.sparkOnly then
			swingFrame.donut:SetAngle(angle)
		end
		angle = 360 -(-90 + angle)

		local x = cos(angle) * module.db.profile.radius * 0.95
		local y = sin(angle) * module.db.profile.radius * 0.95
		local spark = swingFrame.sparkTexture
		spark:SetRotation(rad(angle + 90))
		spark:ClearAllPoints()
		spark:SetPoint("CENTER", swingFrame, "CENTER", x, y)
	else
		module:Hide()
	end
end

function module:PLAYER_ENTER_COMBAT()
	local _,_,offhandlow, offhandhigh = UnitDamage("player")
	if (offhandhigh - offhandlow) <= 0.1 or playerClass == "DRUID" then
		swingMode = 1
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
end

function module:PLAYER_LEAVE_COMBAT()
	if swingMode == 1 then
		swingMode = nil
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
end

function module:START_AUTOREPEAT_SPELL()
	swingMode = 2
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function module:STOP_AUTOREPEAT_SPELL()
	if swingMode == 2 then
		swingMode = nil
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
end

function module:UNIT_SPELLCAST_SUCCEEDED(event, unit, spell)
	if unit ~= "player" or not swingMode then return end
	-- TODO: EVOKER Bar support
	if swingMode == 1 then
		if spell == slam and slamStart then
			startTime = startTime + GetTime() - slamStart
			slamStart = nil
		end
	elseif swingMode == 2 then
		if spell == autoshot or spell == shoot then
			self:Show()
		end
	end
end

function module:UNIT_SPELLCAST_INTERRUPTED(event, unit, spell)
	if unit == "player" and spell == slam and slamStart then
		slamStart = nil
	end
end

function module:UNIT_SPELLCAST_START(event, unit, spell)
	if unit == "player" and spell == slam then
		slamStart = GetTime()
	end
end

function module:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, combatevent, srcGUID, srcName, srcFlags, dstName, dstGUID, dstFlags, spellID, spellName)
	if srcGUID == UnitGUID("player") then
		if combatevent == "SWING_DAMAGE" or combatevent == "SWING_MISSED" then
			self:Show()
		end
	elseif dstGUID == UnitGUID("player") and combatevent == "SWING_MISSED" and spellID == "PARRY" and duration then
		duration = duration * 0.6
	end
end

function module:UNIT_ATTACK(event, unit)
	if unit == "player" and swingMode then
		if swingMode == 1 then
			duration = UnitAttackSpeed("player")
		elseif swingMode == 2 then
			duration = UnitRangedDamage("player")
		end
	end
end

function module:ApplyOptions()
	local anchor = addon.anchor
	if self:IsEnabled() then
		if not swingFrame then
			swingFrame = CreateFrame("Frame")
			swingFrame:SetParent(anchor)
			swingFrame:SetAllPoints()

			swingFrame.sparkTexture = swingFrame:CreateTexture(nil, 'OVERLAY')
			swingFrame.sparkTexture:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
			swingFrame.sparkTexture:SetBlendMode("ADD")
		end
		self:Hide()

		if not self.db.profile.sparkOnly then
			if not swingFrame.donut then
				local donut = addon.donut:New(true, self.db.profile.radius, self.db.profile.thickness, self.db.profile.barColor, self.db.profile.backgroundColor)
				donut:AttachTo(swingFrame)
				swingFrame.donut = donut
			else
				local donut = swingFrame.donut
				donut:SetRadius(self.db.profile.radius)
				donut:SetThickness(self.db.profile.thickness)
				donut:SetBarColor(self.db.profile.barColor)
				donut:SetBackgroundColor(self.db.profile.backgroundColor)
			end

			swingFrame:SetScript("OnShow", function(self) self.donut:Show() end)
			swingFrame:SetScript("OnHide", function(self) self.donut:Hide() end)
		elseif swingFrame.donut then
			swingFrame.donut:Hide()
			swingFrame:SetScript("OnShow", nil)
			swingFrame:SetScript("OnHide", nil)
		end

		swingFrame.sparkTexture:SetVertexColor(self.db.profile.sparkColor.r, self.db.profile.sparkColor.g, self.db.profile.sparkColor.b, self.db.profile.sparkColor.a)
		swingFrame.sparkTexture:SetWidth(self.db.profile.radius)
		swingFrame.sparkTexture:SetHeight(self.db.profile.radius)
		swingFrame.sparkTexture:Show()

		swingFrame:SetScript('OnUpdate', OnUpdate)
	end
end

function module:Unlock(cursor)
	if not self.db.profile.sparkOnly then
		swingFrame:SetScript("OnUpdate", nil)
		swingFrame.donut:SetAngle(115)
		swingFrame:SetParent(cursor)
		swingFrame:SetAllPoints()
		swingFrame:Show()
	end
end

function module:Lock()
	if not self.db.profile.sparkOnly then
		swingFrame:Hide()
		swingFrame:SetParent(addon.anchor)
		swingFrame:SetAllPoints()
		swingFrame:SetScript("OnUpdate", OnUpdate)
	end
end
