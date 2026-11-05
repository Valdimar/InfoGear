--[[
	res/JSE_Neck_Ranks.lua (v1.10)

	Rank bonuses of the augmentable JSE necks (Dynamis - Divergence, one path each). Windower can't read these
	from the item (its extdata only gives the path and the rank), so InfoGear adds them from this table.

	Values are the bonuses at max rank (base R15, +1 R20, +2 R25), from BG-Wiki:
	https://www.bg-wiki.com/ffxi/Category:JSE_Necks
	Below max rank they are scaled by rank / max rank (rounded down), an estimate. Only stats InfoGear shows are
	listed; the others are in the comment on each line.
]]
return {
	[25417] = {job = "WAR", max_rank = 15, stats = {["HP"] = 50, ["STR"] = 10, ["DEX"] = 10, ["Double Attack"] = 5}},	-- Warrior's Beads
	[25418] = {job = "WAR", max_rank = 20, stats = {["HP"] = 75, ["STR"] = 12, ["DEX"] = 12, ["Double Attack"] = 6}},	-- War. Beads +1
	[25419] = {job = "WAR", max_rank = 25, stats = {["HP"] = 100, ["STR"] = 15, ["DEX"] = 15, ["Double Attack"] = 7}},	-- War. Beads +2
	[25423] = {job = "MNK", max_rank = 15, stats = {["DEX"] = 10, ["MND"] = 10, ["Physical Damage Limit"] = 6}},	-- Monk's Nodowa  -- not shown: Kick Attacks +15
	[25424] = {job = "MNK", max_rank = 20, stats = {["DEX"] = 12, ["MND"] = 12, ["Physical Damage Limit"] = 8}},	-- Mnk. Nodowa +1  -- not shown: Kick Attacks +20
	[25425] = {job = "MNK", max_rank = 25, stats = {["DEX"] = 15, ["MND"] = 15, ["Physical Damage Limit"] = 10}},	-- Mnk. Nodowa +2  -- not shown: Kick Attacks +25
	[25429] = {job = "WHM", max_rank = 15, stats = {["INT"] = 10, ["MND"] = 10, ["Fast Cast"] = 6, ["Enmity"] = -15}},	-- Cleric's Torque
	[25430] = {job = "WHM", max_rank = 20, stats = {["INT"] = 12, ["MND"] = 12, ["Fast Cast"] = 8, ["Enmity"] = -20}},	-- Clr. Torque +1
	[25431] = {job = "WHM", max_rank = 25, stats = {["INT"] = 15, ["MND"] = 15, ["Fast Cast"] = 10, ["Enmity"] = -25}},	-- Clr. Torque +2
	[25435] = {job = "BLM", max_rank = 15, stats = {["INT"] = 10, ["MND"] = 10, ["Magic Burst Bonus"] = 6}},	-- Sorcerer's Stole  -- not shown: Magic Burst ACC +15
	[25436] = {job = "BLM", max_rank = 20, stats = {["INT"] = 12, ["MND"] = 12, ["Magic Burst Bonus"] = 8}},	-- Src. Stole +1  -- not shown: Magic Burst ACC +20
	[25437] = {job = "BLM", max_rank = 25, stats = {["INT"] = 15, ["MND"] = 15, ["Magic Burst Bonus"] = 10}},	-- Src. Stole +2  -- not shown: Magic Burst ACC +25
	[25441] = {job = "RDM", max_rank = 15, stats = {["INT"] = 10, ["MND"] = 10}},	-- Duelist's Torque  -- not shown: Enh./Enf. Mag. eff. dur. +15%
	[25442] = {job = "RDM", max_rank = 20, stats = {["INT"] = 12, ["MND"] = 12}},	-- Dls. Torque +1  -- not shown: Enh./Enf. Mag. eff. dur. +20%
	[25443] = {job = "RDM", max_rank = 25, stats = {["INT"] = 15, ["MND"] = 15}},	-- Dls. Torque +2  -- not shown: Enh./Enf. Mag. eff. dur. +25%
	[25447] = {job = "THF", max_rank = 15, stats = {["DEX"] = 10, ["AGI"] = 10, ["Triple Attack"] = 2, ["Evasion"] = 15}},	-- Assassin's Gorget
	[25448] = {job = "THF", max_rank = 20, stats = {["DEX"] = 12, ["AGI"] = 12, ["Triple Attack"] = 3, ["Evasion"] = 20}},	-- Asn. Gorget +1
	[25449] = {job = "THF", max_rank = 25, stats = {["DEX"] = 15, ["AGI"] = 15, ["Triple Attack"] = 4, ["Evasion"] = 25}},	-- Asn. Gorget +2
	[25453] = {job = "PLD", max_rank = 15, stats = {["HP"] = 30, ["VIT"] = 10, ["MND"] = 10, ["DT"] = -5}},	-- Knight's Beads
	[25454] = {job = "PLD", max_rank = 20, stats = {["HP"] = 45, ["VIT"] = 12, ["MND"] = 12, ["DT"] = -6}},	-- Kgt. Beads +1
	[25455] = {job = "PLD", max_rank = 25, stats = {["HP"] = 60, ["VIT"] = 15, ["MND"] = 15, ["DT"] = -7}},	-- Kgt. Beads +2
	[25459] = {job = "DRK", max_rank = 15, stats = {["STR"] = 15, ["Store TP"] = 5, ["Physical Damage Limit"] = 6}},	-- Abyssal Beads
	[25460] = {job = "DRK", max_rank = 20, stats = {["STR"] = 20, ["Store TP"] = 6, ["Physical Damage Limit"] = 8}},	-- Abyssal Beads +1
	[25461] = {job = "DRK", max_rank = 25, stats = {["STR"] = 25, ["Store TP"] = 7, ["Physical Damage Limit"] = 10}},	-- Abyssal Beads +2
	[25465] = {job = "BST", max_rank = 15, stats = {["STR"] = 10, ["DEX"] = 10, ["Physical Damage Limit"] = 6}},	-- Beastmaster Collar  -- not shown: Pet: "Double Attack" +15%
	[25466] = {job = "BST", max_rank = 20, stats = {["STR"] = 12, ["DEX"] = 12, ["Physical Damage Limit"] = 8}},	-- Bst. Collar +1  -- not shown: Pet: "Double Attack" +20%
	[25467] = {job = "BST", max_rank = 25, stats = {["STR"] = 15, ["DEX"] = 15, ["Physical Damage Limit"] = 10}},	-- Bst. Collar +2  -- not shown: Pet: "Double Attack" +25%
	[25471] = {job = "BRD", max_rank = 15, stats = {["DEX"] = 15, ["CHR"] = 15, ["Store TP"] = 5, ["Physical Damage Limit"] = 6}},	-- Bard's Charm
	[25472] = {job = "BRD", max_rank = 20, stats = {["DEX"] = 20, ["CHR"] = 20, ["Store TP"] = 6, ["Physical Damage Limit"] = 8}},	-- Bard's Charm +1
	[25473] = {job = "BRD", max_rank = 25, stats = {["DEX"] = 25, ["CHR"] = 25, ["Store TP"] = 7, ["Physical Damage Limit"] = 10}},	-- Bard's Charm +2
	[25477] = {job = "RNG", max_rank = 15, stats = {["AGI"] = 15, ["Store TP"] = 5, ["Physical Damage Limit"] = 6}},	-- Scout's Gorget
	[25478] = {job = "RNG", max_rank = 20, stats = {["AGI"] = 20, ["Store TP"] = 6, ["Physical Damage Limit"] = 8}},	-- Scout's Gorget +1
	[25479] = {job = "RNG", max_rank = 25, stats = {["AGI"] = 25, ["Store TP"] = 7, ["Physical Damage Limit"] = 10}},	-- Scout's Gorget +2
	[25483] = {job = "SAM", max_rank = 15, stats = {["STR"] = 15, ["Store TP"] = 5, ["Physical Damage Limit"] = 6}},	-- Samurai's Nodowa
	[25484] = {job = "SAM", max_rank = 20, stats = {["STR"] = 20, ["Store TP"] = 6, ["Physical Damage Limit"] = 8}},	-- Sam. Nodowa +1
	[25485] = {job = "SAM", max_rank = 25, stats = {["STR"] = 25, ["Store TP"] = 7, ["Physical Damage Limit"] = 10}},	-- Sam. Nodowa +2
	[25489] = {job = "NIN", max_rank = 15, stats = {["DEX"] = 10, ["AGI"] = 10, ["Physical Damage Limit"] = 6}},	-- Ninja Nodowa  -- not shown: Daken +15
	[25490] = {job = "NIN", max_rank = 20, stats = {["DEX"] = 12, ["AGI"] = 12, ["Physical Damage Limit"] = 8}},	-- Ninja Nodowa +1  -- not shown: Daken +20
	[25491] = {job = "NIN", max_rank = 25, stats = {["DEX"] = 15, ["AGI"] = 15, ["Physical Damage Limit"] = 10}},	-- Ninja Nodowa +2  -- not shown: Daken +25
	[25495] = {job = "DRG", max_rank = 15, stats = {["STR"] = 10, ["VIT"] = 10, ["Physical Damage Limit"] = 6, ["Pet DT"] = -15}},	-- Dragoon's Collar
	[25496] = {job = "DRG", max_rank = 20, stats = {["STR"] = 12, ["VIT"] = 12, ["Physical Damage Limit"] = 8, ["Pet DT"] = -20}},	-- Dgn. Collar +1
	[25497] = {job = "DRG", max_rank = 25, stats = {["STR"] = 15, ["VIT"] = 15, ["Physical Damage Limit"] = 10, ["Pet DT"] = -25}},	-- Dgn. Collar +2
	[25501] = {job = "SMN", max_rank = 15, stats = {["MP"] = 30}},	-- Summoner's Collar  -- not shown: Avatar: All Base Stats +15, Blood Pact Damage +6%
	[25502] = {job = "SMN", max_rank = 20, stats = {["MP"] = 40}},	-- Smn. Collar +1  -- not shown: Avatar: All Base Stats +20, Blood Pact Damage +8%
	[25503] = {job = "SMN", max_rank = 25, stats = {["MP"] = 50}},	-- Smn. Collar +2  -- not shown: Avatar: All Base Stats +25, Blood Pact Damage +10%
	[25507] = {job = "BLU", max_rank = 15, stats = {["STR"] = 15, ["DEX"] = 15, ["Critical hit rate"] = 3, ["Store TP"] = 5}},	-- Mirage Stole
	[25508] = {job = "BLU", max_rank = 20, stats = {["STR"] = 20, ["DEX"] = 20, ["Critical hit rate"] = 4, ["Store TP"] = 6}},	-- Mirage Stole +1
	[25509] = {job = "BLU", max_rank = 25, stats = {["STR"] = 25, ["DEX"] = 25, ["Critical hit rate"] = 5, ["Store TP"] = 7}},	-- Mirage Stole +2
	[25513] = {job = "COR", max_rank = 15, stats = {["STR"] = 10, ["AGI"] = 10, ["Magic Atk. Bonus"] = 5}},	-- Commodore Charm  -- not shown: Magic Damage +15
	[25514] = {job = "COR", max_rank = 20, stats = {["STR"] = 12, ["AGI"] = 12, ["Magic Atk. Bonus"] = 6}},	-- Comm. Charm +1  -- not shown: Magic Damage +20
	[25515] = {job = "COR", max_rank = 25, stats = {["STR"] = 15, ["AGI"] = 15, ["Magic Atk. Bonus"] = 7}},	-- Comm. Charm +2  -- not shown: Magic Damage +25
	[25519] = {job = "PUP", max_rank = 15, stats = {["DEX"] = 10, ["AGI"] = 10, ["Physical Damage Limit"] = 6}},	-- Pup. Collar  -- not shown: Automaton: "Mag. Atk. Bns." +15
	[25520] = {job = "PUP", max_rank = 20, stats = {["DEX"] = 12, ["AGI"] = 12, ["Physical Damage Limit"] = 8}},	-- Pup. Collar +1  -- not shown: Automaton: "Mag. Atk. Bns." +20
	[25521] = {job = "PUP", max_rank = 25, stats = {["DEX"] = 15, ["AGI"] = 15, ["Physical Damage Limit"] = 10}},	-- Pup. Collar +2  -- not shown: Automaton: "Mag. Atk. Bns." +25
	[25525] = {job = "DNC", max_rank = 15, stats = {["DEX"] = 15, ["CHR"] = 15, ["Store TP"] = 5, ["Physical Damage Limit"] = 6}},	-- Etoile Gorget
	[25526] = {job = "DNC", max_rank = 20, stats = {["DEX"] = 20, ["CHR"] = 20, ["Store TP"] = 6, ["Physical Damage Limit"] = 8}},	-- Etoile Gorget +1
	[25527] = {job = "DNC", max_rank = 25, stats = {["DEX"] = 25, ["CHR"] = 25, ["Store TP"] = 7, ["Physical Damage Limit"] = 10}},	-- Etoile Gorget +2
	[25531] = {job = "SCH", max_rank = 15, stats = {["INT"] = 10, ["MND"] = 10}},	-- Argute Stole  -- not shown: Magic Damage +15, Helix eff. Duration +6%
	[25532] = {job = "SCH", max_rank = 20, stats = {["INT"] = 12, ["MND"] = 12}},	-- Argute Stole +1  -- not shown: Magic Damage +20, Helix eff. Duration +8%
	[25533] = {job = "SCH", max_rank = 25, stats = {["INT"] = 15, ["MND"] = 15}},	-- Argute Stole +2  -- not shown: Magic Damage +25, Helix eff. Duration +10%
	[25537] = {job = "GEO", max_rank = 15, stats = {["MP"] = 30}},	-- Bagua Charm  -- not shown: Luopan Duration +15%, Luopan: Absorbs Damage +6%
	[25538] = {job = "GEO", max_rank = 20, stats = {["MP"] = 40}},	-- Bagua Charm +1  -- not shown: Luopan Duration +20%, Luopan: Absorbs Damage +8%
	[25539] = {job = "GEO", max_rank = 25, stats = {["MP"] = 50}},	-- Bagua Charm +2  -- not shown: Luopan Duration +25%, Luopan: Absorbs Damage +10%
	[25543] = {job = "RUN", max_rank = 15, stats = {["HP"] = 30, ["STR"] = 10, ["MND"] = 10, ["DT"] = -5}},	-- Futhark Torque
	[25544] = {job = "RUN", max_rank = 20, stats = {["HP"] = 45, ["STR"] = 12, ["MND"] = 12, ["DT"] = -6}},	-- Futhark Torque +1
	[25545] = {job = "RUN", max_rank = 25, stats = {["HP"] = 60, ["STR"] = 15, ["MND"] = 15, ["DT"] = -7}},	-- Futhark Torque +2
}
