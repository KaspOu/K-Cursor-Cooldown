local addon = LibStub("AceAddon-3.0"):GetAddon("CC")
local module = addon:NewModule("cooldowns")
local media = LibStub("LibSharedMedia-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("CC")
local dbVersion = 1

local GetTime = GetTime
local cdFrames = {}
local options
local _, class = UnitClass("player")

local FrameHandler = {
  framePool = {}
}

function FrameHandler:CreateFrame(frameType, frameName, frameParent)
  local pool = self.framePool
  if not pool[frameType] then pool[frameType] = {} end

  local frame = tremove(pool[frameType]) or CreateFrame(frameType, frameName, frameParent)
  return frame
end

function FrameHandler:DeleteFrame(frame)
  frame:Hide()
  frame:ClearAllPoints()
  local frameType = frame:GetObjectType()

  local pool = self.framePool
  if not pool[frameType] then pool[frameType] = {} end

  tinsert(pool[frameType], frame)
end

local function deepcopy(object)
  local lookup_table = {}
  local function _copy(object)
    if type(object) ~= "table" then
      return object
    elseif lookup_table[object] then
      return lookup_table[object]
    end
    local new_table = {}
    lookup_table[object] = new_table
    for index, value in pairs(object) do
      new_table[_copy(index)] = _copy(value)
    end
    return setmetatable(new_table, _copy(getmetatable(object)))
  end
  return _copy(object)
end

local cdSpells = {
  ["DRUID"] = {
    {['spellID'] = 48438, ['pos'] = {['x'] = 0, ['y'] = 0}},
    {['spellID'] = 18562, ['pos'] = {['x'] = 0, ['y'] = 0}},
    },
  ["PRIEST"] = {
    {['spellID'] = 47540, ['pos'] = {['x'] = 0, ['y'] = 0}},
    {['spellID'] = 586, ['pos'] = {['x'] = 0, ['y'] = 0}},
    {['spellID'] = 34433, ['pos'] = {['x'] = 0, ['y'] = 0}},
  },
  ["SHAMAN"] = {
    {['spellID'] = 32182, ['pos'] = {['x'] = 0, ['y'] = 0}},
  },
  ["MAGE"] = {
    {['spellID'] = 80353, ['pos'] = {['x'] = 0, ['y'] = 0}},
  }
}

local englishFaction, localizedFaction = UnitFactionGroup("player")

if englishFaction == "Horde" then
  cdSpells["SHAMAN"][1]['spellID'] = 2825
end

local defaults = {
  char = {
    cdSpells = cdSpells[class] or {}
  },
  profile = {
    size = 15,
    font = "Calibri",
    fontSize = 11
  }
}

function module:OnEnable()
  self:SPELLS_CHANGED()
  self:ACTIONBAR_UPDATE_COOLDOWN()
  self:RegisterEvent("SPELLS_CHANGED")
  self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
end

function module:OnDisable()
  self:UnregisterAllEvents()
  for _, v in ipairs(cdFrames) do
    self:Hide(v.frame)
  end
end

function module:FixDatabase()
  if not self.db.profile.version then -- first time logging in OR unversioned database
    if self.db.char and (self.db.char.size or self.db.char.font or self.db.char.fontSize) then -- unversioned database
      self.db.profile.size = self.db.char.size or defaults.profile.size
      self.db.profile.font = self.db.char.font or defaults.profile.font
      self.db.profile.fontSize = self.db.char.fontSize or defaults.profile.fontSize
      self.db.profile.version = 1
    end
  end
  if self.db.profile.version then
    -- nothing to do yet
  end
  self.db.profile.version = dbVersion
end

function module:OnInitialize()
  for i, v in ipairs(defaults.char.cdSpells) do
    v.pos.x = cos(((i - 1) / #defaults.char.cdSpells ) * 360) * 36
    v.pos.y = sin(((i - 1) / #defaults.char.cdSpells ) * 360) * 36
  end

  self.db = addon.db:RegisterNamespace("Cooldowns", defaults)
  self:FixDatabase()
  self:PopulateCdSpellsOptions()
end

function module:PopulateCdSpellsOptions()
  local cdSpells = self.db.char.cdSpells
  for _, v in pairs(options.args.spells.args.list) do
    v = nil
  end
  for i, v in ipairs(cdSpells) do
    if v.spellID ~= nil then

      local arg = {

        name = tostring(addon.GetSpellInfo(v.spellID) or "Not found"),
        type = "group",
        args = {
          xPos = {
            name = L["x-Offset"],
            type = "input",
            get = function()
              if cdSpells[i] then
                return tostring(cdSpells[i].pos.x)
              end
            end,
            set = function(info, value)
              cdSpells[i].pos.x = tonumber(value)
            end,
            validate = function(info, value) if tonumber(value) == nil then return "That's not a number!" end return true end,
            order = 1
          },
          yPos = {
            name = L["y-Offset"],
            type = "input",
            get = function() 
              if cdSpells[i] then
                return tostring(cdSpells[i].pos.y) 
              end
            end,
            set = function(info, value) cdSpells[i].pos.y = tonumber(value) end,
            validate = function(info, value) if tonumber(value) == nil then return "That's not a number!" end return true end,
            order = 2
          },
          remove = {
            name = L["Remove Spell"],
            type = "execute",
            func = function()
              tremove(cdSpells, i)
              options.args.spells.args[tostring(i)] = nil
              self:SPELLS_CHANGED()
              self:PopulateCdSpellsOptions()
            end,
            order = 3
          }
        }
      }
      options.args.spells.args.list.args[tostring(i)] = arg
		else
			table.remove(cdSpells, i)
		end
  end
end

function module:GetOptions()
  options = {
    name = L["Spellcds"],
    type = "group",
    args = {
      disp = {
        name = L["Display"],
        type = "header",
        order = 1
      },
      size = {
        name = L["Icon size"],
        type = "range",
        disabled = function() return not addon.db.profile.modules.cooldowns end,
        min = 5,
        max = 50,
        step = 1,
        get = function() return self.db.profile.size end,
        set = function(info, value)
          self.db.profile.size = value
          self:ApplyOptions()
        end,
        order = 2
      },
      fontHeader = {
        name = L["Text"],
        type = "header",
        order = 10
      },
      font = {
        name = L["Font"],
        type = "select",
        disabled = function() return not addon.db.profile.modules.cooldowns end,
        dialogControl = 'LSM30_Font',
        get = function() return self.db.profile.font end,
        set = function(_, value)
          self.db.profile.font = value
          self:ApplyOptions()
        end,
        values = media:HashTable("font"),
        order = 11
      },
      fontSize = {
        name = L["Font Size"],
        type = "range",
        disabled = function() return not addon.db.profile.modules.cooldowns end,
        min = 1,
        max = 30,
        step = 1,
        get = function() return self.db.profile.fontSize end,
        set = function(_, value)
          self.db.profile.fontSize = value
          self:ApplyOptions()
        end,
        order = 12
      },
      spells = {
        name = L["Spells"],
        type = "group",
        childGroups = "tab",
        disabled = function() return not addon.db.profile.modules.cooldowns end,
        args = {
          add = {
            name = L["Add Spell"],
            type = "input",
            disabled = function() return not addon.db.profile.modules.cooldowns end,
            get = false,
            set = function(info, value)
              if not tonumber(value) then
                local _, _, _, _, _, _, spellId = addon.GetSpellInfo(value)
                value = spellId
              end
              tinsert(self.db.char.cdSpells, {['spellID'] = tonumber(value), ['pos'] = {['x'] = 0, ['y'] = 0}})
              self:PopulateCdSpellsOptions()
              self:SPELLS_CHANGED()
            end,
            validate = function(info, value)
              local spellName = addon.GetSpellInfo(value)
              if not spellName then return false end
              if addon:GetSpellPosInSpellbook(spellName) then
                return true
              else
                return string.format("%s is not a spell you possess!", value)
              end
            end,
            order = 1
          },
          arrange = {
            name = L["Auto arrange icons"],
            type = "execute",
            disabled = function() return not addon.db.profile.modules.cooldowns end,
            func = function()
              for i, v in ipairs(self.db.char.cdSpells) do
                v.pos.x = cos(((i - 1) / #self.db.char.cdSpells ) * 360) * 36
                v.pos.y = sin(((i - 1) / #self.db.char.cdSpells ) * 360) * 36
              end
              self:ApplyOptions()
            end,
            order = 2
          },
          list = {
            name = L["Spells"],
            type = "group",
            disabled = function() return not addon.db.profile.modules.cooldowns end,
            args = {}
          }
        }
      },
      misc = {
        name = L["Miscellaneous"],
        type = "header",
        order = 20
      },
      defaults = {
        name = L["Restore defaults"],
        type = "execute",
        disabled = function() return not addon.db.profile.modules.cooldowns end,
        func = function()
          self.db = deepcopy(defaults)
          self:SPELLS_CHANGED()
        end,
        order = 21
      }
    }
  }
  return options
end

function module:ACTIONBAR_UPDATE_COOLDOWN()
    local _, gcdLeft
    gcdLeft = addon.GetSpellCooldown(61304)
    for _, v in ipairs(cdFrames) do
      local spell = addon.GetSpellBookItemName(v.spell, addon.BOOKTYPE_SPELL)
      local start, dur = addon.GetSpellCooldown(spell)
      if type(dur) == "number" and type(gcdLeft) == "number" then
        if dur > gcdLeft then
          v.frame.startTime = start
          v.frame.duration = dur
          self:Show(v.frame)
        end
      end
    end
end

function module:SPELLS_CHANGED()
  for _, v in ipairs(cdFrames) do
    if v.frame then FrameHandler:DeleteFrame(v.frame) end
  end
  cdFrames = {}
  for _, v in ipairs(self.db.char.cdSpells) do
    local spell, _, icon = addon.GetSpellInfo(v.spellID)
    if not not spell then
      local spellPos = addon:GetSpellPosInSpellbook(spell)
      if spellPos then
        tinsert(cdFrames, {['spell'] = spellPos, ['icon'] = icon, ['pos'] = v.pos}) -- Links frame offset to database value
      end
    end
  end
  self:ApplyOptions()
end

local framesVisible = {}
function module:Show(frame)
  framesVisible[frame] = true
  addon:Show("cooldowns")
  frame:Show()
end

function module:Hide(frame)
  framesVisible[frame] = false
  local hide = true
  for _, v in pairs(framesVisible) do
    if v then
      hide = false
    end
  end
  if hide then
    addon:Hide("cooldowns")
    framesVisible = {}
  end
  frame:Hide()
end

local function OnUpdate(self, elapsed)
  if not self.startTime or not self.duration or self.duration <= 0 then print("exit") return end
  local perc = (GetTime() - self.startTime) / self.duration
  self.texture:SetVertexColor(1.0, perc, perc)
  local dur = floor((self.duration - (GetTime() - self.startTime)) * 10) / 10
  if dur > 99 then
    dur = '>>'
  elseif dur > 10 then
    dur = ceil(dur)
  end
  self.cdText:SetText(dur)
  if perc >= 1 then
    module:Hide(self)
  end
end

function module:ApplyOptions()
  local anchor = addon.anchor
  if self:IsEnabled() then
    for i, v in ipairs(cdFrames) do
      if not v.frame then
        local frame = FrameHandler:CreateFrame('Frame')
        frame:SetParent(anchor)
        frame:SetFrameStrata('HIGH')
        frame:SetScript('OnUpdate', OnUpdate)

        frame.texture = frame.texture or frame:CreateTexture(nil, 'ARTWORK')
        frame.texture:SetVertexColor(1, 0, 0)
        frame.texture:SetPoint('CENTER', frame, 'CENTER')

        frame.cdText = frame.cdText or frame:CreateFontString()
        frame.cdText:SetPoint('CENTER', frame, 'CENTER', 0, 1)

        v.frame = frame
      end
      v.frame:SetWidth(self.db.profile.size * v.frame:GetEffectiveScale())
      v.frame:SetHeight(self.db.profile.size * v.frame:GetEffectiveScale())
      v.frame:ClearAllPoints()
      v.frame:SetPoint("CENTER", anchor, "CENTER", v.pos.x, v.pos.y)
      v.frame.texture:SetTexture(v.icon)
      v.frame.texture:SetWidth(self.db.profile.size * v.frame:GetEffectiveScale())
      v.frame.texture:SetHeight(self.db.profile.size * v.frame:GetEffectiveScale())
      v.frame.cdText:SetFont(media:Fetch("font", self.db.profile.font), self.db.profile.fontSize, "OUTLINE, MONOCHROME")
      self:Hide(v.frame)
    end
  end
end

function module:Unlock(cursor)
  for i, v in ipairs(cdFrames) do
    self:Hide(v.frame)
    v.frame:SetScript('OnUpdate', nil)
    v.frame:ClearAllPoints()
    v.frame:SetParent(cursor)
    v.frame:SetPoint('CENTER', cursor, 'CENTER', (v.pos.x) / v.frame:GetEffectiveScale(), (v.pos.y) / v.frame:GetEffectiveScale())
    v.frame.texture:SetVertexColor(1.0, 1.0, 1.0)
    v.frame.cdText:SetText("")
    v.frame:Show()
    v.frame:SetMovable(true)
    v.frame:EnableMouse(true)
    v.frame:SetScript("OnMouseDown", v.frame.StartMoving)
    v.frame:SetScript("OnMouseUp", v.frame.StopMovingOrSizing)
  end
end

function module:Lock()
  for i, v in ipairs(cdFrames) do
    v.frame:Hide()
    v.frame:EnableMouse(false)
    v.frame:SetMovable(false)
    v.frame:SetScript("OnMouseDown", nil)
    v.frame:SetScript("OnMouseUp", nil)
    v.frame:SetScript('OnUpdate', OnUpdate)

    local cursor = v.frame:GetParent()
    local x, y = v.frame:GetCenter()
    local cx, cy = cursor:GetCenter()
    v.pos.x = x - cx
    v.pos.y = y - cy

    v.frame:ClearAllPoints()
    v.frame:SetParent(addon.anchor)
    v.frame:SetPoint("CENTER", addon.anchor, "CENTER", v.pos.x, v.pos.y)
  end
end
