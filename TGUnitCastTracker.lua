local TGUF_PLAYER_CAST      = {}
local TGUF_PLAYER_OT_SPELLS = {}
local TGUF_FREE_CASTS       = {}
local MAX_SPELLS            = 10

local TGUF_OT_SPELL_DB = {
    --[[
    ["Renew"] = {length = 15, texture = "Interface\\Icons\\Spell_Holy_Renew", tick = 3},
    ["Rejuvenation"] = {length = 12, texture = "Interface\\Icons\\Spell_Nature_Rejuvenation", tick = 3},
    ["Regrowth"] = {length = 21, texture = "Interface\\Icons\\Spell_Nature_ResistNature", tick = 3},
    ["Shadow Word: Pain"] = {length = 18, texture = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", tick = 3},
    ["Vampiric Touch"] = {length = 15, texture = "Interface\\Icons\\Spell_Holy_Stoicism", tick = 3},
    ["Power Infusion"] = {length = 15, texture = "Interface\\Icons\\Spell_Holy_PowerInfusion"},
    ["Abolish Disease"] = {length = 20, texture = "Interface\\Icons\\Spell_Nature_NullifyDisease", tick = 5},
    ]]--

    -- Immolate
    {
        name    = "Immolate",
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

    -- Corruption
    {
        name    = "Corruption",
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

    -- Curse of Agony
    {
        name    = "Curse of Agony",
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

    -- Siphon Life
    {
        name    = "Siphon Life",
        texture = "Interface\\Icons\\Spell_Shadow_Requiem",
        tick    = 3,
        ranks   = {
            [18265] = {length = 30},
            [18879] = {length = 30},
            [18880] = {length = 30},
            [18881] = {length = 30},
        },
    },
    --[[
    ["Lacerate"] = {length = 15, texture = "Interface\\Icons\\Ability_Druid_Lacerate", tick = 3},
    ]]--
}

local TGUF_CAST_INFO = {}
for _, s in ipairs(TGUF_OT_SPELL_DB) do
    for spellID, r in pairs(s.ranks) do
        TGUF_CAST_INFO[spellID] = {
            name    = s.name,
            texture = s.texture,
            tick    = s.tick,
            length  = r.length,
        }
    end
end

local function TGCTDbg(msg)
    --TGDbg(msg)
end

EventHandler = {}

local FREE_CASTS = {}
local CAST_CACHE = {}

function GetOrAllocateCast(timestamp, castGUID, spellID)
    -- See if we already know about this spell.
    local cast = CAST_CACHE[castGUID]
    if cast ~= nil then
        return cast
    end

    -- Find or allocate a free cast object.
    if #TGUF_FREE_CASTS > 0 then
        cast = table.remove(FREE_CASTS)
        assert(cast.allocated == false)
    else
        cast = {}
    end

    -- Populate it.
    cast.allocated  = true
    cast.targetName = UnitName("target")
    cast.targetGUID = UnitGUID("target")
    cast.castInfo   = TGUF_CAST_INFO[spellID]
    cast.castGUID   = castGUID
    cast.spellID    = spellID
    cast.timestamp  = timestamp
    cast.spellName  = GetSpellInfo(spellID)

    -- Record it and return.
    CAST_CACHE[castGUID] = cast
    return cast
end

function FreeCast(cast)
    assert(cast.allocated == true)
    assert(CAST_CACHE[cast.castGUID] == cast)

    cast.allocated            = false
    CAST_CACHE[cast.castGUID] = nil
    table.insert(FREE_CASTS, cast)
end

function FreeCastByGUID(castGUID)
    local cast = CAST_CACHE[castGUID]
    if cast then
        FreeCast(cast)
    end
end

function DumpCastCache()
    local t = GetTime()
    for k, v in pairs(CAST_CACHE) do
        local dt = t - v.timestamp
        print("["..tostring(dt).."s ago] "..k..": "..tostring(v.spellName))
    end
end

function EventHandler.ADDON_LOADED()
end

function EventHandler.UNIT_SPELLCAST_SENT(unit, targetName, castGUID, spellID)
    local timestamp  = GetTime()
    --[[
    TGDbg("["..timestamp.."] TGUnitCastTracker: UNIT_SPELLCAST_SENT"
            .." unit "..tostring(unit)
            .." targetName "..tostring(targetName)
            .." castGUID "..tostring(castGUID)
            .." spellID "..tostring(spellID)
            )
    ]]

    GetOrAllocateCast(timestamp, castGUID, spellID)
end

function EventHandler.UNIT_SPELLCAST_START(unit, castGUID, spellID)
    local timestamp  = GetTime()
    --[[
    TGDbg("["..timestamp.."] TGUnitCastTracker: UNIT_SPELLCAST_START"
            .." unit "..tostring(unit)
            .." castGUID "..tostring(castGUID)
            .." spellID "..tostring(spellID)
            )
    ]]

    GetOrAllocateCast(timestamp, castGUID, spellID)
end

function EventHandler.UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID)
    local timestamp = GetTime()
    --[[
    TGDbg("["..timestamp.."] TGUnitCastTracker: UNIT_SPELLCAST_SUCCEEDED"
            .." unit"..tostring(unit)
            .." castGUID "..tostring(castGUID)
            .." spellID "..tostring(spellID)
            )
    print(" ")
    ]]

    -- Find or allocate the cast and see if we care about it.
    local cast = GetOrAllocateCast(timestamp, castGUID, spellID)
    if not cast.castInfo then
        --print("Not a tracked spell!")
        FreeCast(cast)
        return
    end

    -- Check if we are refreshing a spell.
    local refreshed = false
    for k, v in ipairs(TGUF_PLAYER_OT_SPELLS) do
        if (v.spellID    == cast.spellID and
            v.targetGUID == cast.targetGUID) then
            --print("Refresh "..v.castInfo.name.." with "..cast.castInfo.name.." detected!")
            FreeCast(v)
            TGUF_PLAYER_OT_SPELLS[k] = cast
            refreshed = true
            break
        end
    end

    -- If we aren't refreshing, insert the new one.
    if not refreshed then
        --print("New cast detected!")
        table.insert(TGUF_PLAYER_OT_SPELLS, cast)
    end

    TGUnitCastTracker:Show()
    EventHandler.OnUpdate()
end

function EventHandler.UNIT_SPELLCAST_FAILED(unit, castGUID, spellID)
    --[[
    TGDbg("TGUnitCastTracker: UNIT_SPELLCAST_FAILED"
          .." unit: "..tostring(unit)
          .." castGUID: "..tostring(castGUID)
          .." spellID: "..tostring(spellID)
          )
    ]]
    FreeCastByGUID(castGUID)
end

function EventHandler.UNIT_SPELLCAST_FAILED_QUIET(unit, castGUID, spellID)
    --[[
    TGDbg("TGUnitCastTracker: UNIT_SPELLCAST_FAILED_QUIET"
          .." unit: "..tostring(unit)
          .." castGUID: "..tostring(castGUID)
          .." spellID: "..tostring(spellID)
          )
    ]]
    FreeCastByGUID(castGUID)
end

function EventHandler.UNIT_SPELLCAST_INTERRUPTED(unit, castGUID, spellID)
    --[[
    TGDbg("TGUnitCastTracker: UNIT_SPELLCAST_INTERRUPTED"
          .." unit: "..tostring(unit)
          .." castGUID: "..tostring(castGUID)
          .." spellID: "..tostring(spellID)
          )
    ]]
    FreeCastByGUID(castGUID)
end

function EventHandler.CLEU_UNIT_DIED(timestamp, _, _, _, _, _, targetGUID, targetName)
    --[[
    TGCTDbg("["..timestamp.."] TGUnitCastTracker: CLEU_UNIT_DIED "
            .." targetGUID: "..tostring(targetGUID)
            .." targetName: "..tostring(targetName)
            )
    ]]

    local removedOne
    repeat
        removedOne = false
        for k, v in ipairs(TGUF_PLAYER_OT_SPELLS) do
            if v.targetGUID == targetGUID then
                --print("Unit Died, freeing spell")
                FreeCast(table.remove(TGUF_PLAYER_OT_SPELLS, k))
                removedOne = true
                break
            end
        end
    until(removedOne == false)
end

function EventHandler.OnUpdate()
    -- Start by removing any old spells from the casting list
    local removedOne
    local currTime = GetTime()
    repeat
        removedOne = false
        for k, v in ipairs(TGUF_PLAYER_OT_SPELLS) do
            if (v.timestamp + v.castInfo.length <= currTime) then
                --print("Spell expired, freeing spell!")
                FreeCast(table.remove(TGUF_PLAYER_OT_SPELLS, k))
                removedOne = true
                break
            end
        end
    until(removedOne == false)
    
    -- If we have no more spells, we are done
    local numSpells = #TGUF_PLAYER_OT_SPELLS
    if (numSpells == 0) then
        TGUnitCastTracker:Hide()
        return
    end
    if (numSpells > MAX_SPELLS) then
        numSpells = MAX_SPELLS
    end
    
    -- Okay, we need to display spells.
    for k=1, numSpells do
        local v = TGUF_PLAYER_OT_SPELLS[k]
        
        -- Get the cast bar
        local castInfo = TGUF_CAST_INFO[v.spellID]
        local percent = (currTime - v.timestamp)/v.castInfo.length
        if (percent > 1) then
            percent = 1
        end
        local castTrackerBar = _G["TGUnitCastTrackerBar"..k]
        if castTrackerBar ~= nil then
            local castTrackerIcon         = _G["TGUnitCastTrackerBar"..k.."IconTexture"]
            local castTrackerBarFrame     = _G["TGUnitCastTrackerBar"..k.."Bar"]
            local castTrackerBarFrameText = _G["TGUnitCastTrackerBar"..k.."SizeFrameText"]
            local castTrackerBarTexture   = _G["TGUnitCastTrackerBar"..k.."BarTexture"]
            local castTrackerBarSpark     = _G["TGUnitCastTrackerBar"..k.."BarSpark"]
            castTrackerBar:Show()
            castTrackerIcon:SetTexture(castInfo.texture)
            castTrackerIcon:Show()
            castTrackerBarTexture:SetVertexColor(0.25,1,0.25,1)
            castTrackerBarFrameText:Show()
            castTrackerBarFrameText:SetText(v.targetName)
            
            local sizeFrame = _G["TGUnitCastTrackerBar"..k.."SizeFrame"]
            local realWidth = sizeFrame:GetWidth()
            --TGUFMsg(""..(1-percent)*realWidth)
            local   percentWidth = math.floor((1-percent)*realWidth + 0.5)
            if (percentWidth <= 0) then
                percentWidth = 1
            end
            --print(percentWidth)
            castTrackerBarFrame:SetWidth(percentWidth);
            
            local elapsed = currTime - v.timestamp;
            if (elapsed > 0.125 and castInfo.tick ~= nil) then
                local modulo = (elapsed % castInfo.tick)
                if (modulo > castInfo.tick/2) then
                    modulo = modulo - castInfo.tick
                end
                modulo = modulo + 0.125
                if (0 <= modulo and modulo < 0.5) then
                    castTrackerBarSpark:SetAlpha(1-2*modulo)
                else
                    castTrackerBarSpark:SetAlpha(0)
                end
            else
                castTrackerBarSpark:SetAlpha(0)
            end
        end
    end
    
    -- Hide others
    for k=numSpells+1, MAX_SPELLS do
        local castTrackerBar = _G["TGUnitCastTrackerBar"..k]
        if (castTrackerBar ~= nil) then
            castTrackerBar:Hide()
        end
    end
    
    -- Finally set the height
    TGUnitCastTracker:SetHeight(11 + numSpells*15)
end

TGEventManager.Register(EventHandler)
