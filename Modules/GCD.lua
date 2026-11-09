---@diagnostic disable: inject-field, undefined-field
local addon = LibStub("AceAddon-3.0"):GetAddon("CC")
local module = addon:NewModule("gcd")
local L = LibStub("AceLocale-3.0"):GetLocale("CC")
local dbVersion = 1

local GetTime = GetTime
local gcdSpellNum = C_Spell.DoesSpellExist(61304) and 61304 or 29515
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
  self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
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
  if not gcdFrame then return end
  addon:Show("gcd")
  if ringMod and ringMod:IsEnabled() then ringMod:Show("gcd") end
  gcdFrame:Show()
end

function module:Hide()
  if gcdFrame then gcdFrame:Hide() end

  if ringMod and ringMod:IsEnabled() then ringMod:Hide("gcd") end
  addon:Hide("gcd")
end

-- CooldownFrame gère lui-même le temps restant. Les valeurs de cooldown
-- peuvent être secrètes : ne jamais les lire ni effectuer de calcul Lua dessus.

function module:ApplyOptions()
  local anchor = addon.anchor
  if self:IsEnabled() then
    local size = self.db.profile.radius * 2
    local r, g, b, alpha = self.db.profile.backgroundColor.r, self.db.profile.backgroundColor.g, self.db.profile.backgroundColor.b, self.db.profile.backgroundColor.a
    if not gcdFrame then
      gcdFrame = CreateFrame("Frame")
      gcdFrame:SetParent(anchor)
      gcdFrame:SetAllPoints()

      -- Le Cooldown natif accepte directement les DurationObjects, y compris
      -- lorsqu'ils contiennent des Secret Values.
      gcdFrame.backgroundTexture = gcdFrame:CreateTexture(nil, "BACKGROUND")
      gcdFrame.backgroundTexture:SetPoint("CENTER", gcdFrame, "CENTER")
      gcdFrame.backgroundTexture:SetTexture(addon.addonFolder .. "\\Textures\\gcd_ring_" .. self.db.profile.thickness)
      gcdFrame.backgroundTexture:SetVertexColor(r, g, b)
      gcdFrame.backgroundTexture:SetAlpha(alpha)

      gcdFrame.cooldown = CreateFrame("Cooldown", nil, gcdFrame, "CooldownFrameTemplate")
      gcdFrame.cooldown:ClearAllPoints()
      gcdFrame.cooldown:SetPoint("CENTER", gcdFrame, "CENTER")
      gcdFrame.cooldown:SetFrameLevel(gcdFrame:GetFrameLevel() + 2)
      gcdFrame.cooldown:SetDrawBling(false)
      gcdFrame.cooldown:SetDrawSwipe(true)
      gcdFrame.cooldown:SetDrawEdge(true)
      gcdFrame.cooldown:SetReverse(true)
      gcdFrame.cooldown:SetHideCountdownNumbers(true)
      gcdFrame.cooldown:SetSwipeTexture(addon.addonFolder .. "\\Textures\\gcd_ring_" .. self.db.profile.thickness)
      gcdFrame.cooldown:SetEdgeTexture("Interface\\Cooldown\\edge")
      gcdFrame.cooldown:SetUseCircularEdge(true)

      -- Texture conservée pour compatibilité visuelle avec les options existantes.
      gcdFrame.sparkTexture = gcdFrame:CreateTexture(nil, "OVERLAY")
      gcdFrame.sparkTexture:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
      gcdFrame.sparkTexture:SetBlendMode("ADD")
      gcdFrame.sparkTexture:SetWidth(size)
      gcdFrame.sparkTexture:SetHeight(size)
    end
    gcdFrame.backgroundTexture:SetVertexColor(r, g, b)
    gcdFrame.backgroundTexture:SetAlpha(alpha)
    gcdFrame.backgroundTexture:SetWidth(size)
    gcdFrame.backgroundTexture:SetHeight(size)
    gcdFrame.backgroundTexture:SetShown(not self.db.profile.sparkOnly)
    gcdFrame.cooldown:SetWidth(size)
    gcdFrame.cooldown:SetHeight(size)
    gcdFrame.cooldown:SetSwipeTexture(addon.addonFolder .. "\\Textures\\gcd_ring_" .. self.db.profile.thickness)
    gcdFrame.cooldown:Hide()
    gcdFrame.sparkTexture:SetWidth(size)
    gcdFrame.sparkTexture:SetHeight(size)
    gcdFrame.sparkTexture:Hide()

    self:Hide()

    local cooldown = gcdFrame.cooldown
    cooldown:Clear()
    cooldown:SetSwipeColor(
      self.db.profile.barColor.r,
      self.db.profile.barColor.g,
      self.db.profile.barColor.b,
      self.db.profile.barColor.a
    )
    cooldown:SetEdgeScale(self.db.profile.radius / 23)
    cooldown:SetEdgeColor(
      self.db.profile.sparkColor.r,
      self.db.profile.sparkColor.g,
      self.db.profile.sparkColor.b,
      self.db.profile.sparkColor.a
    )
    cooldown:SetEdgeTexture(
      "Interface\\Cooldown\\edge",
      self.db.profile.sparkColor.r,
      self.db.profile.sparkColor.g,
      self.db.profile.sparkColor.b,
      self.db.profile.sparkColor.a
    )
    cooldown:SetUseCircularEdge(true)
    cooldown:SetSize(size, size)
    cooldown:SetDrawSwipe(not self.db.profile.sparkOnly)
    cooldown:SetDrawEdge(true)

    gcdFrame:SetScript("OnShow", function(frame)
      if frame.cooldown then frame.cooldown:Show() end
    end)
    gcdFrame:SetScript("OnHide", function(frame)
      if frame.cooldown then frame.cooldown:Hide() end
    end)
    gcdFrame:SetScript("OnUpdate", nil)
  end
end

function module:SPELL_UPDATE_COOLDOWN()
  self:ACTIONBAR_UPDATE_COOLDOWN()
end

function module:ACTIONBAR_UPDATE_COOLDOWN()
  if not gcdSpellNum or not gcdFrame or not gcdFrame.cooldown then
    return
  end

  local info = C_Spell.GetSpellCooldown(gcdSpellNum)

  -- isOnGCD est un booléen non-secret sur les versions récentes de Retail.
  -- Ne pas inspecter startTime/duration : ces champs peuvent être secrets.
  if info and info.isOnGCD then
    local duration = C_Spell.GetSpellCooldownDuration(gcdSpellNum)
    if duration then
      gcdFrame.cooldown:SetCooldownFromDurationObject(duration)
      self:Show()
      return
    end
  end

  gcdFrame.cooldown:Clear()
  self:Hide()
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
  if not C_Spell.DoesSpellExist(gcdSpellNum) then
    local _, class = UnitClass("player")
    local spellName = addon.GetSpellInfo(spells[class])
    gcdSpellNum = spellName and spells[class] or nil -- addon:GetSpellPosInSpellbook(spellName)
  end
end

function module:Unlock(cursor)
  if gcdFrame and not self.db.profile.sparkOnly then
    gcdFrame:SetParent(cursor)
    gcdFrame:SetAllPoints()
    gcdFrame:Show()
  end
end

function module:Lock()
  if gcdFrame and not self.db.profile.sparkOnly then
    gcdFrame:Hide()
    gcdFrame:SetParent(addon.anchor)
    gcdFrame:SetAllPoints()
  end
end
