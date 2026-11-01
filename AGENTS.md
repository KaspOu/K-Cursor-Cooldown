# AGENTS.md — CursorCooldown

Working rules for AI agents (and humans) modifying **CursorCooldown** ("Cursor Cooldown Reloaded",
internal addon name `CC`), a World of Warcraft UI addon written in **Lua 5.1 + Ace3 + XML include
manifests**. It is not a web project: there is no build, no package manager, no test runner and no
CI. Everything ships as plain source files the WoW client loads directly. The only automation is the
workspace Lua syntax gate (see §6).

CursorCooldown is an **independent** K Ecosystem project (see the top-level `../AGENTS.md`): it does
NOT participate in the KallyeRaidFrames CopyTo or Shared-XML synchronization mechanisms. Never
introduce those mechanisms here.

Deep dive: [docs/architecture.md](docs/architecture.md) — load order, lifecycle, events, per-file
roles, data management.

---

## 1. Ground truth

| Item | Value |
| --- | --- |
| Addon folder / TOC | installed as `CursorCooldown/` + `CursorCooldown.toc` (the git repo is `KCursorCooldown/`; `.pkgmeta` `package-as: CursorCooldown`) |
| Declared version | `## Version: 12.1.502` (TOC) — no `ChangeLog.txt` exists |
| Saved variables | `CursorCooldownDB` (AceDB-3.0) and `CC_Settings` (plain table, account-wide), both available at file load (`## LoadSavedVariablesFirst: 1`) |
| Slash commands | `/gcd`, `/cc`, `/ccr`, `/ccd` — all open the options panel |
| Runtime | WoW Lua 5.1, Ace3 modules, `CreateFrame` UI built in Lua (no XML UI templates) |
| Interface IDs | `120100, 120105, 120107, 16001, 50504, 38002, 20506, 11509` (retail 12.1.x + classic flavors) |
| Localization | 11 files in `Localization/` — `enUS` seeds, 10 others gated by `## AllowLoadTextLocale` |
| License | **GPL v3** (`LICENSE.txt`, `## X-License: GPL v3`) |
| Libs | Ace3 subset + LibSharedMedia-3.0 + AceGUI-3.0-SharedMediaWidgets, vendored and restored by `.pkgmeta` `externals` (wowace SVN) |
| Packaging | BigWigs-style packager: `.pkgmeta`, `icon.png`; build output lands in `.release/` (packaged tree + zips) — never edit those |
| Git | gitmoji-style commit subjects (e.g. `:sparkles: New option: Force English`) |

## 2. Where to change what

| I want to… | Touch these files |
| --- | --- |
| Change the anchor, options shell, role filter, unlock flow, DB migration | `GCD.lua` |
| Add/adjust a WoW API compatibility wrapper (old vs new client API) | `GCD.polyfill.lua` (only there — see §5) |
| Change the arc/segment renderer | `donut.lua` + `Textures/segment_15..35.blp`, `Textures/slice.blp` |
| Change cast-time display (donut, spark, spell text, latency) | `Modules/Cast.lua` |
| Change spell-cooldown icons (per-character spell list, pooling) | `Modules/Cooldowns.lua` |
| Change the GCD sweep | `Modules/GCD.lua` |
| Change the rotating ring overlay | `Modules/Ring.lua` |
| Change the melee/ranged swing timer | `Modules/Swing.lua` (self-disabled on retail 12, see §5) |
| Add a locale string | `Localization/enUS.lua` first, then the 10 other `Localization/*.lua` |
| Change what loads, in which order | `CursorCooldown.toc`, `embeds.xml`, `modules.xml` |
| Change packaging | `.pkgmeta`, `CursorCooldown.toc` |

## 3. Module contract

All five modules follow the same Ace3 shape (`Modules/*.lua`): `addon:NewModule("<name>")` with
`<name>` one of `cast`, `cooldowns`, `gcd`, `ring`, `swing`. A module implements some subset of:

- `OnInitialize()` — `self.db = addon.db:RegisterNamespace("<Ns>", defaults)`, `FixDatabase()`,
  cross-module references via `addon:GetModule("ring", true)`.
- `GetOptions()` — builds and returns the AceConfig group; the core injects an `enabled` toggle and
  calls it from `addon:OnInitialize` (which runs **before** any `module:OnInitialize` — do not assume
  the reverse).
- `ApplyOptions()` — (re)creates frames from `self.db.profile`, called on enable and on every option
  change.
- `OnEnable` / `OnDisable` — event registration and teardown. `OnDisable` must undo everything
  `OnEnable` and `ApplyOptions` set up (see the known `hideCastBar` gap in §8).
- `Show(...)` / `Hide(...)` — gate visibility through `addon:Show(name)` / `addon:Hide(name)` so the
  shared anchor hides only when no module needs it.
- `Unlock(cursor)` / `Lock()` — re-parent module frames to/from the movable unlock frame.

Rules when modifying a module:

1. Read option values live (`self.db.profile.x`) in hot paths — never cache them.
2. New options need: a default in `defaults`, an AceConfig entry, live application in
   `ApplyOptions`, and the `disabled` closure used by the existing entries.
3. `defaults` are per-module (`profile`) except `Cooldowns` which also keeps `char.cdSpells`.
4. Keep the `--@do-not-package@` blocks intact (stripped from release packages).
5. Do not reformat a file you only came to edit: indentation is **tabs** in `GCD.lua`, `donut.lua`
   and most modules, but **2 spaces** in `Modules/Cooldowns.lua` and parts of `Modules/Cast.lua`.
   Match the surrounding lines.

## 4. Conventions and API traps

- Every file starts with `local addon = LibStub("AceAddon-3.0"):NewAddon("CC", …)` (core) or
  `:GetAddon("CC")` (everything else), then `L = LibStub("AceLocale-3.0"):GetLocale("CC")`.
- State lives in file-scope locals; behavior lives in module methods. Avoid new globals.
- **`sin`/`cos` in WoW take DEGREES; `math.sin`/`math.cos` take RADIANS.** `donut.lua` deliberately
  binds the math versions as locals and converts with `math.rad`; the modules use the degree-based
  globals. Never mix them (this is the renderer's main trap).
- Comment markers are meaningful: `--@diagnostic disable: …` headers (keep), `--@do-not-package@`
  blocks (keep), `-- Since Midnight (12)` marks retail-12-only API knowledge.
- Spell/timing values from the API may be **secret values** on retail 12+. Route checks through
  `addon.isSecret(value)` (defined in `GCD.lua`) or the file-local
  `secretwrap and issecretvalue(secretwrap(true))` guard — one call site uses bare `issecretvalue`;
  keep using the helpers for consistency (see §8).
- Texture paths are built as `addon.addonFolder.."\\Textures\\…"`; `addon.addonFolder` is derived at
  the bottom of `GCD.lua` from the **hardcoded** name `"CursorCooldown"` (see §8).
- French comments exist in `Ring.lua`/`Cast.lua`; comments earn their place by explaining why.

## 5. WoW API compatibility rules

The TOC declares retail 12.1.x **and** classic interfaces, so every API call must be
feature-detected, not version-guessed:

- `GCD.polyfill.lua` is the compatibility boundary: it populates `addon.GetSpellInfo`,
  `addon.GetSpellTabInfo`, `addon.GetNumSpellTabs`, `addon.GetSpellBookItemName`,
  `addon.BOOKTYPE_SPELL/PET` over the new `C_SpellBook`/`C_Spell` APIs when the legacy globals are
  gone. Add new wrappers **there**, keeping the `legacy or replacement` shape, and call them via the
  `addon.*` fields (never the raw globals).
- Load order matters: `GCD.lua` (defines `addon.isSecret`, `addon.addonFolder`) →
  `GCD.polyfill.lua` → `donut.lua` → `modules.xml`. Polyfill fields are consumed at call time, so
  modules must not call them at file load before the polyfill runs.
- Secrets (`secretwrap`, `issecretvalue`, `issecrettable`) exist on retail 12+ only.
  `Modules/Swing.lua` early-returns wholesale on 12.x ("no more useable, due to combatevent
  restrictions") — that is intentional; do not "fix" it by re-enabling.
- `PlayerCastingBarFrame` (used as `addon.BlizzardCastingBarFrame`) is a retail frame; check it
  before using it (see §8).
- Empower-cast events are gated by `RAID_CLASS_COLORS.EVOKER ~= nil` (feature detection); keep that
  pattern when adding class/feature-gated code.
- `AddonCompartmentFrame` support is optional and guarded (`addon:RegisterCompartment`).

## 6. Verification after every change

1. **Lua syntax gate** (required after every `.lua` edit):

   ```bash
   python3 ../tools/validate_lua.py <paths you touched>   # from KCursorCooldown/
   python3 ../tools/validate_lua.py --selftest            # prove the checker works
   ```

   Same script as the workspace root `tools/validate_lua.py`. No `lua`, `luac`, `luacheck`,
   `npm test`, `pytest` or `make` exists here — do not invent them.
2. Use `rtk <cmd>` for shell/git/file work (see the top-level `../AGENTS.md` §9 for installations
   and the byte-exactness caveat).
3. **In-game verification is required** for any behaviour change: `/reload`, open options with
   `/cc`, `/console scriptErrors 1`, then exercise the touched module (cast, GCD, cooldown icons,
   ring, swing) — plus the unlock flow (`Unlock` button, drag, right-click to lock).
4. If you touched a client-compatibility path (§5), say which client flavors you actually tested.
   A change verified only on retail 12 proves nothing about the classic TOC targets, and vice versa.

## 7. Sensitive files

- `GCD.polyfill.lua` — the only sanctioned API-compatibility boundary; reordering it against
  `GCD.lua`/`modules.xml` breaks every module.
- `GCD.lua` — core init, options tree, DB migration (`FixDatabase`), anchor and unlock machinery.
- `donut.lua` — quarter/texcoord geometry; a wrong `SetTexCoord` silently renders garbage angles.
- `Libs/**` — vendored third-party (Ace3, LibSharedMedia); never edit, never reformat. Restored by
  `.pkgmeta` externals at packaging time.
- `Localization/*` — all 11 files must stay key-consistent; each non-English file starts with the
  `CC_Settings.ForceEnglish` early-return — keep line 1 intact.
- `CursorCooldown.toc` + `.pkgmeta` — packaging identity: `package-as: CursorCooldown` must match
  the hardcoded folder lookup in `GCD.lua` (see §8) and the `## SavedVariables` list.
- `Textures/segment_15|20|25|30|35.blp` — the thickness option (15–35, step 5) maps to these
  filenames; renaming a texture breaks `donut:SetThickness`.
- `.release/**` — build output (packaged tree + release zips), not source. Ignore it when auditing
  code; never edit it.

## 8. Known fragile spots (audit 2026-11-01, report-only)

The full report lives in [docs/backlog.md](docs/backlog.md). Maintainer-verified facts that closed
the compatibility findings: every WoW version has `C_Spell`, and the addon works on all supported
clients (`Swing` is intentionally disabled on retail 12, which keeps those values secret).

Do not make these worse:

- `Modules/Ring.lua` `ShouldShowRing()` lets "In combat"/"In raid"/"In party/raid" visibility fall
  through to the gcd/cast request check, so the ring shows during casts even when the condition is
  false.
- `Modules/Cooldowns.lua` "Restore defaults" replaces `self.db` with a plain `deepcopy(defaults)`,
  detaching the module from AceDB persistence (the other modules correctly call `ResetProfile()`).
- `hideCastBar` (`Modules/Cast.lua`) disables the Blizzard casting bar but `OnDisable` never restores
  it; the hand-written re-registration list is a fragile copy of Blizzard's.
- `GCD.lua` builds `addon.addonFolder` from the hardcoded `"CursorCooldown"` folder name (matches
  the packaged name); loading from a differently named folder errors at file load.
- `Modules/GCD.lua` calls bare `issecretvalue(dur)` where every other secret check goes through the
  guarded helpers — keep using the helpers for consistency.
- `Modules/Swing.lua` compares `UNIT_SPELLCAST_SUCCEEDED`'s payload against spell name strings; the
  maintainer reports Swing works on Classic — if the Slam swing-reset or the autoshot restart ever
  looks wrong in game, that comparison is the first place to look.
