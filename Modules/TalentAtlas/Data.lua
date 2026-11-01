-- TalentAtlas data (TBC Classic / Anniversary). All strings are English keys
-- that the module routes through S.L.
-- Sources cross-checked: the game's own racial tooltips (wowcalc.net wiki),
-- Warcraft Wiki reagent table, Blizzard Watch reagent list, wow-guides.com
-- weapon table (read from the game's skill data), Wowhead and
-- classicwow.gg stat-cap tools, wowcalc.net class stat pages.
local _, ns = ...
local TD = {}
ns.TalentAtlasData = TD

TD.expansions = {
	[1] = "Classic", [2] = "The Burning Crusade", [3] = "Wrath of the Lich King", [4] = "Cataclysm",
	[5] = "Mists of Pandaria", [6] = "Warlords of Draenor", [7] = "Legion", [8] = "Battle for Azeroth",
	[9] = "Shadowlands", [10] = "Dragonflight", [11] = "The War Within", [12] = "Midnight",
}

TD.classOrder = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
	"DEATHKNIGHT", "MONK", "DEMONHUNTER", "EVOKER" }

local function spec(name, role, primary, stats, cap)
	return { name = name, role = role, primary = primary, stats = stats, cap = cap }
end

TD.classes = {
	DRUID = {
		since = 1, name = "Druid", resource = "Mana, Energy, Rage",
		armor = { "Cloth", "Leather" },
		weapons = { "Daggers", "Fist Weapons", "One-Handed Maces", "Two-Handed Maces", "Staves" },
		extra = { "No shields, no dual wield", "Relic slot: Idols" },
		reagents = {
			{ "Maple, Stranglethorn, Ashwood, Hornbeam, Ironwood and Flintweed Seed", "Rebirth (by rank)" },
			{ "Wild Berries, Wild Thornroot, Wild Quillvine", "Gift of the Wild (by rank)" },
		},
		utility = {
			"Mark of the Wild / Gift of the Wild: +340 armor, +14 stats, +25 resistances",
			"Innervate (mana) and Rebirth (battle resurrection)",
			"Moonkin Aura: +5% spell crit for the party (Balance)",
			"Leader of the Pack: +5% melee and ranged crit (Feral)",
			"Improved Faerie Fire: +3% chance for attackers to hit the target (Balance)",
			"Tree of Life Aura: healing received scales with the Druid's Spirit (Restoration)",
			"Mangle: +30% bleed damage taken by the target (Feral)",
			"Forms break roots and slows; Travel, Aquatic and Flight Form",
		},
		specs = {
			spec("Balance", "DPS", "Intellect", { "Spell damage", "Hit", "Critical strike", "Spell haste" }, "Spell hit: 16%, or 12% with Balance of Power (152 rating)"),
			spec("Feral DPS", "DPS", "Agility", { "Agility", "Strength", "Hit", "Expertise" }, "Melee hit: 9% (142 rating)"),
			spec("Feral Tank", "TANK", "Agility and Stamina", { "Expertise", "Agility", "Stamina", "Hit" }, "Crit immunity: Survival of the Fittest gives 3% of the 5.6% needed, defense or resilience the rest; expertise 26 (6.5% dodge) and 9% hit for threat"),
			spec("Restoration", "HEALER", "Intellect", { "+Healing", "Spirit", "Intellect", "Mana per 5 sec" }, "No hard cap"),
		},
	},
	HUNTER = {
		since = 1, name = "Hunter", resource = "Mana",
		armor = { "Cloth", "Leather", "Mail (from level 40)" },
		weapons = { "Bows", "Crossbows", "Guns", "Thrown", "Daggers", "Fist Weapons", "One-Handed Axes", "Two-Handed Axes",
			"One-Handed Swords", "Two-Handed Swords", "Polearms (level 20)", "Staves" },
		extra = { "Can dual wield, no shields", "Needs ammunition (arrows or bullets) and an ammo pouch or quiver", "Pet food for the pet" },
		reagents = {
			{ "Arrows or Bullets", "Auto Shot and all ranged shots" },
			{ "Pet food (by diet)", "Feed Pet keeps the pet happy" },
		},
		utility = {
			"Misdirection: sends your threat to the tank",
			"Trueshot Aura: +125 attack power for the party (Marksmanship)",
			"Hunter's Mark: +110 attack power against the target (Improved Hunter's Mark raises it)",
			"Ferocious Inspiration: +3% damage for the party (Beast Mastery)",
			"Expose Weakness: attack power for melee (Survival)",
			"Aspect of the Viper restores mana; Tranquilizing Shot removes Enrage",
			"Traps, Feign Death, Scatter Shot and Concussive Shot",
		},
		specs = {
			spec("Beast Mastery", "DPS", "Agility", { "Agility", "Hit", "Critical strike", "Ranged attack power" }, "Ranged hit: 9% (142 rating)"),
			spec("Marksmanship", "DPS", "Agility", { "Agility", "Hit", "Critical strike", "Ranged attack power" }, "Ranged hit: 9% (142 rating)"),
			spec("Survival", "DPS", "Agility", { "Agility", "Hit", "Critical strike", "Ranged attack power" }, "Ranged hit: 9%, or 6% with Surefooted (95 rating)"),
		},
	},
	MAGE = {
		since = 1, name = "Mage", resource = "Mana",
		armor = { "Cloth" },
		weapons = { "Daggers", "One-Handed Swords", "Staves", "Wands" },
		extra = { "Wands are a default skill (Mage, Priest, Warlock only)" },
		reagents = {
			{ "Arcane Powder", "Arcane Brilliance, Ritual of Refreshment" },
			{ "Rune of Teleportation", "Teleport to a capital city" },
			{ "Rune of Portals", "Portal for the group" },
			{ "Light Feather", "Slow Fall" },
		},
		utility = {
			"Arcane Brilliance: +40 Intellect for the group",
			"Amplify Magic / Dampen Magic",
			"Conjured food and water, Ritual of Refreshment",
			"Portals and Teleports",
			"Polymorph (crowd control), Counterspell, Spellsteal",
			"Improved Scorch: +15% fire damage taken by the target (Fire)",
			"Winter's Chill: +10% frost crit chance against the target (Frost)",
			"Evocation, mana gems and potions refill mana",
		},
		specs = {
			spec("Arcane", "DPS", "Intellect", { "Spell damage", "Hit", "Intellect", "Spell haste" }, "Spell hit: 16%, or 6% for Arcane spells (76 rating)"),
			spec("Fire", "DPS", "Intellect", { "Spell damage", "Hit", "Critical strike", "Spell haste" }, "Spell hit: 16%, or 13% with Elemental Precision (164 rating)"),
			spec("Frost", "DPS", "Intellect", { "Spell damage", "Hit", "Critical strike", "Spell haste" }, "Spell hit: 16%, or 13% with Elemental Precision (164 rating)"),
		},
	},
	PALADIN = {
		since = 1, name = "Paladin", resource = "Mana",
		armor = { "Cloth", "Leather", "Mail", "Plate (from level 40)", "Shields" },
		weapons = { "One-Handed Axes", "Two-Handed Axes", "One-Handed Maces", "Two-Handed Maces", "One-Handed Swords",
			"Two-Handed Swords", "Polearms (level 20)" },
		extra = { "No dual wield", "Relic slot: Librams" },
		reagents = {
			{ "Symbol of Kings", "Greater Blessings" },
			{ "Symbol of Divinity", "Divine Intervention" },
		},
		utility = {
			"Blessings: Kings, Might, Wisdom, Salvation, Light, Sanctuary",
			"Auras: Devotion, Retribution, Concentration, Resistance, Sanctity",
			"Judgements: Wisdom, Light, Crusader, Justice",
			"Divine Intervention, Lay on Hands, Hand spells",
			"Horde Paladins exist since Blood Elves (Burning Crusade)",
		},
		specs = {
			spec("Holy", "HEALER", "Intellect", { "+Healing", "Intellect", "Critical strike", "Mana per 5 sec" }, "No hard cap"),
			spec("Protection", "TANK", "Stamina", { "Defense", "Stamina", "Spell damage", "Dodge, parry and block" }, "Defense: 490 (about 332 rating) for crit immunity"),
			spec("Retribution", "DPS", "Strength", { "Weapon damage", "Strength", "Hit", "Critical strike" }, "Melee hit: 9% (142 rating)"),
		},
	},
	PRIEST = {
		since = 1, name = "Priest", resource = "Mana",
		armor = { "Cloth" },
		weapons = { "Daggers", "One-Handed Maces", "Staves", "Wands" },
		extra = { "Wands are a default skill (Mage, Priest, Warlock only)" },
		reagents = {
			{ "Holy Candle", "Prayer of Fortitude (rank 1)" },
			{ "Sacred Candle", "Prayer of Fortitude (rank 2), Prayer of Spirit, Prayer of Shadow Protection" },
			{ "Devout Candle", "Prayer of Fortitude and the prayers at the highest rank" },
			{ "Light Feather", "Levitate" },
		},
		utility = {
			"Power Word: Fortitude, Divine Spirit, Shadow Protection (and the Prayers)",
			"Fear Ward, Dispel Magic, Abolish Disease, Mass Dispel",
			"Power Infusion (Discipline), Prayer of Mending, Shadowfiend (mana)",
			"Misery: +3% spell hit taken by the target (Shadow)",
			"Shadow Weaving: +10% shadow damage taken by the target (Shadow)",
			"Levitate, Mind Control, Shackle Undead",
		},
		specs = {
			spec("Discipline", "HEALER", "Intellect", { "+Healing", "Intellect", "Spirit", "Mana per 5 sec" }, "No hard cap"),
			spec("Holy", "HEALER", "Intellect", { "+Healing", "Spirit", "Intellect", "Mana per 5 sec" }, "No hard cap"),
			spec("Shadow", "DPS", "Intellect", { "Spell damage", "Hit", "Spell haste", "Critical strike" }, "Spell hit: 16%, or 6% with Shadow Focus (76 rating)"),
		},
	},
	ROGUE = {
		since = 1, name = "Rogue", resource = "Energy, Combo Points",
		armor = { "Cloth", "Leather" },
		weapons = { "Bows", "Crossbows", "Guns", "Thrown", "Daggers", "Fist Weapons", "One-Handed Maces", "One-Handed Swords" },
		extra = { "Can dual wield, no shields", "Poisons are crafted/bought consumables (learned at level 20)" },
		reagents = {
			{ "Flash Powder", "Vanish" },
			{ "Instant and Deadly Poison", "Weapon coatings (consumable)" },
		},
		utility = {
			"Sap, Gouge, Blind and Kick (crowd control and interrupt)",
			"Cloak of Shadows and Evasion",
			"Expose Armor, Wound Poison (-50% healing) and Mind-numbing Poison (+60% cast time)",
			"Hemorrhage: +10% physical damage taken by the target (Subtlety)",
			"Distract, Stealth and Lockpicking (chests, doors)",
			"Vanish and Shadowstep",
		},
		specs = {
			spec("Assassination", "DPS", "Agility", { "Hit", "Agility", "Attack power", "Critical strike" }, "Melee hit: 9%, or 4% with Precision (64 rating)"),
			spec("Combat", "DPS", "Agility", { "Hit", "Expertise", "Agility", "Haste" }, "Melee hit: 9%, or 4% with Precision (64 rating)"),
			spec("Subtlety", "DPS", "Agility", { "Agility", "Resilience", "Stamina", "Critical strike" }, "Melee hit: 5% against players, 9% in raids"),
		},
	},
	SHAMAN = {
		since = 1, name = "Shaman", resource = "Mana",
		armor = { "Cloth", "Leather", "Mail (from level 40)", "Shields" },
		weapons = { "Daggers", "Fist Weapons", "One-Handed Axes", "Two-Handed Axes", "One-Handed Maces", "Two-Handed Maces", "Staves" },
		extra = { "Dual wield with the Dual Wield talent (Enhancement)", "Relic slot: Totems" },
		reagents = {
			{ "Ankh", "Reincarnation" },
			{ "Shiny Fish Scales", "Water Breathing" },
			{ "Fish Oil", "Water Walking" },
		},
		utility = {
			"Bloodlust (Horde) / Heroism (Alliance)",
			"Totems: Windfury, Grace of Air, Strength of Earth, Mana Spring, Wrath of Air, Totem of Wrath, Tranquil Air, Healing Stream",
			"Mana Tide Totem and Earth Shield (Restoration)",
			"Totem of Wrath: +3% spell hit and crit for the party (Elemental)",
			"Unleashed Rage: +10% attack power for the party (Enhancement)",
			"Stormstrike: +20% nature damage taken by the target (Enhancement)",
			"Purge, Grounding Totem, Tremor Totem",
			"Reincarnation (needs an Ankh)",
		},
		specs = {
			spec("Elemental", "DPS", "Intellect", { "Spell damage", "Hit", "Critical strike", "Spell haste" }, "Spell hit: 16%, or 7% with Elemental Precision and Totem of Wrath (89 rating)"),
			spec("Enhancement", "DPS", "Strength", { "Hit", "Expertise", "Strength", "Critical strike" }, "Melee hit: 9%, or 3% with Dual Wield Specialization (48 rating)"),
			spec("Restoration", "HEALER", "Intellect", { "+Healing", "Mana per 5 sec", "Intellect", "Spell haste" }, "No hard cap"),
		},
	},
	WARLOCK = {
		since = 1, name = "Warlock", resource = "Mana (Life Tap), Soul Shards",
		armor = { "Cloth" },
		weapons = { "Daggers", "One-Handed Swords", "Staves", "Wands" },
		extra = { "Wands are a default skill (Mage, Priest, Warlock only)" },
		reagents = {
			{ "Soul Shard", "Summons, Soulstone, Healthstone, rituals (dropped, via Drain Soul)" },
			{ "Infernal Stone", "Inferno" },
			{ "Demonic Figurine", "Ritual of Doom" },
		},
		utility = {
			"Curses: Elements, Recklessness, Weakness, Tongues, Doom, Agony",
			"Healthstone, Soulstone and Ritual of Summoning",
			"Curse of Recklessness: -800 armor on the target",
			"Improved Shadow Bolt: +20% shadow damage taken for 4 hits",
			"Demons: Imp, Voidwalker, Succubus, Felhunter, Felguard",
			"Life Tap converts health into mana",
			"Fel Armor / Demon Armor, Unending Breath, Eye of Kilrogg",
		},
		specs = {
			spec("Affliction", "DPS", "Intellect", { "Spell damage", "Hit", "Spell haste", "Stamina" }, "Spell hit: 16%, or 6% for Affliction spells (76 rating)"),
			spec("Demonology", "DPS", "Intellect", { "Spell damage", "Hit", "Stamina", "Spell haste" }, "Spell hit: 16% (202 rating)"),
			spec("Destruction", "DPS", "Intellect", { "Spell damage", "Hit", "Critical strike", "Spell haste" }, "Spell hit: 16% (202 rating)"),
		},
	},
	WARRIOR = {
		since = 1, name = "Warrior", resource = "Rage",
		armor = { "Cloth", "Leather", "Mail", "Plate (from level 40)", "Shields" },
		weapons = { "Bows", "Crossbows", "Guns", "Thrown", "Daggers", "Fist Weapons", "One-Handed Axes", "Two-Handed Axes",
			"One-Handed Maces", "Two-Handed Maces", "One-Handed Swords", "Two-Handed Swords", "Polearms (level 20)", "Staves" },
		extra = { "Can dual wield (Fury)", "Needs no reagents" },
		reagents = {},
		utility = {
			"Battle Shout (+306 attack power) and Commanding Shout (+1080 health)",
			"Demoralizing Shout (-attack power), Thunder Clap (-20% attack speed) and Sunder Armor",
			"Blood Frenzy: +4% physical damage taken by the target (Arms)",
			"Taunt, Mocking Blow, Challenging Shout",
			"Shield Wall, Last Stand, Intervene (Protection)",
			"Pummel / Shield Bash (interrupts) and Berserker Rage",
		},
		specs = {
			spec("Arms", "DPS", "Strength", { "Hit", "Expertise", "Strength", "Critical strike" }, "Melee hit: 9% (142 rating)"),
			spec("Fury", "DPS", "Strength", { "Hit", "Expertise", "Strength", "Critical strike" }, "Melee hit: 9%, or 6% with Precision (95 rating)"),
			spec("Protection", "TANK", "Stamina", { "Defense", "Stamina", "Dodge, parry and block", "Armor" }, "Defense: 490 (about 332 rating) for crit immunity"),
		},
	},
	-- later expansions: overview only
	DEATHKNIGHT = { since = 3, name = "Death Knight", resource = "Runes, Runic Power", roles = "Tank, Melee DPS", armor = { "Plate" },
		overview = "Rune-powered melee fighter combining heavy armor, diseases and dark magic." },
	MONK = { since = 5, name = "Monk", resource = "Energy, Mana, Chi", roles = "Tank, Healer, Melee DPS", armor = { "Leather" },
		overview = "Mobile martial artist with distinct tanking, healing and damage specializations." },
	DEMONHUNTER = { since = 7, name = "Demon Hunter", resource = "Fury, Pain", roles = "Tank, Melee DPS", armor = { "Leather" },
		overview = "Highly mobile fel-powered fighter specializing in aggressive damage or active tanking." },
	EVOKER = { since = 10, name = "Evoker", resource = "Mana, Essence", roles = "Ranged DPS, Healer, Support", armor = { "Mail" },
		overview = "Dracthyr spellcaster with empowered abilities, mid-range magic, healing and support." },
}

-- races: {key, name, faction, since, zone, classes, racials{ {name, desc [, only]} }}
TD.races = {
	{ key = "human", name = "Human", faction = "Alliance", since = 1, zone = "Elwynn Forest",
		classes = { "WARRIOR", "PALADIN", "ROGUE", "PRIEST", "MAGE", "WARLOCK" },
		racials = {
			{ "Perception", "Stealth detection for 20 sec (3 min cooldown)" },
			{ "Diplomacy", "Reputation gains +10%" },
			{ "Mace Specialization", "+5 expertise with maces and two-handed maces" },
			{ "Sword Specialization", "+5 expertise with swords and two-handed swords" },
			{ "The Human Spirit", "Spirit +10%" },
		} },
	{ key = "dwarf", name = "Dwarf", faction = "Alliance", since = 1, zone = "Dun Morogh",
		classes = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST" },
		racials = {
			{ "Stoneform", "Immune to bleed, poison and disease, armor +10% for 8 sec (3 min cooldown)" },
			{ "Find Treasure", "Shows nearby treasure on the minimap" },
			{ "Frost Resistance", "Frost resistance +10" },
			{ "Gun Specialization", "+1% critical strike chance with guns" },
		} },
	{ key = "nightelf", name = "Night Elf", faction = "Alliance", since = 1, zone = "Teldrassil",
		classes = { "WARRIOR", "HUNTER", "ROGUE", "PRIEST", "DRUID" },
		racials = {
			{ "Shadowmeld", "Harder to detect; stealth boost for Rogues and Druids" },
			{ "Quickness", "Dodge chance +1%" },
			{ "Nature Resistance", "Nature resistance +10" },
			{ "Wisp Spirit", "Wisp form after death, +50% speed" },
			{ "Elune's Grace", "-20% chance to be hit by melee and ranged for 15 sec", "PRIEST" },
			{ "Starshards", "785 Arcane damage over 15 sec", "PRIEST" },
		} },
	{ key = "gnome", name = "Gnome", faction = "Alliance", since = 1, zone = "Dun Morogh",
		classes = { "WARRIOR", "ROGUE", "MAGE", "WARLOCK" },
		racials = {
			{ "Escape Artist", "Frees you from roots and slows (1.75 min cooldown)" },
			{ "Expansive Mind", "Intellect +5%" },
			{ "Arcane Resistance", "Arcane resistance +10" },
			{ "Engineering Specialization", "Engineering skill +15" },
		} },
	{ key = "draenei", name = "Draenei", faction = "Alliance", since = 2, zone = "Azuremyst Isle",
		classes = { "WARRIOR", "PALADIN", "HUNTER", "PRIEST", "SHAMAN", "MAGE" },
		racials = {
			{ "Heroic Presence", "+1% hit chance for you and your party within 30 yards", "WARRIOR, PALADIN, HUNTER" },
			{ "Inspiring Presence", "+1% spell hit chance for you and your party within 30 yards", "PRIEST, SHAMAN, MAGE" },
			{ "Gift of the Naaru", "Heals 1085 over 15 sec (3 min cooldown)" },
			{ "Gemcutting", "Jewelcrafting skill +5" },
			{ "Shadow Resistance", "Shadow resistance +10" },
		} },
	{ key = "orc", name = "Orc", faction = "Horde", since = 1, zone = "Durotar",
		classes = { "WARRIOR", "HUNTER", "ROGUE", "SHAMAN", "WARLOCK" },
		racials = {
			{ "Blood Fury", "+282 attack power (Warlock: +143 spell damage), -50% healing received, 15 sec (2 min cooldown)" },
			{ "Axe Specialization", "+5 expertise with axes and two-handed axes" },
			{ "Hardiness", "Stun resistance +15%" },
		} },
	{ key = "undead", name = "Undead", faction = "Horde", since = 1, zone = "Tirisfal Glades",
		classes = { "WARRIOR", "ROGUE", "PRIEST", "MAGE", "WARLOCK" },
		racials = {
			{ "Will of the Forsaken", "Immune to charm, fear and sleep for 5 sec (2 min cooldown)" },
			{ "Cannibalize", "Regenerates 7% health every 2 sec for 10 sec from a corpse" },
			{ "Shadow Resistance", "Shadow resistance +10" },
			{ "Underwater Breathing", "Underwater breath lasts 300% longer" },
			{ "Devouring Plague", "1216 Shadow damage over 24 sec, heals the caster", "PRIEST" },
			{ "Touch of Weakness", "Punishes the next melee attacker", "PRIEST" },
		} },
	{ key = "tauren", name = "Tauren", faction = "Horde", since = 1, zone = "Mulgore",
		classes = { "WARRIOR", "HUNTER", "SHAMAN", "DRUID" },
		racials = {
			{ "War Stomp", "Stuns up to 5 enemies within 8 yards for 2 sec (2 min cooldown)" },
			{ "Endurance", "Total health +5%" },
			{ "Cultivation", "Herbalism skill +15" },
			{ "Nature Resistance", "Nature resistance +10" },
		} },
	{ key = "troll", name = "Troll", faction = "Horde", since = 1, zone = "Durotar",
		classes = { "WARRIOR", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE" },
		racials = {
			{ "Berserking", "+10% to 30% attack and casting speed for 10 sec (3 min cooldown)" },
			{ "Beast Slaying", "+5% damage against beasts" },
			{ "Regeneration", "Health regeneration +10%, 10% continues in combat" },
			{ "Bow Specialization", "+1% critical strike chance with bows" },
			{ "Throwing Specialization", "+1% critical strike chance with thrown weapons" },
			{ "Hex of Weakness", "Weakens the target's damage", "PRIEST" },
		} },
	{ key = "bloodelf", name = "Blood Elf", faction = "Horde", since = 2, zone = "Eversong Woods",
		classes = { "PALADIN", "HUNTER", "ROGUE", "PRIEST", "MAGE", "WARLOCK" },
		racials = {
			{ "Arcane Torrent", "Silences enemies within 8 yards for 2 sec; restores mana (Rogue: energy) per Mana Tap charge" },
			{ "Mana Tap", "Drains 119 mana from the target and stacks up to 3 times" },
			{ "Magic Resistance", "All resistances +5" },
			{ "Arcane Affinity", "Enchanting skill +10" },
		} },
	-- later expansions: summary only
	{ key = "worgen", name = "Worgen", faction = "Alliance", since = 4, traits = "Darkflight, Two Forms" },
	{ key = "goblin", name = "Goblin", faction = "Horde", since = 4, traits = "Rocket Jump, Best Deals Anywhere" },
	{ key = "pandaren", name = "Pandaren", faction = "Both", since = 5, traits = "Quaking Palm, Epicurean" },
	{ key = "nightborne", name = "Nightborne", faction = "Horde", since = 7, traits = "Ancient History, Arcane Pulse" },
	{ key = "highmountaintauren", name = "Highmountain Tauren", faction = "Horde", since = 7, traits = "Bull Rush, Mountaineer" },
	{ key = "voidelf", name = "Void Elf", faction = "Alliance", since = 7, traits = "Spatial Rift, Preternatural Calm" },
	{ key = "lightforgeddraenei", name = "Lightforged Draenei", faction = "Alliance", since = 7, traits = "Light's Judgment, Forge of Light" },
	{ key = "darkirondwarf", name = "Dark Iron Dwarf", faction = "Alliance", since = 8, traits = "Fireblood, Mole Machine" },
	{ key = "kul-tiran", name = "Kul Tiran", faction = "Alliance", since = 8, traits = "Haymaker, Brush It Off" },
	{ key = "magharorc", name = "Mag'har Orc", faction = "Horde", since = 8, traits = "Ancestral Call, Open Skies" },
	{ key = "zandalari-troll", name = "Zandalari Troll", faction = "Horde", since = 8, traits = "Embrace of the Loa, Pterrordax Swoop" },
	{ key = "mechagnome", name = "Mechagnome", faction = "Alliance", since = 8, traits = "Combat Analysis, Hyper Organic Light Originator" },
	{ key = "vulpera", name = "Vulpera", faction = "Horde", since = 8, traits = "Make Camp, Nose For Trouble" },
	{ key = "dracthyr", name = "Dracthyr", faction = "Both", since = 10, traits = "Soar, Visage, racials vary by faction" },
	{ key = "earthen", name = "Earthen", faction = "Both", since = 11, traits = "Azerite Surge, Ingest Minerals" },
	{ key = "haranir", name = "Haranir", faction = "Both", since = 12, traits = "Race abilities vary by game version" },
}

-- stat caps against raid bosses (level 73), TBC
TD.caps = {
	{ "Melee and ranged special attacks", "9% hit (142 rating)", "Improved Faerie Fire (3%) and Heroic Presence (1%) lower the gear requirement" },
	{ "Dual-wield white attacks", "28% hit (442 rating)", "Specials stay on the 9% table; the 19% dual-wield penalty applies to white hits" },
	{ "Spell hit", "16% (202 rating)", "Totem of Wrath covers 3% (38 rating); Inspiring Presence 1%; 1% resist can never be removed" },
	{ "Expertise: dodge", "26 expertise (about 103 rating)", "Removes the 6.5% dodge from behind; attacks from behind cannot be parried" },
	{ "Expertise: parry", "56 expertise (about 221 rating)", "Removes the front parry (base 14%, 7.5% once dodge is capped)" },
	{ "Tank: crit immunity", "490 defense (about 332 rating from gear)", "Needs 5.6% crit reduction; resilience (221 rating) can replace defense, avoidance can too" },
	{ "Tank: crushing blows", "102.4% total avoidance", "Miss + dodge + parry + block; Holy Shield adds 30% block, Shield Block 75%" },
}

-- rating per 1% (or per point) at level 70
TD.ratings = {
	{ "Melee hit", "15.77" }, { "Spell hit", "12.62" }, { "Critical strike", "22.08" }, { "Haste", "15.77" },
	{ "Expertise (per point)", "3.94" }, { "Armor penetration", "5.92" }, { "Defense (per point)", "2.37" },
	{ "Dodge", "18.92" }, { "Parry", "23.65" }, { "Block", "7.88" }, { "Resilience", "39.4" },
}

TD.sources = {
	"Racial abilities: the game's own tooltips (wowcalc.net, TBC)",
	"Reagents: Warcraft Wiki reagent table and Blizzard Watch",
	"Weapon skills: wow-guides.com (read from the game's skill data)",
	"Stat caps: classicwow.gg cap calculator and Wowhead stat guides",
	"Stat priorities: Wowhead stat guides (Burning Crusade versions only)",
	"Best races and professions: Wowhead class and spec overview guides",
	"Enchants and gems: taken from the BiS lists of the BisGuide data",
	"Specialization stats: wowcalc.net class guides",
	"Raid buffs and debuffs: Warcraft Tavern raid buff table and classicwow.gg raid planner",
	"Feral Tank stats: Wowhead, Icy Veins and Warcraft Tavern stat guides",
}

-- stat priorities per spec: Wowhead's Burning Crusade stat guides (only pages
-- titled "... in Burning Crusade"; later-expansion guides were rejected)
local HUNTER = { "Hit rating", "Armor penetration", "Haste rating", "Agility", "Critical strike rating", "Attack power" }
local MAGE = { "Spell hit rating", "Spell haste", "Spell power", "Critical strike rating", "Intellect" }
local ROGUE = { "Expertise rating", "Hit rating", "Haste rating", "Agility", "Critical strike rating", "Strength and attack power", "Armor penetration" }
local LOCK = { "Spell hit rating", "Spell haste", "Spell power", "Critical strike rating", "Intellect", "Stamina" }
local WARR = { "Hit rating", "Expertise rating", "Critical strike rating", "Strength", "Armor penetration", "Haste rating" }
local PRIEST_HEAL = { "Haste rating", "Healing power", "Intellect and Spirit", "Critical strike rating", "MP5", "Spell power" }
TD.priorities = {
	["DRUID:Balance"] = { "Spell hit rating", "Spell power", "Spell haste", "Spell crit", "Intellect", "Spirit", "MP5" },
	["DRUID:Feral DPS"] = { "Agility", "Hit and expertise rating", "Strength", "Critical strike rating", "Haste rating", "Attack power", "Armor penetration" },
	["DRUID:Feral Tank"] = { "Expertise rating", "Agility", "Hit rating", "Stamina", "Strength", "Defense rating", "Critical strike rating" },
	["DRUID:Restoration"] = { "Healing power", "Haste rating", "Spirit", "MP5", "Intellect", "Critical strike rating" },
	["HUNTER:Beast Mastery"] = HUNTER, ["HUNTER:Marksmanship"] = HUNTER, ["HUNTER:Survival"] = HUNTER,
	["MAGE:Arcane"] = MAGE, ["MAGE:Fire"] = MAGE, ["MAGE:Frost"] = MAGE,
	["PALADIN:Holy"] = { "Healing power", "Intellect", "Critical strike rating", "MP5", "Stamina" },
	["PALADIN:Protection"] = { "Crit immunity (490 defense)", "Avoidance (crush cap 102.4%)", "Effective health", "Threat (spell power and hit)" },
	["PALADIN:Retribution"] = { "Expertise rating", "Hit rating", "Strength", "Attack power", "Critical strike rating", "Agility" },
	["PRIEST:Discipline"] = PRIEST_HEAL, ["PRIEST:Holy"] = PRIEST_HEAL,
	["PRIEST:Shadow"] = { "Spell power", "Spell hit rating", "Critical strike rating", "Intellect, Spirit and MP5" },
	["ROGUE:Assassination"] = ROGUE, ["ROGUE:Combat"] = ROGUE, ["ROGUE:Subtlety"] = ROGUE,
	["SHAMAN:Elemental"] = { "Spell hit rating", "Spell haste", "Spell power", "Critical strike rating", "Intellect", "MP5", "Stamina" },
	["SHAMAN:Enhancement"] = { "Expertise rating", "Strength", "Hit rating", "Haste rating", "Critical strike rating", "Agility", "Attack power", "Armor penetration" },
	["SHAMAN:Restoration"] = { "Healing power", "MP5", "Intellect", "Spell haste", "Critical strike rating", "Stamina", "Spirit" },
	["WARLOCK:Affliction"] = LOCK, ["WARLOCK:Demonology"] = LOCK, ["WARLOCK:Destruction"] = LOCK,
	["WARRIOR:Arms"] = WARR, ["WARRIOR:Fury"] = WARR,
	["WARRIOR:Protection"] = { "Crit immunity (490 defense)", "Expertise (6.5% cap)", "Hit rating (9% cap)" },
}
for file, c in pairs(TD.classes) do
	for _, sp in ipairs(c.specs or {}) do
		local list = TD.priorities[file .. ":" .. sp.name]
		if list then sp.stats = list end
	end
end

-- best races / professions: statements from Wowhead's Burning Crusade class
-- overviews and spec overviews (class-wide unless a spec is named)
TD.recommend = {
	DRUID = {
		races = {
			"Alliance Druids are Night Elves, Horde Druids are Tauren",
			"Tauren: Endurance (+5% health) is a real advantage for tanks",
		},
		professions = {
			"Leatherworking: epic gear only Leatherworkers can wear (Primalstrike Vest with Elemental Leatherworking), pairs well with Skinning",
			"Engineering: bombs, special trinkets and goggles (Feral: Super Sapper Charge, Deathblow X11 Goggles from phase 2)",
			"Enchanting: own ring enchants (Feral: Striking and Stats)",
		},
	},
	HUNTER = {
		races = {
			"Draenei is the best Alliance PvE race (Heroic Presence); Night Elf and Dwarf are the other options, Dwarf pays off with a gun",
			"Orc is very strong on the Horde (Blood Fury, Command for Beast Mastery); Blood Elf, Tauren and Troll are the other options",
		},
		professions = {
			"Leatherworking: Greater Drums of Battle and strong sets (Primal Intent), the best early pick",
			"Engineering: Adamantite Grenade, Dimensional Ripper - Area 52 and goggles; then Blacksmithing and Enchanting",
		},
	},
	MAGE = {
		races = {
			"Gnome is the best Alliance race (Expansive Mind: +5% Intellect); Draenei is solid (Inspiring Presence: +1% hit for the party)",
			"Troll is the best Horde PvE race; Undead and Blood Elf are the other options",
		},
		professions = {
			"Tailoring is a must-have: Wrath of Spellfire and Spellstrike Infusion sets (Spellweave specialization)",
			"Engineering is close to a must-have for raid damage (Sapper Charges, Adamantite Grenade, Holo-Gogs from phase 2)",
			"Enchanting is the best second profession for min-maxing",
		},
	},
	PALADIN = {
		races = {
			"Human is the best Alliance choice (Sword and Mace Specialization; Diplomacy for Holy)",
			"Dwarf (Stoneform) and Draenei (Heroic Presence) have strong racials too",
			"Horde Paladins must be Blood Elves",
		},
		professions = {
			"Blacksmithing with Mining: leveling and best-in-slot gear, Weaponsmith weapons",
			"Leatherworking (drums), Jewelcrafting (gems, best necks and rings in later phases), Enchanting (Spell Power and Healing Power ring enchants)",
			"Holy: Enchanting is a great pick, the second profession is flexible; Protection: Engineering and Enchanting; Retribution: Blacksmithing and Engineering",
		},
	},
	PRIEST = {
		races = {
			"Alliance Priests are Draenei, Dwarf, Human or Night Elf; Horde Priests are Blood Elf, Troll or Undead",
			"Every race adds its own priest abilities; there is no single best race, none of them stops you from performing well",
		},
		professions = {
			"Tailoring: Primal Mooncloth (Holy and Discipline) or Frozen Shadoweave (Shadow) sets, pairs well with Enchanting",
			"Enchanting: Spellpower and Healing Power ring enchants",
		},
	},
	ROGUE = {
		races = {
			"Human is the best Alliance PvE race (Sword and Mace Specialization); Gnome is strong in PvP (Escape Artist)",
			"Orc is great for PvE and PvP (Blood Fury, Hardiness); Troll can edge it out in PvE (Berserking, Beast Slaying)",
			"Draenei and Tauren cannot be Rogues",
		},
		professions = {
			"Leatherworking (Drums, Primalstrike Vest), Engineering (bombs, goggles) and Enchanting (ring enchants)",
			"Blacksmithing for the phase 1 weapon; Engineering and Leatherworking share a cooldown group",
		},
	},
	SHAMAN = {
		races = {
			"Alliance Shamans must be Draenei (Heroic and Inspiring Presence for the group)",
			"Horde Shamans are Orc, Troll or Tauren; Orc is the min-max choice (Axe Specialization, Hardiness, Blood Fury)",
		},
		professions = {
			"Leatherworking: Greater Drums of Battle all expansion long",
			"Enchanting is strong for all three specializations (exclusive ring enchants)",
			"Enhancement: Leatherworking is non-negotiable, Blacksmithing is not recommended",
		},
	},
	WARLOCK = {
		races = {
			"Gnome has a slight edge on the Alliance (Expansive Mind); Human is the other option",
			"Orc is the best PvE race (Blood Fury, Command for Demonology); Undead and Blood Elf are the other options",
		},
		professions = {
			"Tailoring: the Shadow's Embrace set (Affliction and Shadow Destruction) is available from the start, then Spellstrike",
			"Engineering: Adamantite Grenade, Dimensional Ripper - Area 52 and goggles; Enchanting: Spellpower ring enchants",
		},
	},
	WARRIOR = {
		races = {
			"Human is the most popular Alliance choice (Sword and Mace Specialization); Orc or Troll on the Horde (Axe Specialization and Blood Fury; Berserking and Beast Slaying)",
			"Blood Elves cannot be Warriors",
			"Protection: Draenei adds group hit (Inspiring and Heroic Presence)",
		},
		professions = {
			"Blacksmithing with Mining: Lionheart Executioner (Master Swordsmithing) and Dragonmaw for Fury",
			"Engineering: Super Sapper Charge, Dimensional Ripper - Area 52 and goggles; Protection: Blacksmithing, Enchanting and Engineering",
		},
	},
}

-- talent prerequisites (talent index -> {required talent index, rank}),
-- from Wowhead's TBC talent-calc data; every entry verified against the
-- BisGuide tree positions (row/col and max rank, zero mismatches).
TD.prereqs = {
	DRUID = {
		[1] = {[3]={2,1},[10]={5,2},[15]={13,1}},
		[2] = {[11]={8,3},[15]={10,3},[19]={18,1},[21]={18,1}},
		[3] = {[11]={6,3},[15]={10,3},[17]={12,5},[20]={19,5}},
	},
	HUNTER = {
		[1] = {[16]={11,5},[18]={13,1},[21]={18,1}},
		[2] = {[10]={7,1},[17]={12,1},[18]={13,3},[20]={19,5}},
		[3] = {[16]={10,1},[20]={15,3},[21]={18,5},[23]={22,5}},
	},
	MAGE = {
		[1] = {[17]={14,1},[18]={6,5},[20]={17,3}},
		[2] = {[15]={8,1},[19]={14,3},[22]={19,1}},
		[3] = {[13]={6,2},[19]={15,1}},
	},
	PALADIN = {
		[1] = {[12]={9,5},[17]={12,1}},
		[2] = {[8]={2,5},[18]={19,1},[19]={14,1},[22]={19,1}},
		[3] = {[15]={14,1},[16]={7,5},[21]={19,1}},
	},
	PRIEST = {
		[1] = {[14]={9,3},[15]={14,1},[19]={13,5}},
		[2] = {[11]={5,5},[18]={13,1}},
		[3] = {[12]={6,2},[14]={13,1},[18]={13,1},[21]={18,1}},
	},
	ROGUE = {
		[1] = {[9]={3,5},[16]={13,1},[21]={18,1}},
		[2] = {[8]={5,5},[12]={6,5},[18]={14,1},[24]={21,1}},
		[3] = {[15]={11,3},[19]={13,1},[21]={19,1}},
	},
	SHAMAN = {
		[1] = {[16]={8,5},[17]={13,1},[20]={19,5}},
		[2] = {[10]={4,5},[17]={18,1},[18]={13,1},[19]={14,3}},
		[3] = {[16]={10,5},[20]={18,3}},
	},
	WARLOCK = {
		[1] = {[15]={9,1},[16]={14,1},[21]={17,5}},
		[2] = {[11]={8,1},[17]={12,5},[19]={14,1}},
		[3] = {[12]={9,2},[14]={7,5},[18]={13,5},[21]={20,5}},
	},
	WARRIOR = {
		[1] = {[11]={9,3},[20]={13,1},[22]={20,1}},
		[2] = {[16]={11,5},[18]={13,1},[21]={18,1}},
		[3] = {[7]={4,5},[19]={14,1}},
	},
}
