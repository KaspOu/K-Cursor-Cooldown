---@diagnostic disable: undefined-global
local addon = LibStub("AceAddon-3.0"):GetAddon("CC")

-- Since The War Within (11)
-- Check for older API before newest
addon.BOOKTYPE_SPELL = BOOKTYPE_SPELL or Enum.SpellBookSpellBank.Player;
addon.BOOKTYPE_PET = BOOKTYPE_PET or Enum.SpellBookSpellBank.Pet;

addon.GetSpellCooldown = GetSpellCooldown or function(spellID)
  local spellCooldownInfo = C_Spell.GetSpellCooldown(spellID);
  if spellCooldownInfo then
    return spellCooldownInfo.startTime, spellCooldownInfo.duration, spellCooldownInfo.isOnGCD, spellCooldownInfo.isEnabled, spellCooldownInfo.modRate;
  end
  return nil
end

addon.GetSpellInfo = GetSpellInfo or function(spellID)
  if not spellID then
    return nil;
  end

  local spellInfo = C_Spell.GetSpellInfo(spellID);
  if addon.isSecret(spellInfo) then
    return "Secret", nil, 136085, 1249, 0, 45, 8936, 136085
  end
  if spellInfo then
    return spellInfo.name, nil, spellInfo.iconID, spellInfo.castTime, spellInfo.minRange, spellInfo.maxRange, spellInfo.spellID, spellInfo.originalIconID;
  end
end

addon.GetSpellTabInfo = GetSpellTabInfo or function(index)
  local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(index);
  if skillLineInfo then
    return	skillLineInfo.name,
        skillLineInfo.iconID,
        skillLineInfo.itemIndexOffset,
        skillLineInfo.numSpellBookItems,
        skillLineInfo.isGuild,
        skillLineInfo.offSpecID,
        skillLineInfo.shouldHide,
        skillLineInfo.specID;
  end
end

addon.GetNumSpellTabs = GetNumSpellTabs or C_SpellBook.GetNumSpellBookSkillLines;

addon.GetSpellBookItemName = GetSpellBookItemName or function(index, bookType)
  local spellBank = (bookType == addon.BOOKTYPE_SPELL) and Enum.SpellBookSpellBank.Player or Enum.SpellBookSpellBank.Pet;
  return C_SpellBook.GetSpellBookItemName(index, spellBank);
end

--[[
addon.Enum_SpellBookSpellBank_Pet = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet) or 1
addon.Enum_SpellBookSpellBank_Player = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
addon.IsSpellInSpellBook = C_SpellBook.IsSpellInSpellBook or function (spellID, spellBank)
  -- legit, can't coexist with C_SpellBook.IsSpellInSpellBook
  return IsSpellKnownOrOverridesKnown(spellID, spellBank == ns.Enum_SpellBookSpellBank_Pet and true or nil)
end
addon.IsSpellKnownOrInSpellBook = C_SpellBook.IsSpellKnownOrInSpellBook or addon.IsSpellInSpellBook
--]]