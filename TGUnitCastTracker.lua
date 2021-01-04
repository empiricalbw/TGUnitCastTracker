
local function TGCTDbg(msg)
    --TGDbg(msg)
end

EventHandler = {
    free_casts     = {},
    cast_cache     = {},
    tracked_spells = {},
    spell_frames   = {},
}

function EventHandler.GetOrAllocateCast(timestamp, castGUID, spellID)
    -- See if we already know about this spell.
    local cast = EventHandler.cast_cache[castGUID]
    if cast ~= nil then
        return cast
    end

    -- Find or allocate a free cast object.
    if #EventHandler.free_casts > 0 then
        cast = table.remove(EventHandler.free_casts)
        assert(cast.allocated == false)
    else
        cast = {}
    end

    -- Populate it.
    cast.allocated  = true
    cast.targetName = UnitName("target")
    cast.targetGUID = UnitGUID("target")
    cast.castInfo   = TGSpellDB.OT_CAST_INFO[spellID]
    cast.castGUID   = castGUID
    cast.spellID    = spellID
    cast.timestamp  = timestamp
    cast.spellName  = GetSpellInfo(spellID)

    -- Record it and return.
    EventHandler.cast_cache[castGUID] = cast
    return cast
end

function EventHandler.FreeCast(cast)
    assert(cast.allocated == true)
    assert(EventHandler.cast_cache[cast.castGUID] == cast)

    cast.allocated            = false
    EventHandler.cast_cache[cast.castGUID] = nil
    table.insert(EventHandler.free_casts, cast)
end

function EventHandler.FreeCastByGUID(castGUID)
    local cast = EventHandler.cast_cache[castGUID]
    if cast then
        EventHandler.FreeCast(cast)
    end
end

function EventHandler.DumpCastCache()
    local t = GetTime()
    for k, v in pairs(EventHandler.cast_cache) do
        local dt = t - v.timestamp
        print("["..tostring(dt).."s ago] "..k..": "..tostring(v.spellName))
    end
end

function EventHandler.ADDON_LOADED(addOnName)
    if addOnName ~= "TGUnitCastTracker" then
        return
    end

    local k = 1
    while true do
        local prefix = "TGUnitCastTrackerBar"..k
        local spell_frames = {
            castTrackerBar          = _G[prefix],
            castTrackerIcon         = _G[prefix.."IconTexture"],
            castTrackerBarFrame     = _G[prefix.."Bar"],
            castTrackerBarFrameText = _G[prefix.."SizeFrameText"],
            castTrackerBarTexture   = _G[prefix.."BarTexture"],
            castTrackerBarSpark     = _G[prefix.."BarSpark"],
            sizeFrame               = _G[prefix.."SizeFrame"],
        }
        if spell_frames.castTrackerBar == nil then
            break
        end

        table.insert(EventHandler.spell_frames, spell_frames)

        k = k + 1
    end
end

function EventHandler.UNIT_SPELLCAST_SENT(unit, targetName, castGUID, spellID)
    local timestamp = GetTime()
    --[[
    TGDbg("["..timestamp.."] TGUnitCastTracker: UNIT_SPELLCAST_SENT"
            .." unit "..tostring(unit)
            .." targetName "..tostring(targetName)
            .." castGUID "..tostring(castGUID)
            .." spellID "..tostring(spellID)
            )
    ]]

    EventHandler.GetOrAllocateCast(timestamp, castGUID, spellID)
end

function EventHandler.UNIT_SPELLCAST_START(unit, castGUID, spellID)
    local timestamp = GetTime()
    --[[
    TGDbg("["..timestamp.."] TGUnitCastTracker: UNIT_SPELLCAST_START"
            .." unit "..tostring(unit)
            .." castGUID "..tostring(castGUID)
            .." spellID "..tostring(spellID)
            )
    ]]

    EventHandler.GetOrAllocateCast(timestamp, castGUID, spellID)
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
    local cast = EventHandler.GetOrAllocateCast(timestamp, castGUID, spellID)
    if not cast.castInfo then
        --print("Not a tracked spell!")
        EventHandler.FreeCast(cast)
        return
    end

    -- Check if we are refreshing a spell.
    local refreshed = false
    for k, v in ipairs(EventHandler.tracked_spells) do
        if (v.spellID    == cast.spellID and
            v.targetGUID == cast.targetGUID) then
            --print("Refresh "..v.castInfo.name.." with "..cast.castInfo.name.." detected!")
            EventHandler.FreeCast(v)
            EventHandler.tracked_spells[k] = cast
            refreshed = true
            break
        end
    end

    -- If we aren't refreshing, insert the new one.
    if not refreshed then
        --print("New cast detected!")
        table.insert(EventHandler.tracked_spells, cast)
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
    EventHandler.FreeCastByGUID(castGUID)
end

function EventHandler.UNIT_SPELLCAST_FAILED_QUIET(unit, castGUID, spellID)
    --[[
    TGDbg("TGUnitCastTracker: UNIT_SPELLCAST_FAILED_QUIET"
          .." unit: "..tostring(unit)
          .." castGUID: "..tostring(castGUID)
          .." spellID: "..tostring(spellID)
          )
    ]]
    EventHandler.FreeCastByGUID(castGUID)
end

function EventHandler.UNIT_SPELLCAST_INTERRUPTED(unit, castGUID, spellID)
    --[[
    TGDbg("TGUnitCastTracker: UNIT_SPELLCAST_INTERRUPTED"
          .." unit: "..tostring(unit)
          .." castGUID: "..tostring(castGUID)
          .." spellID: "..tostring(spellID)
          )
    ]]
    EventHandler.FreeCastByGUID(castGUID)
end

function EventHandler.CLEU_UNIT_DIED(timestamp, _, _, _, _, _, targetGUID,
                                     targetName)
    --[[
    TGCTDbg("["..timestamp.."] TGUnitCastTracker: CLEU_UNIT_DIED "
            .." targetGUID: "..tostring(targetGUID)
            .." targetName: "..tostring(targetName)
            )
    ]]

    local removedOne
    repeat
        removedOne = false
        for k, v in ipairs(EventHandler.tracked_spells) do
            if v.targetGUID == targetGUID then
                --print("Unit Died, freeing spell")
                EventHandler.FreeCast(
                    table.remove(EventHandler.tracked_spells, k))
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
        for k, v in ipairs(EventHandler.tracked_spells) do
            if (v.timestamp + v.castInfo.length <= currTime) then
                --print("Spell expired, freeing spell!")
                EventHandler.FreeCast(
                    table.remove(EventHandler.tracked_spells, k))
                removedOne = true
                break
            end
        end
    until(removedOne == false)
    
    -- If we have no more spells, we are done
    local numSpells = #EventHandler.tracked_spells
    if (numSpells == 0) then
        TGUnitCastTracker:Hide()
        return
    end

    -- Okay, we need to display spells, limited to the number of available
    -- frames.
    if (numSpells > #EventHandler.spell_frames) then
        numSpells = #EventHandler.spell_frames
    end
    for k=1, numSpells do
        local v = EventHandler.tracked_spells[k]
        local f = EventHandler.spell_frames[k]
        
        -- Get the cast bar
        local percent = (currTime - v.timestamp)/v.castInfo.length
        if (percent > 1) then
            percent = 1
        end

        f.castTrackerBar:Show()
        f.castTrackerIcon:SetTexture(v.castInfo.texture)
        f.castTrackerIcon:Show()
        f.castTrackerBarTexture:SetVertexColor(0.25,1,0.25,1)
        f.castTrackerBarFrameText:Show()
        f.castTrackerBarFrameText:SetText(v.targetName)
        
        local realWidth = f.sizeFrame:GetWidth()
        --TGUFMsg(""..(1-percent)*realWidth)
        local percentWidth = math.floor((1-percent)*realWidth + 0.5)
        if (percentWidth <= 0) then
            percentWidth = 1
        end
        --print(percentWidth)
        f.castTrackerBarFrame:SetWidth(percentWidth);
        
        local elapsed = currTime - v.timestamp;
        if (elapsed > 0.125 and v.castInfo.tick ~= nil) then
            local modulo = (elapsed % v.castInfo.tick)
            if (modulo > v.castInfo.tick/2) then
                modulo = modulo - v.castInfo.tick
            end
            modulo = modulo + 0.125
            if (0 <= modulo and modulo < 0.5) then
                f.castTrackerBarSpark:SetAlpha(1-2*modulo)
            else
                f.castTrackerBarSpark:SetAlpha(0)
            end
        else
            f.castTrackerBarSpark:SetAlpha(0)
        end
    end
    
    -- Hide others
    for k=numSpells+1, #EventHandler.spell_frames do
        EventHandler.spell_frames[k].castTrackerBar:Hide()
    end
    
    -- Finally set the height
    TGUnitCastTracker:SetHeight(11 + numSpells*15)
end

TGEventManager.Register(EventHandler)

SlashCmdList["TGUCTDUMP"] = EventHandler.DumpCastCache
SLASH_TGUCTDUMP1 = "/tguctdump"
