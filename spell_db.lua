TGSpellDB = {}

-- The list of heal or damage over time spells that we are interested in
-- tracking.
TGSpellDB.OVER_TIME_SPELL_LIST = {
    -- Priest spells.
    --[[
    ["Renew"] = {
        texture = "Interface\\Icons\\Spell_Holy_Renew",
        tick    = 3,
        ranks   = {},   -- length = 15
    },
    ]]
    ["Shadow Word: Pain"] = {
        texture = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
        tick    = 3,
        ranks   = {},   -- length = 18
    },
    ["Vampiric Touch"] = {
        texture = "Interface\\Icons\\Spell_Holy_Stoicism",
        tick    = 3,
        ranks   = {},   -- length = 15
    },
    --[[
    ["Power Infusion"] = {
        texture = "Interface\\Icons\\Spell_Holy_PowerInfusion",
        tick    = nil,
        ranks   = {},   -- length = 15
    },
    ["Abolish Disease"] = {
        texture = "Interface\\Icons\\Spell_Nature_NullifyDisease",
        tick    = 5,
        ranks   = {},   -- length = 20
    },
    ]]

    -- Druid spells.
    ["Rejuvenation"] = {
        texture = "Interface\\Icons\\Spell_Nature_Rejuvenation",
        tick    = 3,
        ranks   = {},   -- length = 12
    },
    ["Regrowth"] = {
        texture = "Interface\\Icons\\Spell_Nature_ResistNature",
        tick = 3,
        ranks   = {},   -- length = 21
    },
    ["Lacerate"] = {
        texture = "Interface\\Icons\\Ability_Druid_Lacerate",
        tick    = 3,
        ranks   = {},   -- length = 15
    },

    -- Warrior spells.
    ['Rend'] = {
        texture = 132155,
        tick    = 3,
        ranks   = {
            [772]   = {length = 9},
            [6546]  = {length = 12},
            [6547]  = {length = 15},
            [6548]  = {length = 18},
            [11572] = {length = 21},
            [11573] = {length = 21},
            [11574] = {length = 21},
        }
    },

    -- Warlock spells.
    ["Immolate"] = {
        texture = "Interface\\Icons\\Spell_Fire_Immolation",
        tick    = 3,
        ranks   = {
            [348]   = {length = 15},
            [707]   = {length = 15},
            [1094]  = {length = 15},
            [2941]  = {length = 15},
            [11665] = {length = 15},
            [11667] = {length = 15},
            [11668] = {length = 15},
            [25309] = {length = 15},
        },
    },
    ["Corruption"] = {
        texture = "Interface\\Icons\\Spell_Shadow_AbominationExplosion",
        tick    = 3,
        ranks   = {
            [172]   = {length = 12},
            [6222]  = {length = 15},
            [6223]  = {length = 18},
            [7648]  = {length = 18},
            [11671] = {length = 18},
            [11672] = {length = 18},
            [25311] = {length = 18},
        },
    },
    ["Curse of Agony"] = {
        texture = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras",
        tick    = 2,
        ranks   = {
            [980]   = {length = 24},
            [1014]  = {length = 24},
            [6217]  = {length = 24},
            [11711] = {length = 24},
            [11712] = {length = 24},
            [11713] = {length = 24},
        },
    },
    ["Siphon Life"] = {
        texture = "Interface\\Icons\\Spell_Shadow_Requiem",
        tick    = 3,
        ranks   = {
            [18265] = {length = 30},
            [18879] = {length = 30},
            [18880] = {length = 30},
            [18881] = {length = 30},
        },
    },
    ['Banish'] = {
        texture = "Interface\\Icons\\Spell_Shadow_Cripple",
        tick    = nil,
        ranks   = {
            [710]   = {length = 30},
            [18647] = {length = 30},
        },
    },
}

TGSpellDB.OT_CAST_INFO = {}
for spellName, s in pairs(TGSpellDB.OVER_TIME_SPELL_LIST) do
    for spellID, r in pairs(s.ranks) do
        TGSpellDB.OT_CAST_INFO[spellID] = {
            name    = spellName,
            texture = s.texture,
            tick    = s.tick,
            length  = r.length,
        }
    end
end
