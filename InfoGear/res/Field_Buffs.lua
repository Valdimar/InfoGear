--[[
	res/Field_Buffs.lua (v1.27)

	Stats InfoGear adds while you have one of these status effects (buff id = key). They go into the same totals as
	your gear, so every card that shows the stat includes them, and the hover box lists them on their own line.

	Edit the numbers here if you know better ones. Stat names are the ones the gear uses: Accuracy, Attack,
	Ranged Accuracy, Ranged Attack, Evasion, DEF, Magic Accuracy, Magic Atk. Bonus, Magic Evasion, Magic Def. Bonus,
	Critical hit rate, Fast Cast, Conserve MP, Store TP, Regen, Refresh, Regain, HP, MP...

	Ionis: every coalition is taken as fully edified (both edifications). Only the numbers BG-Wiki gives are filled
	in (Couriers' Coalition, Moderate: Accuracy +20, Evasion +20). The others are listed with 0 until their values
	are known: put the number in and it counts.

	Sanction and Sigil: you pick ONE extra bonus (Regen, Refresh or food duration), which Windower can't see. Tell
	InfoGear with //ig sanction regen|refresh|food and //ig sigil regen|refresh|food. Each only works below an HP / MP
	threshold (Sanction: Regen under 95% HP, Refresh under 75% MP at Imperial Defense 8, BG-Wiki).
	Sanction's Regen / Refresh are 1 per tick (BG-Wiki). Sigil's amount isn't on BG-Wiki; 1 per tick is assumed.

	Signet gives Defense and Evasion only against an even-match-or-weaker target you are attacking, with no
	published amount, so it adds nothing here.
]]
return {
	[512] = {name = 'Ionis', stats = {
		['Accuracy'] = 20,				-- Couriers': Coalition Flag + Adoulinian Flag (BG-Wiki: +20 at Moderate)
		['Magic Accuracy'] = 0,			-- Couriers': same edifications, value unreadable on BG-Wiki
		['Evasion'] = 20,				-- Couriers': Signboard + Main Terrace (BG-Wiki: +20 at Moderate)
		['Magic Evasion'] = 0,			-- Couriers': same edifications, value unreadable on BG-Wiki
		['Critical hit rate'] = 0,		-- Couriers': Emblem + Bay Roof
		['Attack'] = 0,					-- Pioneers': Coalition Flag
		['Magic Atk. Bonus'] = 0,		-- Pioneers': Signboard
		['DEF'] = 0,					-- Peacekeepers': Coalition Flag
		['Magic Def. Bonus'] = 0,		-- Peacekeepers': Signboard
		['Regen'] = 0,					-- Peacekeepers': Emblem (HP / MP recovery)
		['Refresh'] = 0,				-- Peacekeepers': Emblem (HP / MP recovery)
		['Conserve MP'] = 0,			-- Scouts': Signboard
		['Fast Cast'] = 0,				-- Scouts': Emblem
	}},
	[256] = {name = 'Sanction', setting = 'sanction', options = {
		regen = {['Regen'] = 1}, refresh = {['Refresh'] = 1}, food = {},
	}},
	[268] = {name = 'Sigil', setting = 'sigil', options = {
		regen = {['Regen'] = 1}, refresh = {['Refresh'] = 1}, food = {},
	}},
	[253] = {name = 'Signet', stats = {}},
}
