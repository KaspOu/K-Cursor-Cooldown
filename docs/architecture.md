# CursorCooldown — Architecture

Technical reference for **CursorCooldown** ("Cursor Cooldown Reloaded", internal name `CC`): a World
of Warcraft addon that draws cooldown sweeps (global cooldown, cast time, swing timer, tracked spell
cooldowns) around the mouse cursor. Written 2026-11-01 from a full read of the source; every claim
below comes from the code in this repository. Companion document: [../AGENTS.md](../AGENTS.md).

## 1. General architecture

The addon is a single Ace3 addon (`CC`) with five Ace3 modules (`cast`, `cooldowns`, `gcd`, `ring`,
`swing`) and one shared widget factory (`addon.donut`). There is no XML-defined UI: the only XML
files are load manifests. All frames and textures are created in Lua and anchored to one invisible
64×64 `anchor` frame that follows the mouse cursor (or a fixed position).

```
CursorCooldown.toc
  └─ embeds.xml            LibStub, CallbackHandler, Ace* libs, LibSharedMedia, SM widgets
  └─ Localization/*.lua    AceLocale "CC" (enUS seeds; other 10 gated per client locale)
  └─ GCD.lua               addon core: DB, options tree, anchor, role filter, unlock, secrets
  └─ GCD.polyfill.lua      legacy→modern API wrappers, attached to the addon object
  └─ donut.lua             addon.donut: quarter-segment arc renderer widget
  └─ modules.xml
       ├─ Modules/Cast.lua        cast bar sweep + spark + spell text + latency arc
       ├─ Modules/Cooldowns.lua   tracked spell cooldown icons around the cursor
       ├─ Modules/GCD.lua         global cooldown sweep + spark
       ├─ Modules/Ring.lua        rotating decorative ring overlay
       └─ Modules/Swing.lua       melee/ranged swing timer sweep (disabled on retail 12)
```

Data flows one way: event/API values → module state (file-scope locals + `frame` fields) → `OnUpdate`
routines that redraw every frame while visible. Options flow the other way: AceConfig callbacks →
`self.db.profile.*` → `module:ApplyOptions()`.

## 2. XML ↔ Lua relationship

- `embeds.xml` — `<Script>`/`<Include>` list for the vendored libraries. Its content is wrapped in
  `#@no-lib-strip@ … #@end-no-lib-strip@` in the TOC so packagers can strip embedded libs.
- `modules.xml` — `<Script>` list for the five modules, in dependency-neutral order (each file just
  registers its module; wiring happens at init).
- There is **no** XML UI, no templates, no `parentKey` wiring. Adding XML UI would be a new pattern
  for this codebase.

## 3. File roles

| File | Role |
| --- | --- |
| `CursorCooldown.toc` | load order, metadata, SavedVariables (`CursorCooldownDB`, `CC_Settings`), per-locale gating (`[AllowLoadTextLocale …]`) |
| `GCD.lua` | addon object (`NewAddon("CC", "AceConsole-3.0", "AceEvent-3.0")`), defaults, `FixDatabase`, AceConfig options tree, module enable/disable loop, `anchor` + `OnUpdate` positioning, role filter (`IsRoleFiltered`/`RefreshRoleFilter`), Addon Compartment registration, unlock frame, `addon.isSecret`, `addon.BlizzardCastingBarFrame`, `addon.addonFolder` |
| `GCD.polyfill.lua` | fills `addon.GetSpellInfo`, `addon.GetSpellTabInfo`, `addon.GetNumSpellTabs`, `addon.GetSpellBookItemName`, `addon.BOOKTYPE_SPELL/PET` — legacy globals when present, `C_Spell`/`C_SpellBook` wrappers otherwise (incl. secret-value fallbacks) |
| `donut.lua` | `addon.donut:New(direction, radius, thickness, color, bgColor, frame)` factory: builds background quarter textures, three full-quarter segments and a red/blue/slice triad; `SetAngle(degree)` picks one of four quarter layouts × two directions and computes texcoords |
| `Modules/Cast.lua` | tracks player casts/channels/empowers; donut sweep + latency arc + rotating spark + spell name text; can hide and hand-rebuild the Blizzard casting bar (`hideCastBar`) |
| `Modules/Cooldowns.lua` | per-character list of tracked spells (`char.cdSpells`), spellbook-position keyed icon frames with a frame pool (`FrameHandler`), countdown text, "Since Midnight (12)" secret-safe rendering path (`C_CurveUtil`, `durationObject`) |
| `Modules/GCD.lua` | watches the GCD (`C_Spell.GetSpellCooldown` on spell 61304, falling back to class starter spells) and drives the sweep + spark |
| `Modules/Ring.lua` | rotating ring texture (LibSharedMedia-free, file IDs or custom paths), visibility modes (`gcd_casting`, `combat`, `raid`, `party_raid`, `always`) |
| `Modules/Swing.lua` | swing timer from `COMBAT_LOG_EVENT_UNFILTERED` (`SWING_DAMAGE`/`SWING_MISSED`, parry-haste `×0.6`) and `UnitAttackSpeed`/`UnitRangedDamage`; Warrior Slam swing-reset; **early-returns at file load on clients with secret values (retail 12+)** |
| `Localization/*.lua` | AceLocale tables; every non-English file starts with `if CC_Settings and CC_Settings.ForceEnglish then return end` |
| `.pkgmeta` | packaging: `package-as: CursorCooldown`, `externals` for the Ace3/LibSharedMedia libs, ignores `.vscode`, `.release*`, `.git*`, `.icon*`, `.logo*` |
| `.release/` | build outputs: packaged `CursorCooldown/` tree + release zips. Not source |

## 4. Lifecycle

1. **SavedVariables load first** (`## LoadSavedVariablesFirst: 1`) — `CC_Settings` and
   `CursorCooldownDB` are readable at file load. `GCD.lua` does `CC_Settings = CC_Settings or {}`,
   and the locale files read `CC_Settings.ForceEnglish` at load (hence the `/reload` requirement on
   that option).
2. **File load** (TOC order): `GCD.lua` creates the addon `CC`; module files call `NewModule`;
   `GCD.polyfill.lua` fills the API wrappers; `donut.lua` installs the factory.
   `addon.addonFolder` is built from `C_AddOns.GetAddOnInfo("CursorCooldown")` (hardcoded folder
   name) and `addon.BlizzardCastingBarFrame` is bound to `PlayerCastingBarFrame`.
3. **`ADDON_LOADED` → AceAddon init queue** — the root addon is initialized **before** its modules
   (verified in `Libs/AceAddon-3.0`: modules join the same FIFO initialize queue after their
   creator). Order: `CC:OnInitialize` → `cast` → `cooldowns` → `gcd` → `ring` → `swing`.
   - `CC:OnInitialize`: `InitializeDefaults` (profile defaults incl. `modules[name] = true` per
     registered module), AceDB `New("CursorCooldownDB", defaults)`, `FixDatabase` (legacy
     char→profile migration, role-filter defaults, `ForceEnglish` default, `profile.version`
     stamp), `InitializeOptions` (builds the options tree, calls each module's `GetOptions()`,
     appends AceDBOptions profiles UI), `RegisterCompartment`, registers `/gcd`, `/cc`, `/ccr`,
     `/ccd`.
   - `module:OnInitialize`: namespace registration (`RegisterNamespace`) + `FixDatabase` + optional
     `GetModule("ring", true)` lookup. Note `Cooldowns` also pre-arranges default icon positions
     here and populates its spell options (`PopulateCdSpellsOptions`) — safe because `GetOptions()`
     already ran during `CC:OnInitialize`.
4. **`PLAYER_LOGIN` → enable** — `CC:OnEnable` runs `ApplyOptions()` (creates the anchor), registers
   `PLAYER_SPECIALIZATION_CHANGED`, then enables each module whose `db.profile.modules[name]` is
   true, then `RefreshRoleFilter()`. Modules whose profile flag is false stay disabled
   (`SetDefaultModuleState(false)`).
5. **Runtime** — events update module state; `OnUpdate` handlers on the visible frames redraw the
   sweep/spark/text every frame. `addon:Show(name)`/`addon:Hide(name)` reference-count module
   visibility on the shared anchor.
6. **`OnDisable`** — modules unregister events, hide frames; the core hides the anchor and disables
   all modules. (Gap: `Cast`'s `hideCastBar` state is not restored here — see §10.)

## 5. Main functions and responsibilities

### Core (`GCD.lua`)

- `addon:Show(name)` / `addon:Hide(name)` — anchor visibility request table (`showRequests`), gated
  by the role filter.
- `addon:InitializeDefaults` / `InitializeOptions` / `FixDatabase` — defaults, AceConfig tree,
  versioned DB migration (`dbVersion = 1`).
- `addon:IsRoleFiltered()` / `RefreshRoleFilter()` — hides everything when the current spec's role
  (`GetSpecializationRole`) is unchecked in the Filter options.
- `addon:RegisterCompartment()` — one-shot Addon Compartment entry (`_compartmentRegistered` latch).
- `addon:Unlock()` / lock callback — movable 20×20 cursor frame; right-click saves position to
  `db.profile.position`, turns off `attachToMouse`, calls each module's `Lock()`.
- `OnUpdate` (anchor) — repositions to `GetCursorPosition()` (+`db.profile.offset`) or the fixed
  position, scaled by `GetEffectiveScale()`.
- `addon.isSecret(value)` — retail-12 secret-value detection (`issecretvalue`/`issecrettable`),
  false stub otherwise.

### Modules (shared contract)

`OnInitialize` (DB + deps) · `GetOptions()` (AceConfig group; core injects the `enabled` toggle) ·
`ApplyOptions()` (build/refresh frames from `db.profile`) · `OnEnable`/`OnDisable` (events) ·
`Show`/`Hide` (visibility requests) · `Unlock(cursor)`/`Lock()` (re-parent to/from the unlock frame).
`Cast` and `Swing` also define a private `RegisterUnitEvent` shim (a dispatch frame mapping event
names to `module[evt]` handlers) — duplicated verbatim in both files.

### `donut.lua`

`SetAngle(degree)` is the heart: clamps to 0–360, computes the quarter (1–4) and the inner/outer
intercept coordinates from `thickness`/`radius`, then assigns texcoords and anchors to the `red`
(remaining), `blue` (progress) and `slice` (edge) textures per direction. `SetThickness` swaps
`Textures/segment_<thickness>` textures (15/20/25/30/35 shipped). Degree 0 or 90 hides the slice.

## 6. WoW events used

| Where | Events | Notes |
| --- | --- | --- |
| core | `PLAYER_SPECIALIZATION_CHANGED` | → `RefreshRoleFilter` |
| `cast` | `UNIT_SPELLCAST_SENT`, `_SUCCEEDED`, `_START`, `_STOP`, `_INTERRUPTED`, `_FAILED`, `_DELAYED`, `_CHANNEL_START`, `_CHANNEL_STOP`, `_CHANNEL_UPDATE`, and `_EMPOWER_START/_STOP/_UPDATE` when `RAID_CLASS_COLORS.EVOKER` exists | registered for `player` via the dispatch shim |
| `cooldowns` | `SPELLS_CHANGED`, `ACTIONBAR_UPDATE_COOLDOWN`, `SPELL_UPDATE_COOLDOWN` | the last only when secrets are absent |
| `gcd` | `ACTIONBAR_UPDATE_COOLDOWN`, `SPELLS_CHANGED` | `SPELLS_CHANGED` re-resolves the GCD spell |
| `ring` | `PLAYER_REGEN_ENABLED`, `PLAYER_REGEN_DISABLED`, `GROUP_JOINED`, `GROUP_LEFT` | → `UpdateVisibility` |
| `swing` | `PLAYER_ENTER_COMBAT`, `PLAYER_LEAVE_COMBAT`, `START_AUTOREPEAT_SPELL`, `STOP_AUTOREPEAT_SPELL`, `COMBAT_LOG_EVENT_UNFILTERED` (registered on demand), `UNIT_SPELLCAST_SUCCEEDED/_START/_INTERRUPTED` (player), `UNIT_ATTACK` (player) | file does not load on retail 12+ |

## 7. UI composition and rendering

- **Anchor** (`GCD.lua`): 64×64, strata `HIGH`, hidden unless a module requests it; its `OnUpdate`
  does the cursor attachment every frame.
- **Cast** (`castFrame`, child of anchor): `donut` (bar color) + `latencyDonut` (latency color, laid
  beneath, both drawn from `addon.donut`), `sparkTexture` (Blizzard casting spark, rotated by the
  sweep angle, colored red when inside the latency window in `sparkOnly` mode), `spellText`
  fontstring (LibSharedMedia font, offset by `spellText.relativeX/Y`).
- **GCD / Swing**: same pattern with one donut + spark.
- **Cooldowns**: pooled icon frames (`FrameHandler` pool keyed by object type) centered at
  `db.char.cdSpells[i].pos` around the anchor, with a countdown fontstring. On retail 12+ the
  `hasSecrets` branch renders via `C_CurveUtil` color curves and `durationObject` instead of
  computed angles.
- **Ring**: one `ARTWORK` texture, optionally rotated 0.5° every 0.02 s (`OnUpdate`).
- **Unlock flow**: module frames re-parent onto the movable cursor frame and show static test angles
  (cast 320°+60°, GCD 195°, swing 115°, cooldowns spread at their saved offsets).

## 8. Data management

- `CursorCooldownDB` (AceDB-3.0, `LoadSavedVariablesFirst: 1`):
  - root `profile` (core): `offset`, `position`, `attachToMouse`, `compartmentFilter`,
    `filterByRole`, `filterRoles{TANK/HEALER/DAMAGER}`, `modules{}`, `version`.
  - namespaces: `Cast` (colors, radius, thickness, sparkOnly, spellText, hideCastBar),
    `Cooldowns` (`profile.size/font/fontSize`, `char.cdSpells` = per-character tracked spell list),
    `CC` (the `gcd` module: colors, radius, thickness, sparkOnly), `Ring` (color, texture, rotate,
    width, visibility), `Swing` (same shape as GCD). Each namespace stamps `profile.version`
    (`dbVersion = 1` in every module; migrations so far only upgrade unversioned char→profile data).
  - AceDBOptions "profiles" UI is appended to the options tree (profile copy/reset).
- `CC_Settings` (plain saved table): only `ForceEnglish`, read at file load by every non-English
  locale file.
- "Restore defaults" is implemented as `db:ResetProfile()` in cast/gcd/ring/swing but as
  `self.db = deepcopy(defaults)` in `cooldowns` (see §10).

## 9. Dependencies

**Internal (cross-file contracts):** `addon.donut` (factory), `addon.isSecret`, the polyfill fields
(`addon.GetSpellInfo` …), `addon.addonFolder`, `addon.anchor`, `addon.BlizzardCastingBarFrame`,
`ringMod = addon:GetModule("ring", true)` used by cast/gcd/swing to piggyback the ring's visibility
requests, and the `showRequests`/`framesVisible` visibility tables.

**Vendored (Libs/, do not edit):** LibStub, CallbackHandler-1.0, AceAddon-3.0, AceEvent-3.0,
AceDB-3.0, AceDBOptions-3.0, AceConsole-3.0, AceGUI-3.0, AceLocale-3.0, AceConfig-3.0,
LibSharedMedia-3.0 (fonts incl. the default `"2002 Bold"` → `Fonts\2002B.TTF`), and
AceGUI-3.0-SharedMediaWidgets (the `LSM30_Font` dropdown control).

**Blizzard API surface:** `C_Spell`, `C_SpellBook`, `C_CombatLog`, `C_CurveUtil` (12+),
`C_AddOns.GetAddOnInfo/GetAddOnMetadata`, `UnitCastingInfo`, `UnitChannelInfo`, `UnitAttackSpeed`,
`UnitRangedDamage`, `UnitDamage`, `UnitClass`, `UnitFactionGroup`, `UnitGUID`,
`GetSpecialization`/`GetSpecializationRole`, `GetCursorPosition`, `GetTime`, `GetBuildInfo`,
`IsInRaid`, `IsInGroup`, `UnitAffectingCombat`, `PlayerCastingBarFrame`, `AddonCompartmentFrame`,
`GameTooltip`, `RAID_CLASS_COLORS`, `CreateFrame`/`CreateTexture`, `BackdropTemplate`, and the
legacy spellbook globals the polyfill mirrors.

## 10. Inconsistencies, redundancies and regression risks

Found during the 2026-11-01 analysis/audit (report-only — none fixed; the full report is in
[backlog.md](backlog.md)). Maintainer corrections applied 2026-11-01: every WoW version has
`C_Spell` and the addon works on all supported clients — the initial compatibility findings are
withdrawn, and `Swing`'s retail-12 disable is intentional.

**Correctness gaps (traced):**

1. `Modules/Ring.lua` `ShouldShowRing()` — the `combat`/`raid`/`party_raid` modes fall through into
   the `gcd_casting` request scan, so the ring also shows during casts/GCDs when the mode condition
   is false. The loop needs to be gated on `visibility == "gcd_casting"`.
2. `Modules/Cooldowns.lua` "Restore defaults" (`self.db = deepcopy(defaults)`) detaches the module
   from AceDB: the reset is not persisted and later changes are lost on reload. The other modules
   use `ResetProfile()`.
3. `Modules/Swing.lua` `UNIT_SPELLCAST_SUCCEEDED` handler compares its third parameter against spell
   **name** strings (`slam`, `autoshot`, `shoot`); per the modern `(unit, castGUID, spellID)` payload
   shape that parameter receives the castGUID. The maintainer reports Swing works on Classic (the
   retail-12 disable is by design) — if the Slam swing-reset or the autoshot-success restart ever
   looks wrong in game, this comparison is the first place to look. The CLEU `SWING_*` path is solid
   either way.
4. `Modules/Cast.lua` `hideCastBar` — `OnDisable` never restores the Blizzard casting bar it
   unregistered/hid; the restore list in the option's `set` is a hand-copied subset of Blizzard's
   events (plain `RegisterEvent`, not unit-filtered). Both `hideCastBar` and `reverseChanneling`
   index `addon.BlizzardCastingBarFrame` without a guard.
5. `Modules/Cooldowns.lua` `ACTIONBAR_UPDATE_COOLDOWN` legacy fallback
   (`scd, dur = C_Spell.GetSpellCooldown(spell)`) is unreachable as written — the API returns a
   single table, so `dur` is always nil — and is dead code worth removing (icons work via the
   primary path on current clients).
6. `GCD.lua` hardcodes the folder name `"CursorCooldown"` when building `addon.addonFolder`; a
   differently named install folder makes `GCD.lua` error at file load and breaks all texture paths.

**Smaller defects:** `framesVisible` stale keys across `SPELLS_CHANGED` (cooldowns anchor can stay
shown) · `PopulateCdSpellsOptions` removes entries while `ipairs`-iterating · `RegisterCompartment`
is a one-way latch (the option cannot remove the entry) · `media:Fetch("font", …)` passed to
`SetFont` unguarded in `Cooldowns` (guarded by `tostring` in `Cast`) · `channel`-start latency
division has no zero-guard (`Cast`) · `UNIT_SPELLCAST_CHANNEL_UPDATE` arithmetic lacks the nil/secret
guards its `DELAYED` sibling has · unused `build` local (`Cooldowns.lua`) · `SetBackdropColor(255,0,0,1)`
uses 0–255 values where vertex colors are 0–1.

**Redundancies:** the `RegisterUnitEvent` dispatch shim is duplicated in `Cast.lua` and `Swing.lua`;
the `FixDatabase` version-stamp boilerplate exists in five near-identical copies; the
donut/spark/`Unlock`/`Lock`/`ApplyOptions` scaffolding is triplicated across cast/gcd/swing; DB
namespace naming is inconsistent (`Cast`, `Cooldowns`, `CC`, `Ring`, `Swing`); `Cooldowns.lua` uses
2-space indentation while the rest uses tabs.

**Not analyzed (gaps):** in-game behaviour on any client (nothing was executed inside WoW) · the
Swing sub-branches (Slam swing-reset, autoshot restart) in game — the maintainer reports Swing works
on Classic, so the payload-shape note above is a question for a client run, not a confirmed defect ·
contents of `.release/` archives · binary texture assets · translation quality of the 10 non-English
locale files (structure and key parity only) · vendored `Libs/**` internals except the
AceAddon/AceDB/LSM parts quoted above.
