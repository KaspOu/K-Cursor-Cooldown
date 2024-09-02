local addon = LibStub("AceAddon-3.0"):NewAddon("CC", "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("CC")
local ACD = LibStub("AceConfigDialog-3.0")
local dbVersion = 1

addon:SetDefaultModuleState(false)
addon:SetDefaultModuleLibraries("AceEvent-3.0")

local defaults, options
local showRequests = {}

function addon:Show(name)
	showRequests[name] = true
	self.anchor:Show()
end

function addon:Hide(name)
	showRequests[name] = false

	local hide = true
	for _,v in pairs(showRequests) do
		if v then
			hide = false
		end
	end
	if hide then
		self.anchor:Hide()
	end
end

function addon:GetSpellPosInSpellbook(spellName)
	local spellNum = nil
	for tab = 1, addon.GetNumSpellTabs() do
		local _, _, offset, numSpells = addon.GetSpellTabInfo(tab)
		for i = (1+offset), (offset+numSpells) do
			local spell = addon.GetSpellBookItemName(i, addon.BOOKTYPE_SPELL)
			if spell then
				if string.lower(spell) == string.lower(spellName) then
					spellNum = i
					break
				end
			end
		end
	end
	return spellNum;
end

function addon:InitializeDefaults()
	defaults = {
		profile = {
			offset = {
				x = 12,
				y = -12
			},
			position = {
				x = 400,
				y = 400
			},
			attachToMouse = true,
			modules = {}
		}
	}

	for name, module in self:IterateModules() do
		defaults.profile.modules[name] = true
	end
end

function addon:InitializeOptions()
	options = {
		name = "Cursor Cooldown Reloaded",
		type = "group",
		args = {
			unlock = {
				name = L["Unlock"],
				type = "execute",
				func = function() addon:Unlock() end,
				order = 1
			},
			info = {
				name = L["All specified colors are vertex colors! (see wowwiki.com)"],
				type = "description",
				order = 2
			},
			general = {
				name = L["General"],
				type = "group",
				args = {
					position = {
						name = L["Position"],
						type = "header",
						order = 0
					},
					mouse = {
						name = L["Attach to cursor"],
						type = "toggle",
						get = function(info) return self.db.profile.attachToMouse end,
						set = function(info,val)
								self.db.profile.attachToMouse = val
							end,
						order = 1
					},
					xOff = {
						name = L["Horizontal Offset"],
						type = "range",
						min = 0,
						max = 64,
						step = 1,
						disabled = function() return not self.db.profile.attachToMouse end,
						get = function(info) return self.db.profile.offset.x end,
						set = function(info, val)
									self.db.profile.offset.x = val
								end,
						order = 2
					},
					yOff = {
						name = L["Vertical Offset"],
						type = "range",
						min = -64,
						max = 0,
						step = 1,
						disabled = function() return not self.db.profile.attachToMouse end,
						get = function(info) return self.db.profile.offset.y end,
						set = function(info, val)
									self.db.profile.offset.y = val
								end,
						order = 3
					},
					x = {
						name = L["Left"],
						type = "input",
						disabled = function() return self.db.profile.attachToMouse end,
						get = function(info) return tostring(self.db.profile.position.x) end,
						set = function(info, val)
									self.db.profile.position.x = tonumber(val)
									self:ApplyOptions()
								end,
						validate = function(_, value)
											if tonumber(value) then
												return true
											else
												return L["Left has to be a number!"]
											end
										end,
						order = 4
					},
					y = {
						name = L["Bottom"],
						type = "input",
						disabled = function() return self.db.profile.attachToMouse end,
						get = function(info) return tostring(self.db.profile.position.y) end,
						set = function(info, val)
									self.db.profile.position.y = tonumber(val)
									self:ApplyOptions()
								end,
						validate = function(_, value)
											if tonumber(value) then
												return true
											else
												return L["Bottom has to be a number!"]
											end
										end,
						order = 5
					},

				},
				order = 10
			}
		}
	}
	local i = 2
	for name, module in self:IterateModules() do
		local modOptions = module:GetOptions()
		modOptions.order = i*10
		modOptions.args.enabled = {
			name = L["Enabled"],
			type = "toggle",
			get = function(info) return self.db.profile.modules[name] end,
			set = function(info,val)
					self.db.profile.modules[name] = val
					if val then
						self:GetModule(name):Enable()
					else
						self:GetModule(name):Disable()
					end
				end,
			order = 0
		}
		options.args[name] = modOptions
		i = i + 1
	end
	options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
end

local function OnUpdate(self, elapsed)
	local x, y, xOff, yOff
	if addon.db.profile.attachToMouse then
		x, y = GetCursorPosition(UIParent);
		x = x + addon.db.profile.offset.x
		y = y + addon.db.profile.offset.y
	else
		x, y = addon.db.profile.position.x, addon.db.profile.position.y
	end
	self:ClearAllPoints()
	self:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', x / self:GetEffectiveScale(), y / self:GetEffectiveScale())
end

function addon:FixDatabase()
	if not self.db.profile.version then -- first time logging in OR unversioned database
		if self.db.char  then -- unversioned database
			if self.db.char.attachToMouse ~= nil then
				self.db.profile.attachToMouse = self.db.char.attachToMouse
			end
			for i,v in pairs(self.db.profile.modules) do
				if self.db.char.modules and self.db.char.modules[i] ~= nil then
					self.db.profile.modules[i] = self.db.char.modules[i]
				end
			end
			self.db.char = nil
			self.db.profile.version = 1
		end
	end
	if self.db.profile.version then
		-- nothing to do yet
	end
	self.db.profile.version = dbVersion
end

function addon:OnInitialize()
	self:InitializeDefaults()
	self.db = LibStub("AceDB-3.0"):New("CursorCooldownDB", defaults)
	self:FixDatabase()

	self:InitializeOptions()
	LibStub("AceConfig-3.0"):RegisterOptionsTable("CC", options)
	ACD:SetDefaultSize("CC", 640, 480)
	ACD:AddToBlizOptions("CC", "Cursor Cooldown")
	self:RegisterChatCommand("gcd", self.OpenConfig)
	self:RegisterChatCommand("cc", self.OpenConfig)
end

function addon:OnEnable()
	self:ApplyOptions()
	for name, _ in self:IterateModules() do
			if self.db.profile.modules[name] then
				self:EnableModule(name)
			end
	end
	return true
end

function addon:OnDisable()
	if self.anchor then self.anchor:Hide() end
	for _, module in self:IterateModules() do
		if module:IsEnabled() then
			module:Disable()
		end
	end
	self:UnregisterAllEvents()
	return true
end

function addon:ApplyOptions()
	local anchor = self.anchor or CreateFrame("Frame")
	anchor:Hide()
	anchor:ClearAllPoints()
	anchor:SetFrameStrata("HIGH")
	anchor:SetScript('OnUpdate', OnUpdate)
	anchor:SetWidth(64)
	anchor:SetHeight(64)

	self.anchor = anchor


end

function addon:OpenConfig()
	ACD:Open("CC")
end

--[[
		Unlock
]]

local cursorBackdrop = {bgFile = "Interface/Tooltips/UI-Tooltip-Background",
							edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
							tile = true, tileSize = 16, edgeSize = 16,
							insets = { left = 4, right = 4, top = 4, bottom = 4 }}
local cursorFrame

function addon:Unlock()
	local unlocked = false
	for name, module in self:IterateModules() do
		if self.db.profile.modules[name] and module.Unlock then
			unlocked = true
		end
	end
	if unlocked then
		local cursor = cursorFrame or CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
		cursor:SetWidth(20)
		cursor:SetHeight(20)
		cursor:SetBackdrop(cursorBackdrop)
		cursor:SetBackdropColor(255,0,0,1)
		cursor:SetFrameStrata('HIGH')
		cursor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.db.profile.position.x / cursor:GetEffectiveScale(), self.db.profile.position.y / cursor:GetEffectiveScale())
		cursor:SetScript("OnMouseDown", cursor.StartMoving)
		cursor:SetScript("OnMouseUp", function(self, button)
											self:StopMovingOrSizing()
											if button == "RightButton" then
												local x, y = self:GetCenter()
												addon.db.profile.position.x, addon.db.profile.position.y = math.floor(x* cursor:GetEffectiveScale()), math.floor(y* cursor:GetEffectiveScale())
												addon.db.profile.attachToMouse = false;
												self:Hide()
												for name, module in addon:IterateModules() do
													if addon.db.profile.modules[name] and module.Lock then
														module:Lock()
													end
												end
											end
										end)
		cursor:SetScript("OnEnter", function(self)
										GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
										GameTooltip:SetText("Right Click")
										GameTooltip:AddLine("to lock the icons and save their positions", 1, 1, 1)
										GameTooltip:Show()
									end)
		cursor:SetScript("OnLeave", function(self)
										GameTooltip:Hide()
									end)
		cursor:SetMovable(true)
		cursor:EnableMouse(true)
		cursor:Show()

		for name, module in self:IterateModules() do
			if self.db.profile.modules[name] and module.Unlock then
				module:Unlock(cursor)
			end
		end

		ACD:Close("CC")
		return true
	else
		return L["All unlockable modules are disabled!"]
	end
end
