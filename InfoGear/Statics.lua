-- Statics.lua
-- The addon's shared state, made when it loads: the player table, the running totals, the numbers added by hand,
-- the default settings (written to data/<name>_settings.xml the first time a character logs in) and the defaults
-- for party Bards / CORs / GEOs. Everything here is global so every file can read it.


-- get_player() returns nil on the character-select / login screen, so fall back to an empty table.
-- The 'login' event reloads the addon once a character is actually in the world.
-- the player, refreshed every quarter second by the prerender loop (InfoGear.lua)
player = windower.ffxi.get_player() or {}
-- slot -> the item table with its parsed stats (filled by check_equipped / get_equip_stats)
player.equipment = T{}
-- base stats from packet 0x061 (without gear)
player.stats = {STR = 0, DEX = 0, VIT = 0, AGI = 0, INT = 0, MND = 0, CHR = 0}
player.skill = player.skills
-- combat skills without gear (packet 0x062); skill from gear is added in get_player_skill_in_gear
player_base_skills = player.skills or {}
-- movement, sent to Gearswap; position is used to notice moving
player.is_moving = false
player.position = {x = 0, y = 0, z = 0}
buff = 0
-- every item you own with its parsed stats, read from data/<name>_data.lua
full_gear_table_from_file = T{}
-- Totals from your buffs, rebuilt by calculate_total_haste() (Buff_Processing.lua) from each buff's details.
-- ma_haste / ja_haste / g_haste are magic / job ability / gear-type haste in 1/1024ths.
Buffs_inform = {['delay'] = 0,['DEF'] = 0,['HP'] = 0,['MP'] = 0,['STR'] = 0,['DEX'] = 0,['VIT'] = 0,['AGI'] = 0,['INT'] = 0,['MND'] = 0,['CHR'] = 0,
								['Accuracy'] = 0,['Attack'] = 0, ['Attack perc'] = 0, ['Defense perc'] = 0,
								['Ranged Accuracy'] = 0, ['Ranged Attack'] = 0,
								['Evasion'] = 0,
								['Magic Accuracy'] = 0, ['Magic Atk. Bonus'] = 0,
								['Magic Evasion'] = 0,['Magic Def. Bonus'] = 0,
								['ma_haste'] = 0,['ja_haste'] = 0,
								['g_haste'] = 0,['Attack perc'] = 0,
								['PDT'] = 0,['MDT'] = 0,['BDT'] = 0,['DT'] = 0,['MDT2'] = 0,['PDT2'] = 0,
								['Store TP'] = 0,['Dual Wield'] = 0 ,['Fast Cast'] = 0 ,['Martial Arts'] = 0,['damage'] = 0,
								["Double Attack"] = 0,["Tripple Attack"] = 0,['Quadruple Attack'] = 0,["Critical hit rate"] = 0,["Critical hit damage"] = 0,["Subtle Blow"] = 0,
								}
-- The status effects a GEO bubble (Indi- / Geo-) can give you, by buff id
Geo_buffs = {
	{id=539,en="Regen",							},
	{id=541,en="Refresh",						},
	{id=580,en="Haste",							},
	{id=542,en="STR Boost",					},
	{id=543,en="DEX Boost",					},
	{id=544,en="VIT Boost",					},
	{id=545,en="AGI Boost",					},
	{id=546,en="INT Boost",					},
	{id=547,en="MND Boost",					},
	{id=548,en="CHR Boost",					},
	{id=549,en="Attack Boost",				},
	{id=550,en="Defense Boost",				},
	{id=551,en="Magic Atk. Boost",			},
	{id=552,en="Magic Def. Boost",			},
	{id=553,en="Accuracy Boost",			},
	{id=554,en="Evasion Boost",				},
	{id=555,en="Magic Acc. Boost",			},
	{id=556,en="Magic Evasion Boost",	},
}
-- Element of the day -> the stat its bubble / roll boosts (7 = all)
ele_to_stat = {
	[0] = {id=0,en="STR"},
	[1] = {id=1,en="INT"},
	[2] = {id=2,en="AGI"},
	[3] = {id=3,en="VIT"},
	[4] = {id=4,en="DEX"},
	[5] = {id=5,en="MND"},
	[6] = {id=6,en="CHR"},
	[7] = {id=7,en={[1]="STR",[2]="INT",[3]="AGI",[4]="VIT",[5]="DEX",[6]="MND",[7]="CHR"}},
}
-- Gear totals (all equipped items + set bonuses + food etc.), rebuilt every update by Display.update()
Gear_info = T{}
-- party / alliance members: name, job, buffs they've given you (Packet_parsing.lua)
member_table = T{}
-- whether the buff-duration packet (0x063 type 9) has been seen yet
seen_0x063_type9 = false
delay_0x063_v9 = false
-- //ig debug
debug_mode = false
party_from_packet = {}

-- Details InfoGear works out about you: buff_details = one entry per buff with what it gives (Buff_Processing.lua)
_ExtraData = {
        player = {buff_details = {}},
        pet = {},
        world = {in_mog_house = false,conquest=false},
    }

-- the last values sent to Gearswap, so it's only told when something changes
old_inform = {}
-- Numbers added by hand with //ig stp / dw / ghaste / mhaste / jahaste / dwn (until reload)
manual_stp = 0
manual_dw = 0
manual_ghaste = 0
manual_mhaste = 0
manual_jahaste = 0
manual_dw_needed = 0
-- Song / roll / Geomancy bonus for party BRD / COR / GEO not on your list (//ig brd / cor / geo <n>)
manual_bard_duration_bonus = 0
manual_COR_bonus = 0
manual_GEO_bonus  = 0
manual_hide = false
-- TP per hit kept with //ig wstp save, shown as a second line on the TP cards
WSTP = 0
update_gs = true
show_total_haste = true
show_tp_Stuff = true
show_acc_Stuff = true
-- Dual Wield needed last time (sent to Gearswap only when it changes)
old_DW_needed = 0
DW = false
-- //ig dnc: Haste Samba comes from a main DNC (stronger)
dancer_main = false
-- the COR who used Crooked Cards and whether their next roll gets it
Crooked_cards = {name = '', bool = false}
__raw = {lower = string.lower, upper = string.upper,}

-- "Store TP" -> "store_tp": the way Windower names merits / job points
function to_windower_api(str)
    return __raw.lower(str:gsub(' ','_'))
end

-- the stats that are added up from items
stat_names = L{'delay','DEF','HP','MP','STR','DEX','VIT','AGI','INT','MND','CHR',
								'Accuracy','Attack',
								'Ranged Accuracy', 'Ranged Attack',
								'Evasion',
								'Magic Accuracy', 'Magic Atk. Bonus',
								'Magic Evasion','Magic Def. Bonus',
								'ma_haste','ja_haste',
								'PDT','MDT','BDT','DT','MDT2','PDT2',
								'Store TP','Dual Wield' ,'Fast Cast' ,'Martial Arts','damage',
								"Double Attack","Tripple Attack",'Quadruple Attack',"Critical hit rate","Critical hit damage","Subtle Blow",
								}
							
-- Default settings for a new character. config.load() fills in anything missing from the saved file, so a new
-- setting only needs a default here.
defaults = {}
defaults.player = {}
-- main cards shown by default (//ig show <name>)
defaults.player.show_total_haste = true
defaults.player.show_tp_Stuff = true
defaults.player.show_acc_Stuff = false
defaults.player.show_dt_Stuff = false
defaults.player.show_att_Stuff = false
defaults.player.show_Evasion = false
defaults.player.show_Defence = false
defaults.player.show_STP = false
defaults.player.show_speed = true
defaults.parser_version = 0	-- set by InfoGear; see GEAR_PARSER_VERSION
defaults.player.show_DW_Stuff = false
defaults.player.show_MA_Stuff = false
-- chat message for each Phantom Roll (//ig cor msgs)
defaults.player.show_COR_messages = true
-- send haste / DW to Gearswap (//ig ugs)
defaults.player.update_gs = true
-- Unity rank (//ig rank)
defaults.player.rank = 1
-- party members with their bonuses: name = song settings / roll bonus / Geomancy bonus (//ig brd|cor|geo add)
defaults.Bards = {}
defaults.Cors = {}
defaults.Cors['qultada'] = 0
defaults.Geos = {}
defaults.Geos['Sylvie'] = 0
-- where the display is and how it looks (//ig scale / columns / size, dragging)
defaults.display = {}
defaults.display.pos = {}
defaults.display.pos.x = 0
defaults.display.pos.y = 0
defaults.display.scale = 1		-- //ig scale 0.5 - 2
defaults.display.columns = 4		-- //ig columns 4 - 6
defaults.display.size = 'normal'	-- //ig size normal | small

-- Song settings for a bard (the trusts Joachim and Ulmia here): Gjallarhorn, song merits / job points,
-- empyrean armor bonus and +songs per song (song_bonus.all_songs adds to every song).
defaults.Bards["joachim"] = {
	['gjallarhorn'] = false,
	['merits'] = {
		['minne'] = 0,
		['minuet'] = 0,
		['madrigal'] = 0,
	},
	['jp'] = {
		['minne'] = 0,
		['minuet'] = 0,
	},
	['emperean_armor_bonus'] = 0,
	['song_bonus'] = {
		['all_songs'] = 0,
		['paeon'] = 0,
		['ballad'] = 0,
		['minne'] = 0,
		['minuet'] = 0,
		['madrigal'] = 0,
		['prelude'] = 0,
		['mambo'] = 0,
		['march'] = 0,
		['etude'] = 0,
		['carol'] = 0,
		['mazurka'] = 0,
	},
}
defaults.Bards["ulmia"] = {
	['gjallarhorn'] = false,
	['merits'] = {
		['minne'] = 0,
		['minuet'] = 0,
		['madrigal'] = 0,
	},
	['jp'] = {
		['minne'] = 0,
		['minuet'] = 0,
	},
	['emperean_armor_bonus'] = 0,
	['song_bonus'] = {
		['all_songs'] = 0,
		['paeon'] = 0,
		['ballad'] = 0,
		['minne'] = 0,
		['minuet'] = 0,
		['madrigal'] = 0,
		['prelude'] = 0,
		['mambo'] = 0,
		['march'] = 0,
		['etude'] = 0,
		['carol'] = 0,
		['mazurka'] = 0,
	},
}

-- What //ig brd add <name> <bonus> starts a bard with (a fully geared player bard)
default_bard_settings = {
	['gjallarhorn'] = true,
	['merits'] = {
		['minne'] = 0,
		['minuet'] = 5,
		['madrigal'] = 5,
	},
	['jp'] = {
		['minne'] = 20,
		['minuet'] = 20,
	},
	['emperean_armor_bonus'] = 3,
	['song_bonus'] = {
		['all_songs'] = 0,
		['paeon'] = 0,
		['ballad'] = 0,
		['minne'] = 0,
		['minuet'] = 0,
		['madrigal'] = 0,
		['prelude'] = 0,
		['mambo'] = 0,
		['march'] = 0,
		['etude'] = 0,
		['carol'] = 0,
		['mazurka'] = 0,
	},
}

-- the display: sections.background (the panel) and sections.block[n] (the cards), see Image_processing.lua
sections = {}
sections.block= {}












