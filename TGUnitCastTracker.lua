-- A type to keep track of casts generated via UNIT_SPELLCAST events.
TGEventCast = {}
TGEventCast.__index = TGEventCast
TGEventCast.free_casts = {}

function TGEventCast:new(timestamp, castGUID, spellID)
    local cast
    if #TGEventCast.free_casts > 0 then
        cast = table.remove(TGEventCast.free_casts)
        assert(cast.allocated == false)
    else
        cast = {}
        setmetatable(cast, self)
    end

    cast.allocated  = true
    cast.timestamp  = timestamp
    cast.castGUID   = castGUID
    cast.spellID    = spellID
    cast.spellName  = GetSpellInfo(spellID)
    cast.castInfo   = TGSpellDB.OT_CAST_INFO[spellID]

    return cast
end

function TGEventCast:free()
    assert(self.allocated == true)
    self.allocated = false
    table.insert(TGEventCast.free_casts, self)
end

-- A type to keep track of casts generated via CLEU events.
TGCLEUCast = {}
TGCLEUCast.__index = TGCLEUCast
TGCLEUCast.free_casts = {}

function TGCLEUCast:new(timestamp, event, targetGUID, targetName, spellName)
    local cast
    if #TGCLEUCast.free_casts > 0 then
        cast = table.remove(TGCLEUCast.free_casts)
        assert(cast.allocated == false)
    else
        cast = {}
        setmetatable(cast, self)
    end

    cast.allocated  = true
    cast.timestamp  = timestamp
    cast.event      = event
    cast.targetGUID = targetGUID
    cast.targetName = targetName
    cast.spellName  = spellName

    return cast
end

function TGCLEUCast:free()
    assert(self.allocated == true)
    self.allocated = false
    table.insert(TGCLEUCast.free_casts, self)
end

-- Our cast tracker addon.
TGUCT = {
    tracked_spells = {},
    spell_frames   = {},
    log_level      = 1,
    log            = TGLog:new(1),

    event_casts    = {},
    cleu_casts     = {},
}

local function dbg(...)
    TGUCT.log:log(TGUCT.log_level, ...)
end

function TGUCT.ADDON_LOADED(addOnName)
    if addOnName ~= "TGUnitCastTracker" then
        return
    end

    local k = 1
    while true do
        local prefix = "TGUCTFrameBar"..k
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

        table.insert(TGUCT.spell_frames, spell_frames)

        k = k + 1
    end
end

function TGUCT.PushEventCast(cast)
    dbg("Pushing event cast: "..cast.spellName)
    table.insert(TGUCT.event_casts, cast)
end

function TGUCT.PushCLEUCast(cast)
    dbg("Pushing CLEU cast: "..cast.spellName)
    if cast.event ~= "SPELL_CAST_SUCCESS" then
        assert(#TGUCT.cleu_casts > 0)
        local last_cast = TGUCT.cleu_casts[#TGUCT.cleu_casts]
        assert(last_cast.timestamp  == cast.timestamp)
        assert(last_cast.targetGUID == cast.targetGUID)
        assert(last_cast.spellName  == cast.spellName)
        print("PushCLEUCast: Replacing "..last_cast.spellName.." "..
              last_cast.event.." with "..cast.event)
        last_cast.event = cast.event
    else
        table.insert(TGUCT.cleu_casts, cast)
    end
end

function TGUCT.ProcessCastFIFO()
    if #TGUCT.event_casts == 0 or #TGUCT.cleu_casts == 0 then
        return
    end

    local event_cast = table.remove(TGUCT.event_casts, 1)
    local cleu_cast  = table.remove(TGUCT.cleu_casts, 1)
    assert(event_cast.spellName == cleu_cast.spellName)

    if cleu_cast.event ~= "SPELL_CAST_SUCCESS" then
        print("ProcessCastFIFO: CLEU event was "..cleu_cast.event)
        event_cast:free()
        cleu_cast:free()
        return
    end

    local meta_cast = {
        event_cast = event_cast,
        cleu_cast  = cleu_cast,
    }

    -- Check if we are refreshing a spell.
    local refreshed = false
    for k, v in ipairs(TGUCT.tracked_spells) do
        if (v.event_cast.spellID   == meta_cast.event_cast.spellID and
            v.cleu_cast.targetGUID == meta_cast.cleu_cast.targetGUID) then
            v.event_cast:free()
            v.cleu_cast:free()
            TGUCT.tracked_spells[k] = meta_cast
            refreshed = true
            break
        end
    end

    -- If we aren't refreshing, insert the new one.
    if not refreshed then
        table.insert(TGUCT.tracked_spells, meta_cast)
    end

    TGUCTFrame:Show()
end

function TGUCT.DumpCastFIFO()
    print("*** Event casts ***")
    for _, v in ipairs(TGUCT.event_casts) do
        print("   "..v.spellName)
    end

    print("*** CLEU casts ***")
    for _, v in ipairs(TGUCT.cleu_casts) do
        print("   "..v.spellName)
    end
end

function TGUCT.UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID)
    if unit ~= "player" then
        return
    end

    local timestamp = GetTime()
    dbg("[", timestamp, "] TGUnitCastTracker: UNIT_SPELLCAST_SUCCEEDED unit",
        unit, " castGUID ", castGUID, " spellID ", spellID)
    dbg(" ")

    -- Push the spellcast if we care about it.
    local event_cast = TGEventCast:new(timestamp, castGUID, spellID)
    if event_cast.castInfo then
        TGUCT.PushEventCast(event_cast)
    else
        event_cast:free()
    end
end

function TGUCT.CLEU_SPELL_CAST_SUCCESS(timestamp, _, sourceGUID, _, _, _,
                                       targetGUID, targetName, _, _, _,
                                       spellName, _)
    dbg("[", timestamp, "] TGUnitCastTracker: CLEU_SPELL_CAST_SUCCESS ",
        "sourceGUID: ", sourceGUID, "targetGUID: ", targetGUID,
        " targetName: ", targetName, " spellName: ", spellName)
    if sourceGUID ~= UnitGUID("player") then
        return
    end

    if TGSpellDB.OVER_TIME_SPELL_LIST[spellName] then
        local cleu_cast = TGCLEUCast:new(timestamp, "SPELL_CAST_SUCCESS",
                                         targetGUID, targetName, spellName)
        TGUCT.PushCLEUCast(cleu_cast)
    end
end

function TGUCT.CLEU_SPELL_MISSED(timestamp, _, sourceGUID, _, _, _,
                                 targetGUID, targetName, _, _, _,
                                 spellName, _)
    dbg("[", timestamp, "] TGUnitCastTracker: CLEU_SPELL_MISSED ",
        "sourceGUID: ", sourceGUID, "targetGUID: ", targetGUID,
        " targetName: ", targetName, " spellName: ", spellName)
    if sourceGUID ~= UnitGUID("player") then
        return
    end

    if TGSpellDB.OVER_TIME_SPELL_LIST[spellName] then
        local cleu_cast = TGCLEUCast:new(timestamp, "SPELL_MISSED",
                                         targetGUID, targetName, spellName)
        TGUCT.PushCLEUCast(cleu_cast)
    end
end

function TGUCT.CLEU_UNIT_DIED(timestamp, _, _, _, _, _, targetGUID,
                              targetName)
    dbg("[", timestamp, "] TGUnitCastTracker: CLEU_UNIT_DIED targetGUID: ",
        targetGUID, " targetName: ", targetName)

    local removedOne
    repeat
        removedOne = false
        for k, v in ipairs(TGUCT.tracked_spells) do
            if v.cleu_cast.targetGUID == targetGUID then
                local meta_cast = table.remove(TGUCT.tracked_spells, k)
                meta_cast.event_cast:free()
                meta_cast.cleu_cast:free()
                removedOne = true
                break
            end
        end
    until(removedOne == false)
end

function TGUCT.OnUpdate()
    -- Process the cast FIFO.
    TGUCT.ProcessCastFIFO()

    -- Start by removing any old spells from the casting list
    local removedOne
    local currTime = GetTime()
    repeat
        removedOne = false
        for k, v in ipairs(TGUCT.tracked_spells) do
            if (v.event_cast.timestamp + v.event_cast.castInfo.length <=
                currTime)
            then
                local meta_cast = table.remove(TGUCT.tracked_spells, k)
                meta_cast.event_cast:free()
                meta_cast.cleu_cast:free()
                removedOne = true
                break
            end
        end
    until(removedOne == false)
    
    -- If we have no more spells, we are done
    local numSpells = #TGUCT.tracked_spells
    if (numSpells == 0) then
        TGUCTFrame:Hide()
        return
    end

    -- Okay, we need to display spells, limited to the number of available
    -- frames.
    if (numSpells > #TGUCT.spell_frames) then
        numSpells = #TGUCT.spell_frames
    end
    for k=1, numSpells do
        local v  = TGUCT.tracked_spells[k]
        local f  = TGUCT.spell_frames[k]
        local ec = v.event_cast
        local cc = v.cleu_cast
        
        -- Get the cast bar
        local percent = (currTime - ec.timestamp)/ec.castInfo.length
        if (percent > 1) then
            percent = 1
        end

        f.castTrackerBar:Show()
        f.castTrackerIcon:SetTexture(ec.castInfo.texture)
        f.castTrackerIcon:Show()
        f.castTrackerBarTexture:SetVertexColor(0.25,1,0.25,1)
        f.castTrackerBarFrameText:Show()
        f.castTrackerBarFrameText:SetText(cc.targetName)
        
        local realWidth = f.sizeFrame:GetWidth()
        local percentWidth = math.floor((1-percent)*realWidth + 0.5)
        if (percentWidth <= 0) then
            percentWidth = 1
        end
        f.castTrackerBarFrame:SetWidth(percentWidth);
        
        local elapsed = currTime - ec.timestamp;
        if (elapsed > 0.125 and ec.castInfo.tick ~= nil) then
            local modulo = (elapsed % ec.castInfo.tick)
            if (modulo > ec.castInfo.tick/2) then
                modulo = modulo - ec.castInfo.tick
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
    for k=numSpells+1, #TGUCT.spell_frames do
        TGUCT.spell_frames[k].castTrackerBar:Hide()
    end
    
    -- Finally set the height
    TGUCTFrame:SetHeight(11 + numSpells*15)
end

function TGUCT.ExtendETrace()
    if not EventTraceFrame then
        UIParentLoadAddOn("Blizzard_DebugTools")
    end

    local function addArgs(args, index, ...)
        for i = 1, select("#", ...) do
            if not args[i] then
                args[i] = {}
            end
            args[i][index] = select(i, ...)
        end
    end
     
    EventTraceFrame:HookScript("OnEvent", function(self, event)
        if (event == "COMBAT_LOG_EVENT_UNFILTERED" and
            not self.ignoredEvents[event] and
            self.events[self.lastIndex] == event) then
            addArgs(self.args, self.lastIndex, CombatLogGetCurrentEventInfo())
        end
    end)
end

TGEventManager.Register(TGUCT)

SlashCmdList["TGUCTETRACE"] = TGUCT.ExtendETrace
SLASH_TGUCTETRACE1 = "/tguctetrace"

SlashCmdList["TGUCTFIFO"] = TGUCT.DumpCastFIFO
SLASH_TGUCTFIFO1 = "/tguctfifo"
