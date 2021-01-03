TGUF_PLAYER_CAST      = {}
TGUF_PLAYER_OT_SPELLS = {}
TGUF_FREE_CASTS       = {}
local TGUF_CAST_INFO = {
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
    [348]   = {name = "Immolate", length = 15, texture = "Interface\\Icons\\Spell_Fire_Immolation", tick = 3},
    [707]   = {name = "Immolate", length = 15, texture = "Interface\\Icons\\Spell_Fire_Immolation", tick = 3},
    [1094]  = {name = "Immolate", length = 15, texture = "Interface\\Icons\\Spell_Fire_Immolation", tick = 3},
    [2941]  = {name = "Immolate", length = 15, texture = "Interface\\Icons\\Spell_Fire_Immolation", tick = 3},
    [11665] = {name = "Immolate", length = 15, texture = "Interface\\Icons\\Spell_Fire_Immolation", tick = 3},
    [11667] = {name = "Immolate", length = 15, texture = "Interface\\Icons\\Spell_Fire_Immolation", tick = 3},
    [11668] = {name = "Immolate", length = 15, texture = "Interface\\Icons\\Spell_Fire_Immolation", tick = 3},
    [25309] = {name = "Immolate", length = 15, texture = "Interface\\Icons\\Spell_Fire_Immolation", tick = 3},

    -- Corruption
    [172]   = {name = "Corruption", length = 12, texture = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", tick = 3},
    [6222]  = {name = "Corruption", length = 15, texture = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", tick = 3},
    [6223]  = {name = "Corruption", length = 18, texture = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", tick = 3},
    [7648]  = {name = "Corruption", length = 18, texture = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", tick = 3},
    [11671] = {name = "Corruption", length = 18, texture = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", tick = 3},
    [11672] = {name = "Corruption", length = 18, texture = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", tick = 3},
    [25311] = {name = "Corruption", length = 18, texture = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", tick = 3},

    -- Curse of Agony
    [980]   = {name = "Curse of Agony", length = 24, texture = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras", tick = 2},
    [1014]  = {name = "Curse of Agony", length = 24, texture = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras", tick = 2},
    [6217]  = {name = "Curse of Agony", length = 24, texture = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras", tick = 2},
    [11711] = {name = "Curse of Agony", length = 24, texture = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras", tick = 2},
    [11712] = {name = "Curse of Agony", length = 24, texture = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras", tick = 2},
    [11713] = {name = "Curse of Agony", length = 24, texture = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras", tick = 2},

    -- Siphon Life
    [18265] = {name = "Siphon Life", length = 30, texture = "Interface\\Icons\\Spell_Shadow_Requiem", tick = 3},
    [18879] = {name = "Siphon Life", length = 30, texture = "Interface\\Icons\\Spell_Shadow_Requiem", tick = 3},
    [18880] = {name = "Siphon Life", length = 30, texture = "Interface\\Icons\\Spell_Shadow_Requiem", tick = 3},
    [18881] = {name = "Siphon Life", length = 30, texture = "Interface\\Icons\\Spell_Shadow_Requiem", tick = 3},

    --[[
    ["Lacerate"] = {length = 15, texture = "Interface\\Icons\\Ability_Druid_Lacerate", tick = 3},
    ]]--
};
local TGUF_PLAYER_CLASS = nil
local MAX_SPELLS = 10
local LAST_SPELL_SENT = nil

local function TGCTDbg(msg)
    --TGDbg(msg)
end

EventHandler = {}

function AllocateCast(timestamp, targetName, castGUID, spellID)
    local cast
    if #TGUF_FREE_CASTS > 0 then
        cast = table.remove(TGUF_FREE_CASTS)
        assert(cast.allocated == false)
    else
        cast = {}
    end

    cast.allocated  = true
    cast.targetName = targetName
    cast.targetGUID = UnitGUID("target")
    cast.castInfo   = TGUF_CAST_INFO[spellID]
    cast.castGUID   = castGUID
    cast.spellID    = spellID
    cast.timestamp  = timestamp
    cast.spellName  = GetSpellInfo(spellID)

    return cast
end

function FreeCast(cast)
    assert(cast.allocated == true)

    cast.allocated = false
    table.insert(TGUF_FREE_CASTS, cast)
end

function EventHandler.ADDON_LOADED()
end

function EventHandler.PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
    TGCTDbg("TGUnitCastTracker: PLAYER_ENTERING_WORLD isInitialLogin "..tostring(isInitialLogin)..
            " isReloadingUi "..tostring(isReloadingUi))

    _, TGUF_PLAYER_CLASS = UnitClass("player");
    --[[
    if (TGUF_PLAYER_CLASS == "PRIEST") then
        for tab=1,GetNumTalentTabs() do
            for talent=1,GetNumTalents(tab) do
                local   name,icon,_,_,rank = GetTalentInfo(tab,talent);
                if (name == "Improved Shadow Word: Pain") then
                    --TGUFMsg("Player has rank "..rank.." of Improved Shadow Word: Pain ("..icon..")");
                    TGUF_CAST_INFO["Shadow Word: Pain"].length = TGUF_CAST_INFO["Shadow Word: Pain"].length + 3*rank;
                end
            end
        end
    end
    ]]
end

function EventHandler.UNIT_SPELLCAST_SENT(unit, targetName, castGUID, spellID)
    local timestamp  = GetTime()
    --TGDbg("Spell sent: "..tostring(name))
    TGDbg("["..timestamp.."] TGUnitCastTracker: UNIT_SPELLCAST_SENT"
            .." unit "..tostring(unit)
            .." targetName "..tostring(targetName)
            .." castGUID "..tostring(castGUID)
            .." spellID "..tostring(spellID)
            )

    cast = AllocateCast(timestamp, targetName, castGUID, spellID)

    LAST_SPELL_SENT = cast.spellName
    TGUF_PLAYER_CAST[castGUID] = cast
end

function EventHandler.UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID)
    local timestamp = GetTime()
    TGDbg("["..timestamp.."] TGUnitCastTracker: UNIT_SPELLCAST_SUCCEEDED"
            .." unit"..tostring(unit)
            .." castGUID "..tostring(castGUID)
            .." spellID "..tostring(spellID)
            )
    print(" ")
    local name = GetSpellInfo(spellID)

    -- Pop the cast out of our pending casts.  It's possible for this to be
    -- nil, for instance shooting a wand gives us a single SENT event followed
    -- by streaming SUCCEEDED events.
    local playerCast = TGUF_PLAYER_CAST[castGUID]
    if playerCast == nil then
        TGDbg("Unsent spell succeeded: "..tostring(name).." (last sent was "..tostring(LAST_SPELL_SENT)..")")
        return
    end
    --TGDbg("Sent spell succeeded: "..tostring(name))
    TGUF_PLAYER_CAST[castGUID] = nil

    if playerCast.castInfo then
        -- Record the spell start time.
        playerCast.startTime = timestamp

        -- Check if we are refreshing a spell.
        local refreshed = false
        for k, v in pairs(TGUF_PLAYER_OT_SPELLS) do
            if (v.spellID    == playerCast.spellID and
                v.targetGUID == playerCast.targetGUID) then
                --print("Refresh "..v.castInfo.name.." with "..playerCast.castInfo.name.." detected!")
                FreeCast(v)
                TGUF_PLAYER_OT_SPELLS[k] = playerCast
                refreshed = true
                break
            end
        end

        -- If we aren't refreshing, insert the new one.
        if not refreshed then
            --print("New cast detected!")
            table.insert(TGUF_PLAYER_OT_SPELLS, playerCast)
        end
    else
        --print("Not a tracked spell!")
        FreeCast(playerCast)
    end

    TGUnitCastTracker:Show()
    EventHandler.OnUpdate()
end

function EventHandler.UNIT_SPELLCAST_FAILED(unit, castGUID, spellID)
    TGDbg("TGUnitCastTracker: UNIT_SPELLCAST_FAILED"
          .." unit: "..tostring(unit)
          .." castGUID: "..tostring(castGUID)
          .." spellID: "..tostring(spellID)
          )
    local playerCast = TGUF_PLAYER_CAST[castGUID]
    TGUF_PLAYER_CAST[castGUID] = nil
    if playerCast then
        FreeCast(playerCast)
    end
end

function EventHandler.UNIT_SPELLCAST_FAILED_QUIET(unit, castGUID, spellID)
    TGDbg("TGUnitCastTracker: UNIT_SPELLCAST_FAILED"
          .." unit: "..tostring(unit)
          .." castGUID: "..tostring(castGUID)
          .." spellID: "..tostring(spellID)
          )
    local playerCast = TGUF_PLAYER_CAST[castGUID]
    TGUF_PLAYER_CAST[castGUID] = nil
    if playerCast then
        FreeCast(playerCast)
    end
end

function EventHandler.CLEU_UNIT_DIED(timestamp, _, _, _, _, _, targetGUID, targetName)
    TGCTDbg("["..timestamp.."] TGUnitCastTracker: CLEU_UNIT_DIED "
            .." targetGUID: "..tostring(targetGUID)
            .." targetName: "..tostring(targetName)
            )

    local removedOne
    repeat
        removedOne = false
        for k, v in pairs(TGUF_PLAYER_OT_SPELLS) do
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
        for k, v in pairs(TGUF_PLAYER_OT_SPELLS) do
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

TGEventHandler.Register(EventHandler)
