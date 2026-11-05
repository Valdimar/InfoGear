# InfoGear v1.0 (formerly GearInfo 1.7.2.9, patched)

Drop-in folder: `InfoGear/` -> copy it to `Windower4/addons/InfoGear/` and load it with `//lua l infogear`.
Based on the **GearInfo 1.7.2.9** zip, not master (1.7.2.10) - compare before merging. Original author: Sebyg666.

## The rename
| | before | now |
|---|---|---|
| addon / folder / main file | `GearInfo` / `GearInfo.lua` | `InfoGear` / `InfoGear.lua` (Windower needs all three to match) |
| version | 1.7.2.8 (string in the file) | `1.0` |
| commands | `//gi`, `//gearinfo` | `//ig`, `//infogear` (help text and messages updated) |
| reload command used internally | `lua r gearinfo` | `lua r infogear` |
| **Gearswap command** | `gs c gearinfo ...` | **unchanged on purpose** - your existing Gearswap files listen for it |

Things to know:
* **Do not load GearInfo and InfoGear together** - both would send `gs c gearinfo` to Gearswap and draw on the same screen spots. Unload GearInfo first: `//lua u gearinfo`.
* Settings and your saved gear are stored per addon folder, so InfoGear starts fresh. To keep them, copy the old `GearInfo/data/` folder into `InfoGear/data/`.
* If you want the Gearswap command renamed to `infogear` as well, it is three strings in `InfoGear.lua` (search for `gs c gearinfo`) plus your Gearswap files - say so and it can be done, but it breaks existing Gearswap setups until they are updated.

**Not tested in-game.** Everything was tested outside the game with a small Lua runner and Windower stubs
(`sh tests/run_all.sh`, needs Lua 5.3/5.4 – the addon itself runs on Windower's Lua 5.1).
Diffs per step are in `diffs/` (`4_rename_to_infogear.diff` is the rename), the code before each step is in `baselines/`.

## Step 1 – bug fixes
| Problem | Fix |
|---|---|
| Attack / evasion / defence were wrong unless the **Acc** widget was shown (base STR/AGI/VIT and base weapon skill were only added inside `get_player_acc`, which mutated the shared table) | New `build_combined_stats()` runs once per update; `get_player_acc` no longer modifies its input. Test: acc hidden gave att/eva/def 89/356/256, now 440/391/331 (same as the old "acc shown" values). |
| Hand-to-Hand base skill never counted (`hand-to-hand` vs Windower's `hand_to_hand` key) | `skill_key()` maps both spaces and hyphens to `_`. |
| Hand-to-Hand attack counted `Buffs_inform['Attack']` twice | removed the second addition |
| Total haste: manual gear haste counted twice, Ionis haste (`g_haste`) missing | `get_total_haste` uses `Gear_info.Haste + g_haste` (manual already inside) |
| Moving along one axis looked like standing still (`and` instead of `or`); `nul`/`null` typos; `x` twice, no `z` | fixed in `check_player_movement` and `Statics.lua` |
| `R.Acc` widget never removed (deleted block 20 instead of 19) | fixed |
| `gs c gearinfo ...` sent ~4x/second even when nothing changed | sent only on change, plus a heartbeat every 20 updates (~5 s) so a reloaded Gearswap catches up; `//ig update` always sends. Command format unchanged. |
| Crashes: nil `get_player()` at the login screen; unknown buff/spell ids; spells missing from `Blue_Mage_Spells`; weapons without `delay`; Aggressor body check called `:contains()` on a number | guarded |

## Step 2 – tables instead of if/elseif, direct lookups
* New `Job_Traits.lua`: all job trait ladders (acc/eva/att/def, Smite, Store TP, Dual Wield, hand-to-hand delay)
  are data + one `by_level()` helper; Blue Mage trait code (was copied six times) is `blu_trait_rank()`; job-point
  gifts are `gift_bonus()`. `Gear_Processing.lua` 1114 -> 624 lines, `Calculator.lua` 440 -> 206.
* `res.items[id]`, `DW_Gear[id]`, `Unity_rank[id]`, `Set_bonus_by_item_id[id]`, `Martial_Arts_Gear[id]`,
  `res.spells[id]`, `res.job_abilities[id]` instead of scanning tables (the action handler runs for every action in the zone).
* Verified against the old code on 5,852 scenarios (every job x level, every sub job/level, job point tiers, 400 random
  Blue Mage spell sets, martial arts gear): **15 rows differ, all intentional** (below).

## Step 3 – `Display.lua`
`update()` and all widget code moved to `Display.lua` (~400 lines of copy-paste -> small helper-based functions).
Gear stats, `Total_haste` and the `DW` flag are now calculated **before** and independent of the widgets.
Old vs new `update()` compared on 18,000 random updates (including widgets being toggled on and off): identical,
except for the intentional changes below. A deliberately injected bug is detected by the same test.

## Intentional behaviour changes – please double-check these
1. **Samurai Store TP** had gaps (levels 30/31, 50/51, 70/71, 90/91 returned 0). Tiers now start at 30/50/70/90
   (main) and 30 (sub). I assumed that is what the `> 31` etc. were meant to be – confirm against game data.
2. **Puppetmaster evasion**: the original gives nothing at levels 60-76 (`> 76`, probably meant `> 59`). I **kept**
   that behaviour and marked it in `Job_Traits.lua` (`{60, 0}`) – fix it once you know the right value.
3. Gearswap now receives the real haste value and DW flag even when the haste / DW widgets are hidden
   (before: `nil`/stale haste, and `DW` was only ever set to true while the DW widget was visible).
4. Captions follow state: `Acc.`/`Acc.1`, `Att.`/`Att.1` when an off-hand weapon appears, `R.to WS` after WS TP ends.
5. PDT/MDT with a positive second tier (PDT2/MDT2 > 0) show a value instead of a stale `0`.
6. Hidden evasion/defence widgets are no longer calculated every update.

## Known, not done
* COR roll message can fail when a target is not a party member (`rollMembers` has holes, `Action_Processing.lua`).
* `get_player_skill_in_gear`'s combat/magic-skill branch is dead code (`player_base_skills.player_skill`).
* `check_equipped` still scans the whole saved gear table a few times per second – worth caching, but needs in-game testing.
* `centre_all_text()` runs every 2 frames; only recompute when text changes.

## v1.4 – new display
* The 4-across bracket-tile display is replaced by **cards**: flat rounded cards, 4 across in 54 x 38 px (228 px wide like the original), small coloured
  caption over a big bold number, on a plain dark panel (`Layouts.lua`, `textures/cards/`).
* Removed: the logo, the old textures and theme folders (`default/`, `custom1/`, the `_title` / `_double` strips,
  `zz*.png`), and the commands that only applied to them: `//ig theme`, `//ig show logo`. The `show_logo` and
  `image_folder_name` settings are no longer used (an old settings file that still has them is fine).
* New: `//ig scale <0.5-2>` (setting `display.scale`).
* `check_positions()` / `get_position()` / `centre_all_text()` / `update_all()` in `Image_processing.lua` apply the
  plan from `Layouts.lua`; `Display.lua` calls `check_positions()` right after a card is created.
* The panel is the existing background prim (created first, so it sits under the cards) with `panel.png` on it.
* Over-cap values use `alert_color` (set from the layout, a soft red) in `set_value` in `Display.lua`.
* Tested outside the game only: Lua 5.1 with Windower stubs, 2,500 random widget sets at scales 0.5–2 (every card
  placed, no overlaps, all inside the panel); `docs/layout-cards.png` is rendered from that code. **Not tested
  in-game.** Things to look at: the panel texture on the background prim, and card textures at scales other than 1.
* Removed the three chat notices about the 1.7.2.2 settings change that were printed on every load.

## v1.5 – GEO bubbles and Swordplay
* **Geo-/Indi-Fury** now raise attack: the bubble was stored as `Attack_perc`, the attack formula reads
  `Attack perc` (355/1024 = +34.7% at 900 skill). Sylvie (UC)'s Indi-Fury was a flat +384 attack, now 384/1024 (+37.5%).
* **Geo-/Indi-Barrier** now raise defence, as a percentage (407/1024 = +39.8% at 900 skill, BG-Wiki). Defence also
  counts flat DEF and VIT from buffs now (it only counted gear before).
* **Geo-/Indi-Voidance** now raise evasion. Evasion also counts AGI and Evasion from buffs (so Aggressor's -25
  evasion now shows too). Ranged attack counts STR from buffs.
* **Bolster** is detected: it was recorded as `Bolster` but checked as `bolster`, so Bolstered bubbles counted at
  normal strength. The Soul Voice / Bolster flags are also worked out per party member now; before, one member
  with the buff marked everyone after them in the party list.
* **Swordplay** (RUN, buff 532): accuracy and evasion, +3 when used, +3 per tick, up to +60 (BG-Wiki). Futhark
  Mitons / +1 / +2 / +3 on your hands when it's used start it 3 / 5 / 7 / 9 ticks in (+12 / +18 / +24 / +30).
  The game doesn't report the current value, so it's worked out from the time since the buff appeared, with
  **3 s per tick as an estimate** (`swordplay_tick_seconds` at the top of `Buff_Processing.lua`).
* Runes themselves only change elemental resistance, which InfoGear doesn't show, so they aren't calculated.
* Tested outside the game: the defence / evasion / attack formulas and Swordplay with Lua 5.1 and stubs
  (Barrier 1022 -> 1428 def, x2 under Bolster 1834; Voidance +65 eva; Swordplay +30 at 0 s with Mitons +3, +60
  cap). The Bolster party-packet change isn't covered by a test (it needs real packets).

## v1.5 – load message
* On load, chat shows the character's profile and the author line:
  `[InfoGear] Loaded profile layout for <character>.` / `[InfoGear] Author: Valdimar @ Phoenix <version>, based on GearInfo by Sebyg666`.
  At the login screen (no character yet) only the author line is shown.
* `_addon.author` is now `Valdimar @ Phoenix`; GearInfo by Sebyg666 is credited in the load line and the README.
* Display settings were already per character (`data/<CharacterName>_settings.xml`: position, scale, show toggles);
  no change needed there.

## v1.6 – movement speed
* New **Speed** card (block 30, after STP): `+18%` etc., red when below +0%. Same formula as Windower's SpeedChecker:
  `100 x (movement_speed / 5 - 1)` from your own character, so it includes gear, Flee, Bolt's Role, Quickening,
  slows and weight. Mounted it shows the mount's speed against walking (also as SpeedChecker does).
* `//ig show speed` toggles it (setting `show_speed`, on by default); `//ig show all` / `//ig hide` include it.
* Tested outside the game: matches SpeedChecker's output for 5.0 / 5.9 / 6.25 / 4.0 / 8.0 (mounted).

## v1.7 – extra stat cards, gear reading fixes
* **28 new cards**, all off by default, in 5 groups (`//ig cards`, `//ig show <card|group>`; `//ig show all` /
  `//ig hide` include them): melee DA/TA/QA, Crit, Crit.D, SB, SB II, WSD, PDL; ranged Snapshot, Rapid Shot; magic
  Fast Cast, M.Acc, MAB, MBB, MBB II, Cure, Cure II; tank M.Eva, MDB, Phalanx, Enmity; misc HP, MP, Regen, Refresh,
  Regain, TH. Caps (BG-Wiki) turn the number red: Fast Cast 80, MBB 40, Cure 50, Cure II 30, Snapshot 70,
  Subtle Blow 50 each / 75 together. Gear totals plus tracked buffs; traits / job points / merits not included.
* **Gear reader** learns all of those, with the wordings found in the game's item descriptions and augments
  (`"Mag. Atk. Bns."`, `"M. Def. B."`, `Mag. Eva.`, `"Phalanx" received`, `Magic burst damage II`, `"Quad Attack"`...).
  Stats that only look similar are kept apart: Magic critical hit rate, Cure potency received, `"Double Attack"
  damage`, Magic Accuracy skill.
* **Fix – conditional and pet stats:** the description is now cut at the earliest of ~45 prefixes (Pet, Avatar,
  Wyvern, **Automaton**, Luopan, Trust, Latent effect, Unity Ranking, Set, Song effects, Reives, Campaign, Besieged,
  weather, days, "Vs. ...", ear/ring pair bonuses...). Before, only 6 were checked, in a fixed order, so e.g.
  `Automaton: "Refresh"+4`, `Reives: Damage taken-10%` or `On Lightningdays: Accuracy+15` counted as always on (this
  affected haste and DT too), and a pet line could overwrite your own value (Arasy Sainti: Accuracy 10 instead of 15).
* **Fix – PDT/MDT:** `Physical Damage taken` / `Magic Damage taken` (capital D) were counted as general DT.
* Set bonus names `Critical Hit Rate`, `Cure potency (II)` are mapped to the stat names.
* **One-time re-read of saved gear:** each character's `_data.lua` is read again on the first load of 1.7
  (`GEAR_PARSER_VERSION` in `InfoGear.lua`, `parser_version` in the settings file), so nobody has to `//ig parse`.
* Tested outside the game: the parser over all 23,456 item descriptions in Windower's resources (counts per stat,
  every miss explained by a pet / latent / unity prefix, spot checks on ~20 well-known items), old vs new parser on
  the existing stats (all 1,203 differences are the fixes above), toggles, cap colours, layout checks with the new
  cards. Not tested in game.

## v1.8 – columns
* `//ig columns 4|5|6` (or `//ig cols`): cards per row, saved per character (`display.columns`, default 4). The panel
  resizes right away. Other values are refused.
* Tested outside the game: the command (valid, out of range, no value), and 2,700 random card sets at 4, 5 and 6
  columns and scales 0.5 / 1 / 2 (every card placed, no overlaps, inside the panel, never more cards in a row than
  the setting).

## v1.8 – columns
* `//ig columns 4|5|6` (or `//ig cols`): cards per row, saved per character as `display.columns` (default 4).
  Other values are refused with a message; the panel resizes at once.
* Tested outside the game: the command (4/5/6, out of range, no value) and 2,700 random layouts at 4, 5 and 6
  columns and scales 0.5–2 (every card placed, no overlaps, no row wider than the setting).

## v1.9 – grouped rows at 4, 5 and 6 columns
* Cards are placed by group instead of one fixed order (`card_groups` in `Layouts.lua` replaces `card_order`):
  a group that fits in a row stays in one row, a bigger one wraps from the start of a new row, and small groups
  (Eva/Def, DW, MA, Speed, short extra groups) fill gaps in earlier rows, first gap first. UGS goes in the last
  row, or the first gap when that is full. STP now sits with the melee TP cards.
* Panel sizes are unchanged from v1.8 for the same cards (no extra rows from the grouping in the tested sets).
* Tested outside the game: 1,500 random card sets at 4/5/6 columns with no group split when it would fit, plus the
  earlier checks (every card placed, no overlaps, no row wider than the setting).

## v1.10 – JSE neck rank bonuses, augment freeze
* **JSE neck ranks:** Windower's extdata gives only the path and rank of the Dynamis - Divergence JSE necks, never
  their bonus stats, so e.g. Futhark Torque +2's Damage taken -7% was never counted (swapping it for Warder's Charm
  +1 left DT unchanged). New `res/JSE_Neck_Ranks.lua`: all 66 necks (22 jobs x base / +1 / +2) with their max-rank
  bonuses from BG-Wiki (Category:JSE_Necks), limited to stats InfoGear shows (HP, MP, attributes, DT, DA, TA, Crit,
  Store TP, PDL, Fast Cast, MBB, MAB, Evasion, Enmity). The current rank is read from the item; below max rank the
  bonuses are scaled by rank / max rank (rounded toward 0), which is an estimate. If the rank can't be read, max
  rank is assumed. The bonus is added to a copy, so the saved gear file isn't changed.
* **Fix – freeze on re-augmented gear:** when the saved copy of an augmented item had fewer augment lines than the
  one worn, `check_equipped` errored and the whole display stopped updating. Now that is treated as "no match" (the
  item is read again).
* Tested outside the game with the real `check_equipped`: Futhark Torque +2 at R25 / R20 / unreadable rank, swap
  to Warder's Charm +1 (DT -7 -> 0), repeated updates (no build-up), the re-augmented case (no error).

## v1.11 – Limbus accessories, all Unity gear
* **Limbus ranked accessories:** new `res/Limbus_Ranks.lua` with the exact bonus at every rank R1-R30 for Murky
  Ring, Murky Mantle, Alabaster Earring and Alabaster Mantle (FFXIAH, "Augment Tables for Limbus Gear (r1 to 30)";
  Murky Mantle's Magic Damage isn't shown). The JSE necks and these share one lookup (`Ranked_Gear`).
* **Rank detection:** an item that was never augmented now counts as rank 0 (before, "rank unreadable" always meant
  max rank). An item with a rank path but no readable rank is still taken as max rank.
* **Unity gear:** `res/Unity_Gear.lua` regenerated from the "Unity Ranking:" lines of every item description in
  Windower's resources: 205 items with stats InfoGear tracks (was 151; 10 more give only Conserve MP, MP while
  healing, avatar MAB or resistances). Items can have several Unity stats (Imp. Wing Hairpin: DEX and AGI). The
  151 existing entries were checked against the game text: all matched, except Cure potency now uses the Cure card's
  name and Imp. Wing Hairpin (+1) also gets AGI. Same rank formula as before (rank 1 = best), now also correct for
  negative ranges (Enmity-).
* `GEAR_PARSER_VERSION` 3: saved gear is read again once, since Unity values are stored in it.
* Not yet: rank augments of the Limbus racial armor (75 pieces, ids 24120-24194); their base stats are read as usual.
* Tested outside the game: Murky Ring at R30 / R25 / R15 / R1 / not augmented, Alabaster Mantle at R30 / R22 / R10
  (match the forum tables), the JSE neck cases again, Unity values at ranks 1 / 6 / 12 against the old formula.

## v1.12 – Pet DT
* New card **Pet DT** (`//ig show pet` or `petdt`, off by default): the damage taken your gear gives your pet, as
  physical / magic (DT + PDT / DT + MDT), shown positive like your own DT cards. One card for every pet type: the
  "Pet:", "Wyvern:", "Avatar:", "Automaton:" and "Luopan:" parts of descriptions all count (gear is job-locked, so
  in practice it's your current pet). Red over 50 (pets cap like players, BG-Wiki). Pet abilities and traits (Stout
  Servant, Spirit Bond, Steady Wing...) aren't included.
* The gear reader reads those parts separately before cutting them off, so your own stats don't change (checked on
  all 23,456 items: 0 changes; 78 items give pet damage taken, e.g. Idris Luopan DT -25%).
* DRG JSE neck (Dragoon's Collar / +1 / +2): Wyvern Damage taken -15 / -20 / -25% at max rank added to the rank table.
* `GEAR_PARSER_VERSION` 4: saved gear is read again once.

## v1.13 – pet cards only on pet jobs
* The pet card group (Pet DT) is shown only on a pet job: main BST, DRG, SMN, PUP or GEO, or support job SMN or BST
  (a /DRG can't call a wyvern, a /PUP can't activate an automaton). On other jobs it's hidden, but `//ig show pet`
  stays on, so it comes back by itself on a pet job. Lists: `pet_main_jobs` / `pet_sub_jobs` in `Display.lua`.
* Tested outside the game: 11 main/sub combinations with the real card update code.

## v1.14 – small card size
* `//ig size normal|small` (setting `display.size`, default normal): small cards are 44 x 30 px with 6 pt captions
  and 9 pt numbers (normal 54 x 38, 7 / 11 pt), so the panel takes about a third less space. Columns, grouping and
  scale work the same in both. Card sizes, fonts and text positions are in `card_sizes` (`Layouts.lua`); the plan
  now carries the font sizes and text positions, so Image_processing.lua no longer has them hard-coded.
* Tested outside the game: the command (normal / small / any case / unknown), 1,800 random small layouts at 4/5/6
  columns and scales 0.5–2, renders of both sizes (docs/sizes.png).

## v1.15 – Pet DT absorb fix, //ig why
* **Fix – Pet DT:** "Wyvern: Absorbs damage taken +N%" (all four Peltast's Mezail, and other absorb lines) was read
  as +N% pet damage taken, cancelling out real pet DT (Peltast's Mezail +3 + Dragoon's Collar +2 R25 showed 7 instead
  of 25). Absorb lines are now skipped. 72 items give pet damage taken (was 78 with the absorb lines); your own stats
  are unchanged on every item.
* **New `//ig why pet` / `//ig why dt`:** lists each equipped item's Pet DT / PDT / MDT (or your DT / PDT / MDT /
  BDT), the rank read for ranked gear, and the totals.
* `GEAR_PARSER_VERSION` 5: saved gear is read again once.
* Tested outside the game: Mezail (all 4) no pet DT; a DRG set (Mezail +3, Dgn. Collar +2 R25, Ptero. Fin. G. +3)
  through the real check_equipped -> Pet DT 25/36, and the why listing.

## v1.16 – wyvern innate damage taken
* On main DRG the Pet DT card adds the wyvern's innate -40% damage taken on top of the gear part: shown =
  min(gear, 50) + 40, up to the 87.5% overall cap (BG-Wiki, Wyvern (Dragoon Pet)). Red still means the gear part is over
  50 (wasted). Shown as whole numbers so it fits (87.5 -> 87). `wyvern_innate_dt` / `pet_dt_overall_cap` in Display.lua.
  Absorbs damage taken (Peltast's Mezail) stays out: it's a chance to absorb a hit, not damage taken.
* `//ig why pet` lists the wyvern's innate -40 as its own line on DRG.
* Tested outside the game: DRG set (Dgn. Collar +2 R25, Ptero. Fin. G. +3) 65/76; same gear on BST 25/36; gear
  33 -> 73/73; gear over the cap -> 87/87 red; no gear on DRG 40/40.

## v1.17 – Pet Regen
* New card **Pet Regen** (`petregen`, in the `pet` group: `//ig show pet` toggles both pet cards): the "Regen"+N your
  gear gives your pet, every pet type together like Pet DT. Only shown on a pet job. "Adds "Regen" effect" lines give no
  number and set bonuses are separate, so neither is counted. `//ig why pet` lists it per item too.
* `GEAR_PARSER_VERSION` 6: saved gear is read again once.
* Tested outside the game: 50 items give pet Regen (Ptero. Greaves +2 +7, Arasy Lance +5, Bagua Sandals +2 +4...);
  your own stats unchanged on every item; layout checks with the new card at both sizes.

## v1.18 – augments (Ambuscade capes) and abbreviations
* **Augment short forms:** `"Dbl.Atk."` (Double Attack) and `"Triple Atk."` (Triple Attack), as Windower writes the
  Ambuscade cape options, are now read. Before, a DA / TA cape added nothing to DA / TA.
* **`Eva.` on its own** is read as Evasion: the cape option `Eva.+20 /Mag. Eva.+20` gave only the Magic Evasion half,
  and many AF+3 / relic / Nyame descriptions write evasion as `Eva.+74` (21 items, e.g. Pel. Vambraces +3, Chasseur's
  Gants +3, Leth. Houseaux +3, Nyame Gauntlets / Sollerets), so their Evasion was never counted. Nyame's
  `Magic Eva.+112` is read too.
* **Pet augments:** augment lines with "Pet:" / "Wyvern:" / "Avatar:" were skipped entirely; they now go through the
  same reader as descriptions, so `Pet: Damage taken -5%`, `Pet: Phys. dmg. taken`, `Pet: Magic dmg. taken` and
  `Pet: "Regen"+10` (Ambuscade pet capes etc.) count toward Pet DT / Pet Regen. The pet's other stats still don't count
  as yours.
* `GEAR_PARSER_VERSION` 7: saved gear is read again once.
* Tested outside the game: 15 typical Ambuscade capes (augment text built exactly as Windower's extdata does), before
  and after in separate runs; all 711 standard augments; every item description (23 values changed, all of them the
  Evasion / Magic Eva. fixes above).

## v1.19 – README images
* The README's opening images (the old GearInfo logo and a screenshot of the old bracket-tile display, both on Imgur)
  are replaced with `docs/banner.png` (a new InfoGear wordmark in the card style) and `docs/display.png` (the current
  display, rendered from the addon's own layout code at 2x). The other README images (`layout-cards`, `sizes`,
  `columns`, `layout-cards-extra`) already show the current layout.

## v1.20 – Limbus racial armor and weapon ranks
* New `res/Limbus_Armor_Ranks.lua`, generated from the R30 values per slot (sheet of the BG-Wiki pages): 155 items,
  i.e. the 5 racial sets x 5 slots x NQ / HQ1 / HQ2 (Justice / Magnificent / Duty, Hope / Perfection / Revelation,
  Trust / Prestige / Sworn, Bravery / Intrepid / Indomitable, Mercy / Grace / Clemency) and the Limbus weapons
  (Skia, Arctus, Auge, Telognophos, Daduchos, Telopanos). Shown stats: Accuracy, Ranged / Magic Accuracy, Attack,
  Ranged Attack, DA, TA, QA, Store TP, PDL, MAB, Phalanx (received), Enmity, HP, VIT. Not shown: Damage, Magic
  Damage, Blood Pact damage, pet stats.
* Growth per rank: exact BG-Wiki tables for Sworn Crown, Duty Crown and Clemency Somen (used for their whole slot,
  NQ to HQ2). Elsewhere: [1] and [4] +1 per rank from R1; [2] from R15 and [3] from R20 (Bravery: R16 / R26),
  +1 every 2 ranks but at most the R30 value minus 1 per 3 ranks still to go, which reproduces the four known tables
  except 2 values (1 off); big weapon numbers grow in proportion. R30 is exact for every piece.
* Uses the same rank reading as the JSE necks and Murky / Alabaster gear (`Ranked_Gear`).
* Tested outside the game: Sworn Crown R30 + Duty Cyclas R20 through the real check_equipped (TA 7, Store TP 3,
  Phalanx 4); spot checks against the pasted tables (Revelation Platemail DA +1 at R15, +3 at R20).

## v1.21 – Limbus weapon ranks
* Limbus weapons now grow like BG-Wiki's Telopanos Grip table: every group starts at R1 (not R15 / R20 like the
  armor); stats worth 30 at R30 go +1 per rank; bigger ones follow the grip's HP curve (+4 / +3 / +2 per rank for
  every 100 at R1-15 / R16-25 / R26-30), e.g. HP+300 = +12 / +9 / +6 per rank. The grips (Arctus to Telopanos) match
  the wiki at all 30 ranks; R30 stays exact for every weapon.

## v1.22 – one growth rule for all Limbus armor
* All Limbus armor sets, slots and tiers rank up the same way: a stat's growth depends only on its R30 value. So the
  three per-item tables (Sworn Crown, Duty Crown, Clemency Somen) are gone and every piece uses the one rule. Checked
  against six BG-Wiki tables (Sworn Crown, Sworn Sabatons, Prestige Platemail, Duty Crown, Clemency Somen, Revelation
  Platemail): 139 of 141 values match; the 2 others (Clemency Somen Enmity R29, Sworn Crown Phalanx R23) contradict
  other tables with the same R30 value, so they look like wiki typos.

## v1.23 – new banner

* `docs/banner.png` replaced: outlined 2x2 card icon beside the InfoGear wordmark, a six-colour rule (the card caption colours) under both, and the tagline "gear, buffs & caps at a glance". No code changes.

## v1.24 – Ecliptic Attrition crash fix

* Fixed `Action_Processing.lua:239: attempt to perform arithmetic on field 'boost' (a nil value)`: using Ecliptic Attrition when InfoGear didn't know the Luopan's bubble (cast before the addon loaded, or the party list had been rebuilt) crashed. Now it's skipped in that case, and a missing boost counts as 1.
* Also guarded: a Luopan that has just despawned no longer errors in the GEO bubble check, and Indi/Geo potency uses x1 when the boost is unknown.

## v1.25 – README section headings

* New heading images in the banner's style (outlined card icon, six-colour rule, the command in lavender) above the Cards, Sizes, Columns and Extra Cards pictures: `docs/heading-cards.png`, `heading-sizes.png`, `heading-columns.png`, `heading-extra-cards.png`. No code changes.
