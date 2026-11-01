# Backlog — KCursorCooldown

Open work items and audit findings for CursorCooldown. The audit (2026-11-01) was report-only: no
code was changed.

## Maintainer facts (2026-11-01) — re-ranking context

- The addon works fine on all supported clients.
- Every WoW version has `C_Spell`: the load-time `C_Spell.*` uses are safe everywhere. The initial
  "high" client-compatibility finding is **withdrawn**.
- `Modules/Swing.lua` works on Classic. Its wholesale disable on retail 12 is **intentional** —
  retail keeps those values secret.

## Open — audit findings 2026-11-01

### Medium

1. **`Modules/Ring.lua:100-118` — `ShouldShowRing()` visibility fall-through.** The
   `combat`/`raid`/`party_raid` modes fall through into the `showRequests` scan (the
   `-- gcd_casting detection` loop has no mode guard), so the ring also shows during casts/GCDs when
   the mode's condition is false. Traced: `visibility = "combat"` while solo → both mode `if`s are
   false → a live `cast`/`gcd`/`swing` request returns `true` → `UpdateVisibility()` shows the ring,
   contradicting the option label. Fix: gate the loop on `visibility == "gcd_casting"` (or return
   `false` for the other modes).
2. **`Modules/Cooldowns.lua:326` — "Restore defaults" detaches the module from AceDB.**
   `self.db = deepcopy(defaults)` replaces the AceDB namespace with a plain table: the reset is not
   persisted (lost on `/reload`) and later edits bypass AceDB's saved-variable copy. Contrast: the
   four other modules call `self.db:ResetProfile()` (`Cast.lua:289`, `Modules/GCD.lua:144`,
   `Ring.lua:291`, `Swing.lua:190`). Fix: use `ResetProfile()` here too.
3. **`Modules/Cast.lua:335-342` + `249-283` — `hideCastBar` state leak.** The option unregisters all
   events on the Blizzard casting bar and hides it, but `OnDisable` never restores it: disabling the
   Cast module afterwards leaves the default castbar dead until the module is re-enabled and the
   toggle flipped off. The restore path also re-registers a hand-copied event list (plain
   `RegisterEvent`, unlike Blizzard's unit-filtered registration) — fragile against Blizzard
   changes. Fix: restore in `OnDisable` when the option is set, or document the coupling.

### Low

4. **`GCD.lua:547-548` — hardcoded addon folder name.** `C_AddOns.GetAddOnInfo("CursorCooldown")` is
   concatenated into `addon.addonFolder`; the packaged name matches (`.pkgmeta` `package-as`), but
   loading from a differently named folder (e.g. the git repo name) errors at file load and breaks
   every texture path. `addonName` (line 5) is already the robust value.
5. **`Modules/Cooldowns.lua:378-417` — stale `framesVisible` keys.** `SPELLS_CHANGED` pools old icon
   frames without clearing their `framesVisible[frame] = true` entries, so the all-hidden scan in
   `module:Hide` never fires `addon:Hide("cooldowns")` and the anchor can stay shown with nothing on
   it. Fix: clear the table when rebuilding `cdFrames`.
6. **`Modules/Cast.lua:467-492` — inconsistent channel guards.** `UNIT_SPELLCAST_CHANNEL_START`
   computes `sendLag / castDuration` without the zero-guard `UNIT_SPELLCAST_START` has (0/0 → NaN),
   and calls `castFrame.spellText:SetText` without the nil-check its sibling has (`Cast.lua:424`);
   `UNIT_SPELLCAST_CHANNEL_UPDATE` does `castEndTime - castStartTime` with none of the nil/secret
   guards `UNIT_SPELLCAST_DELAYED` has (`Cast.lua:449-459`).
7. **`Modules/Cooldowns.lua:195-197` and `:501`.** `table.remove(cdSpells, i)` while `ipairs`-
   iterating skips entries (nil-`spellID` cleanup is unreliable), and
   `SetFont(media:Fetch("font", …))` is unguarded — `Cast.lua:564` wraps the same call in `tostring`.
8. **`GCD.lua:87-98` — Addon Compartment one-way latch.** Once `_compartmentRegistered` is true the
   option can never remove the compartment entry (no unregister path).
9. **`Modules/Cooldowns.lua:344-374` — dead legacy fallback.** The `elseif type(dur) == "number"`
   branch assigns `scd, dur = C_Spell.GetSpellCooldown(spell)`, but that API returns a single table,
   so `dur` is always nil and the branch is unreachable — dead code worth removing (the maintainer
   confirms icons work on current clients via the primary path).
10. **`Modules/Swing.lua:267-280` — verify in game (maintainer reports Swing works on Classic).**
    The `UNIT_SPELLCAST_SUCCEEDED` handler compares its third parameter against spell **name**
    strings (`slam`, `autoshot`, `shoot`); per the modern `(unit, castGUID, spellID)` payload shape
    that parameter receives the castGUID. If the Slam swing-reset and the autoshot-success restart
    visibly work in game on Classic, this entry is a non-issue (the payload shape differs from the
    modern one there); if those two subtleties ever look wrong, this comparison is the first place
    to look. The main timer path (CLEU `SWING_*`) is solid either way.

### Cosmetic

11. `GCD.lua:488` — `SetBackdropColor(255, 0, 0, 1)` uses 0–255 values where vertex colors are 0–1
    (clamps to 1; contradicts the in-options note). `Modules/Cooldowns.lua:16` — unused `build`
    local.

## Cleared (checked and found safe)

- **Client-compatibility cluster (withdrawn 2026-11-01):** maintainer confirms every WoW version has
  `C_Spell` and the addon works on all supported clients; the bare `issecretvalue` call in
  `Modules/GCD.lua:235` therefore resolves everywhere (kept as a consistency note only).
- **`Swing` disabled on retail 12** (`Modules/Swing.lua:5-7`) is intentional design, not a defect.
- `addon.GetSpellInfo`/`GetNumSpellTabs`/… called through the addon table: filled by
  `GCD.polyfill.lua`, resolved at call time; load order is safe.
- `PopulateCdSpellsOptions` at `Cooldowns:OnInitialize` with `options` unset: safe — AceAddon
  initializes the root addon before its modules (verified in `Libs/AceAddon-3.0`).
- `defaults.char.cdSpells` shared-table mutation: AceDB `copyDefaults` deep-copies lazily
  (`Libs/AceDB-3.0`).
- `Swing.lua:297` CLEU destructuring has misnamed intermediate variables, but every used slot lands
  on the right payload (`srcGUID` = sourceGUID, `dstGUID` = destGUID, `spellID` = missType for
  `SWING_MISSED`).
- Degree/radian handling (`cos`/`sin` WoW globals in degrees vs `math.*` in radians): correct.
- Position inputs are `tonumber`-validated before `set`; `string.format` calls pass user data as
  arguments, not as format strings; a stale `modules.swing` SavedVariable key is inert (enable loop
  iterates registered modules only); the default font `"2002 Bold"` is registered in the bundled
  LibSharedMedia.

## Hardening (not vulnerabilities)

- SavedVariables are read without type validation (hand-edited SV → nil-indexing errors on
  colors/fonts/tables).
- Event handlers rely on `RegisterUnitEvent(…, "player")` filtering instead of checking `unit`
  (checks are commented out; `UNIT_SPELLCAST_SENT` is the only handler validating it).
- `Modules/GCD.lua:234-237` checks `issecretvalue(dur)` but assigns `startTime` unchecked.
- The `thickness` option maps to `Textures/segment_<thickness>` filenames — an out-of-range saved
  value silently loses its texture.

## Coverage

Walked: all project Lua (`GCD.lua`, `GCD.polyfill.lua`, `donut.lua`, 5 modules), TOC, `embeds.xml`,
`modules.xml`, `.pkgmeta`, locale file structure, and the AceAddon/AceDB/LibSharedMedia internals
needed for the cleared items. Not walked (GAP): in-game execution on any client; `.release/`
archives; binary textures; translation content of the 10 non-English locales; `Libs/**` internals
beyond the verification points above.

## Summary

3 medium, 7 low, 1 verify-in-game, 1 cosmetic; no security-relevant findings (client-side addon, no
injection/memory/crypto surface). Overall: an addon that works in practice with traced logic defects.
Fix order: ① `ShouldShowRing()` mode gating, ② `ResetProfile()` in Cooldowns, ③ `hideCastBar`
restore in `OnDisable`.
