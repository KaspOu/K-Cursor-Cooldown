local addon = LibStub("AceAddon-3.0"):GetAddon("CC")
local module = addon:NewModule("gcd")
local L = LibStub("AceLocale-3.0"):GetLocale("CC")
local dbVersion = 1

local GetTime = GetTime
local spellNum = 61304
local spellName
local gcdFrame
local options
local ringMod

local defaults = {
  profile = {
    barColor = {r = 1, g = 1, b = 1, a = 0.8},
    backgroundColor = {r = 0.4, g = 0.4, b = 0.4, a = 0.8},
    sparkColor = {r = 0.9, g = 0.8, b = 1, a = 1},
    radius = 23,
    thickness = 25,
    sparkOnly = false
  }
}

function module:OnEnable()
  self:ApplyOptions()
  self:SPELLS_CHANGED()
  self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
  self:RegisterEvent("SPELLS_CHANGED")
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
  self.db = addon.db:RegisterNamespace("CC", defaults)
  self:FixDatabase()
  ringMod = addon:GetModule("ring", true)
end

function module:GetOptions()
  -- FIXME: Classic gcd reactivation
  if not C_Spell.DoesSpellExist(61304) then
    if not addon.db.profile.modules.gcd and not addon.db.profile.modules.gcd_back then
      addon.db.profile.modules.gcd = true
      addon.db.profile.modules.gcd_back = true
    end
  end
  options = {
    name = "GCD",
    type = "group",
    args = {
      sparkOnly = {
        name = L["Show spark only"],
        type = "toggle",
        disabled = function() return not addon.db.profile.modules.gcd end,
        get = function(info) return self.db.profile.sparkOnly end,
        set = function(info, val)
          self.db.profile.sparkOnly = val
          self:ApplyOptions()
        end,
        order = 2
      },
      radius = {
        name = L["Radius"],
        type = "range",
        min = 10,
        max = 256,
        step = 1,
        disabled = function() return not addon.db.profile.modules.gcd end,
        get = function(info) return self.db.profile.radius end,
        set = function(info, val)
          self.db.profile.radius = val
          self:ApplyOptions()
        end,
        order = 3
      },
      thickness = {
        name = L["Thickness"],
        type = "range",
        min = 15,
        max = 35,
        step = 5,
        disabled = function() return not addon.db.profile.modules.gcd end,
        get = function(info) return self.db.profile.thickness end,
        set = function(info, val)
          self.db.profile.thickness = val
          self:ApplyOptions()
        end,
        order = 4
      },
      colors = {
        name = L["Colors"],
        type = "header",
        order = 10
      },
      barColor = {
        name = L["Bar"],
        type = "color",
        disabled = function() return not addon.db.profile.modules.gcd end,
        get = function(info) return self.db.profile.barColor.r, self.db.profile.barColor.g, self.db.profile.barColor.b, self.db.profile.barColor.a end,
        set = function(info, r, g, b, a)
          self.db.profile.barColor = {r = r, g = g, b = b, a = a}
          self:ApplyOptions()
        end,
        hasAlpha = true,
        order = 11
      },
      bgColor = {
        name = L["Background"],
        type = "color",
        disabled = function() return not addon.db.profile.modules.gcd end,
        get = function(info) return self.db.profile.backgroundColor.r, self.db.profile.backgroundColor.g, self.db.profile.backgroundColor.b, self.db.profile.backgroundColor.a end,
        set = function(info, r, g, b, a)
          self.db.profile.backgroundColor = {r = r, g = g, b = b, a = a}
          self:ApplyOptions()
        end,
        hasAlpha = true,
        order = 12
      },
      sparkColor = {
        name = L["Spark"],
        type = "color",
        disabled = function() return not addon.db.profile.modules.gcd end,
        get = function(info) return self.db.profile.sparkColor.r, self.db.profile.sparkColor.g, self.db.profile.sparkColor.b, self.db.profile.sparkColor.a end,
        set = function(info, r, g, b, a)
          self.db.profile.sparkColor = {r = r, g = g, b = b, a = a}
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
        disabled = function() return not addon.db.profile.modules.gcd end,
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
  addon:Show("gcd")
  if ringMod and ringMod:IsEnabled() then ringMod:Show("gcd") end
  gcdFrame:Show()
end

function module:Hide()
  gcdFrame:Hide()

  if ringMod and ringMod:IsEnabled() then ringMod:Hide("gcd") end
  addon:Hide("gcd")
end

local function OnUpdate(self, elapsed)
  local gcdPerc = (GetTime() - self.startTime) / self.duration
  if gcdPerc < 1 then
    local angle = gcdPerc * 360
    if not module.db.profile.sparkOnly and gcdFrame.donut then
      gcdFrame.donut:SetAngle(angle)
    end
    angle = 360 - (-90 + angle)

    local x = cos(angle) * module.db.profile.radius * 0.95
    local y = sin(angle) * module.db.profile.radius * 0.95
    local spark = gcdFrame.sparkTexture
    spark:SetRotation(rad(angle + 90))
    spark:ClearAllPoints()
    spark:SetPoint("CENTER", gcdFrame, "CENTER", x, y)
  else
    module:Hide()
  end
end

function module:ApplyOptions()
  local anchor = addon.anchor
  if self:IsEnabled() then
    if not gcdFrame then
      gcdFrame = CreateFrame("Frame")
      gcdFrame:SetParent(anchor)
      gcdFrame:SetAllPoints()

      gcdFrame.sparkTexture = gcdFrame:CreateTexture(nil, 'OVERLAY')
      gcdFrame.sparkTexture:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
      gcdFrame.sparkTexture:SetBlendMode("ADD")
    end
    self:Hide()

    if not self.db.profile.sparkOnly then
      if not gcdFrame.donut then
        local donut = addon.donut:New(true, self.db.profile.radius, self.db.profile.thickness, self.db.profile.barColor, self.db.profile.backgroundColor)
        donut:AttachTo(gcdFrame)
        gcdFrame.donut = donut
      else
        local donut = gcdFrame.donut
        donut:SetRadius(self.db.profile.radius)
        donut:SetThickness(self.db.profile.thickness)
        donut:SetBarColor(self.db.profile.barColor)
        donut:SetBackgroundColor(self.db.profile.backgroundColor)
      end

      gcdFrame:SetScript("OnShow", function(self) self.donut:Show() end)
      gcdFrame:SetScript("OnHide", function(self) self.donut:Hide() end)
    elseif gcdFrame.donut then
      gcdFrame.donut:Hide()
      gcdFrame:SetScript("OnShow", nil)
      gcdFrame:SetScript("OnHide", nil)
    end

    gcdFrame.sparkTexture:SetVertexColor(self.db.profile.sparkColor.r, self.db.profile.sparkColor.g, self.db.profile.sparkColor.b, self.db.profile.sparkColor.a)
    gcdFrame.sparkTexture:SetWidth(self.db.profile.radius)
    gcdFrame.sparkTexture:SetHeight(self.db.profile.radius)
    gcdFrame.sparkTexture:Show()

    gcdFrame:SetScript('OnUpdate', OnUpdate)
  end
end

function module:ACTIONBAR_UPDATE_COOLDOWN()
  if spellNum then
    local start, dur = addon.GetSpellCooldown(spellNum)
    if type(dur) == "number" then
      if dur > 0 and dur <= 1.5 then
        gcdFrame.startTime = start
        gcdFrame.duration = dur
        self:Show()
      end
    end
  end
end

local spells = {
	["DRUID"] = 5185,
	["PALADIN"] = 635,
	["PRIEST"] = 2050,
	["SHAMAN"] = 331,
	["WARRIOR"] = 6673,
	["DEATHKNIGHT"] = 45902,
	["HUNTER"] = 75,
	["MAGE"] = 1459,
	["WARLOCK"] = 687,
	["ROGUE"] = 1752,
}
function module:SPELLS_CHANGED()
  if not C_Spell.DoesSpellExist(61304) then
    local _, class = UnitClass("player")
    spellName = addon.GetSpellInfo(spells[class])
    spellNum = spellName and spells[class] or nil -- addon:GetSpellPosInSpellbook(spellName)
  end
end

function module:Unlock(cursor)
  if not self.db.profile.sparkOnly then
    gcdFrame:SetScript("OnUpdate", nil)
    gcdFrame.donut:SetAngle(195)
    gcdFrame:SetParent(cursor)
    gcdFrame:SetAllPoints()
    gcdFrame:Show()
  end
end

function module:Lock()
  if not self.db.profile.sparkOnly then
    gcdFrame:Hide()
    gcdFrame:SetParent(addon.anchor)
    gcdFrame:SetAllPoints()
    gcdFrame:SetScript("OnUpdate", OnUpdate)
  end
end
