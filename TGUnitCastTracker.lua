-- Anatomy of a spellcast.  Here's Eye of Kilrogg, which starts with a cast and
-- then switches to channeling:
--
--  Frame   Event                           Valid
--  0       UNIT_SPELLCAST_SENT             castGUID, spellID
--  0       UNIT_SPELLCAST_START            castGUID, spellID
--  1       UNIT_SPELLCAST_DELAYED          castGUID, spellID (on damage)
--          (Note: no UNIT_SPELLCAST_STOP)
--  2       UNIT_SPELLCAST_CHANNEL_START    spellID
--  2       UNIT_SPELLCAST_SUCCEEDED        castGUID, spellID
--  2       CLEU_SPELL_CAST_SUCCESS         sourceGUID, targetGUID, spellName
--  3       UNIT_SPELLCAST_CHANNEL_STOP     spellID
--
-- Here's Drain Soul, which is purely channeled:
--
--  0       UNIT_SPELLCAST_SENT             castGUID, spellID
--  0       UNIT_SPELLCAST_CHANNEL_START    spellID
--  0       UNIT_SPELLCAST_SUCCEEDED        castGUID, spellID
--  0       CLEU_SPELL_CAST_SUCCESS         sourceGUID, targetGUID, spellName
--  1       UNIT_SPELLCAST_CHANNEL_UPDATE   spellID (on damage)
--  2       UNIT_SPELLCAST_CHANNEL_STOP     spellID
--
-- Here's Soul Fire, which is purely cast:
--
--  0       UNIT_SPELLCAST_SENT             castGUID, spellID
--  0       UNIT_SPELLCAST_START            castGUID, spellID
--  1       UNIT_SPELLCAST_DELAYED          castGUID, spellID (on damage)
--  2       UNIT_SPELLCAST_SUCCEEDED        castGUID, spellID
--  2       UNIT_SPELLCAST_STOP             castGUID, spellID
--  2       CLEU_SPELL_CAST_SUCCESS         sourceGUID, targetGUID, spellName
--
-- Here's Summon Imp, which is purely cast with no offensive component:
--
--  0       UNIT_SPELLCAST_SENT             castGUID, spellID
--  0       UNIT_SPELLCAST_START            castGUID, spellID
--  1       UNIT_SPELLCAST_SUCCEEDED        castGUID, spellID
--  1       UNIT_SPELLCAST_STOP             castGUID, spellID
--  1       CLEU_SPELL_CAST_SUCCESS         sourceGUID, spellName
--
-- Here's Summon Imp, but interrupt by moving before it completes:
--
--  0       UNIT_SPELLCAST_SENT             castGUID, spellID
--  0       UNIT_SPELLCAST_START            castGUID, spellID
--  1       UNIT_SPELLCAST_INTERRUPTED      castGUID, spellID
--  1       UNIT_SPELLCAST_STOP             castGUID, spellID
--  2       UNIT_SPELLCAST_INTERRUPTED      castGUID, spellID
--  2       UNIT_SPELLCAST_INTERRUPTED      castGUID, spellID
--  2       UNIT_SPELLCAST_INTERRUPTED      castGUID, spellID
--
-- Here's Create Healthstone (Greater), which doesn't even have a visible non-
-- player component:
--
--  0       UNIT_SPELLCAST_SENT             castGUID, spellID
--  0       UNIT_SPELLCAST_START            castGUID, spellID
--  1       UNIT_SPELLCAST_SUCCEEDED        castGUID, spellID
--  1       UNIT_SPELLCAST_STOP             castGUID, spellID
--  1       CLEU_SPELL_CAST_SUCCESS         sourceGUID, spellName
--
-- Here's Create Healthstone (Greater) when you already have one in your
-- inventory:
--
--  0       UNIT_SPELLCAST_SENT             castGUID, spellID
--  0       UNIT_SPELLCAST_FAILED           castGUID, spellID (different!?)
--  0       UNIT_SPELLCAST_FAILED_QUIET     castGUID, spellID
--
-- Here's Siphon Life, which is an instant cast with a DoT component:
--
--  0       UNIT_SPELLCAST_SENT             castGUID, spellID
--  0       UNIT_SPELLCAST_SUCCEEDED        castGUID, spellID
--  0       CLEU_SPELL_CAST_SUCCESS         sourceGUID, targetGUID, spellName
--  0       CLEU_SPELL_AURA_APPLIED         sourceGUID, targetGUID, spellName
--
-- Here's Drain Soul, which is a channeled spell with a DoT component:
--
--  0       UNIT_SPELLCAST_SENT             castGUID, spellID
--  0       UNIT_SPELLCAST_CHANNEL_START    spellID
--  0       CLEU_SPELL_AURA_APPLIED         (self Drain Soul BUFF)
--  0       UNIT_SPELLCAST_SUCCEEDED        castGUID, spellID
--  0       CLEU_SPELL_CAST_SUCCESS         sourceGUID, targetGUID, spellName
--  1       CLEU_SPELL_AURA_APPLIED         sourceGUID, targetGUID, spellName
--  2       UNIT_SPELLCAST_CHANNEL_STOP     spellID
--
-- Here's what we get when a Defias Rogue Wizard hits me with a Frostbolt:
--
--  0       CLEU_SPELL_CAST_START           sourceGUID, spellName
--  1       CLEU_SPELL_CAST_SUCCESS         sourceGUID, targetGUID, spellName
--  2       CLEU_SPELL_DAMAGE               sourceGUID, targetGUID, spellName
--
-- And when he misses:
--
--  0       CLEU_SPELL_CAST_START           sourceGUID, spellName
--  1       CLEU_SPELL_CAST_SUCCESS         sourceGUID, targetGUID, spellName
--  2       CLEU_SPELL_MISSED               sourceGUID, targetGUID, spellName
--
-- So for mob spell notification, we should just watch for SPELL_CAST_START and
-- SPELL_CAST_SUCCESS.  Note that if I fear the mob while it is casting, there
-- is no CLEU notification that the mob's cast failed.

local TGUCTSavedVariablesDefault = {
    position = {
        x = 954,    -- Distance from left edge of screen to left of frame
        y = 257,    -- Distance from bottom edge screen to top of frame
    },
    castingColor = {
        r = 1,
        g = 1,
        b = 0.25,
        a = 1,
    },
    channelingColor = {
        r = 0.25,
        g = 1,
        b = 0.25,
        a = 1,
    },
}
TGUCTSavedVariables = {}

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
    cast_frame     = nil,
    spell_frames   = {},
    log_level      = 1,
    log            = TGLog:new(1),
    log_timestamp  = nil,

    event_casts    = {},
    cleu_casts     = {},

    cast_info = {
        name      = nil,
        text      = nil,
        texture   = nil,
        startTime = nil,
        endTime   = nil,
        castGUID  = nil,
        spellId   = nil,
        shrink    = false,
        color     = nil,
    },
    channel_info = {
        name      = nil,
        text      = nil,
        texture   = nil,
        startTime = nil,
        endTime   = nil,
        spellId   = nil,
        shrink    = true,
        color     = nil,
    },
}

local function dbg(...)
    local timestamp = GetTime()
    if timestamp ~= TGUCT.log_timestamp then
        TGUCT.log_timestamp = timestamp
        TGUCT.log:log(TGUCT.log_level, " ")
    end
    TGUCT.log:log(TGUCT.log_level, "[", timestamp, "] ", ...)
end

function TGUCT.ADDON_LOADED(addOnName)
    if addOnName ~= "TGUnitCastTracker" then
        return
    end

    for k, v in pairs(TGUCTSavedVariablesDefault) do
        if TGUCTSavedVariables[k] == nil then
            TGUCTSavedVariables[k] = TGUCTSavedVariablesDefault[k]
        end
    end
    TGUCT.cast_info.color    = TGUCTSavedVariables.castingColor
    TGUCT.channel_info.color = TGUCTSavedVariables.channelingColor

    TGUCT.SetPosition(TGUCTSavedVariables.position.x,
                      TGUCTSavedVariables.position.y)

    TGUCT.cast_frame = {
        icon       = TGUCTFrameCastBarIconTexture,
        bar        = TGUCTFrameCastBarBar,
        text       = TGUCTFrameCastBarSizeFrameText,
        barTexture = TGUCTFrameCastBarBarTexture,
        barSpark   = TGUCTFrameCastBarBarSpark,
        sizeFrame  = TGUCTFrameCastBarSizeFrame,
    }
    TGUCT.cast_frame.bar:Hide()
    TGUCT.cast_frame.text:Show()
    TGUCT.cast_frame.text:SetJustifyH("CENTER")
    TGUCT.cast_frame.text:SetText("--")

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

function TGUCT.OnMouseDown(button)
    if button == "LeftButton" and not TGUCTFrame.isMoving then
        TGUCTFrame:StartMoving()
        TGUCTFrame.isMoving = true
    end
end

function TGUCT.OnMouseUp(button)
    if button == "LeftButton" and TGUCTFrame.isMoving then
        TGUCTFrame:StopMovingOrSizing()
        TGUCTFrame.isMoving = false
        TGUCT.SetPosition(TGUCTFrame:GetLeft(), TGUCTFrame:GetTop())
    end
end

function TGUCT.OnHide()
    if TGUCTFrame.isMoving then
        TGUCTFrame:StopMovingOrSizing()
        TGUCTFrame.isMoving = false
        TGUCT.SetPosition(TGUCTFrame:GetLeft(), TGUCTFrame:GetTop())
    end
end

function TGUCT.SetPosition(x, y)
    TGUCTFrame:ClearAllPoints()
    TGUCTFrame:SetUserPlaced(false)
    TGUCTFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    TGUCTSavedVariables.position.x = x
    TGUCTSavedVariables.position.y = y
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
    if (event_cast.spellName ~= cleu_cast.spellName) then
        print(event_cast.spellName)
        print(cleu_cast.spellName)
    end
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

    --TGUCTFrame:Show()
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

function TGUCT.UNIT_SPELLCAST_SENT(unit, target, castGUID, spellID)
    if unit ~= "player" then
        return
    end

    dbg("UNIT_SPELLCAST_SENT unit: ", unit, " target: ", target, " castGUID: ",
        castGUID, " spellID: ", spellID)
end

function TGUCT.UNIT_SPELLCAST_START(unit, castGUID, spellID)
    if unit ~= "player" then
        return
    end

    dbg("UNIT_SPELLCAST_START unit: ", unit, " castGUID: ", castGUID,
        " spellID: ", spellID)

    TGUCT.channel_info.name = nil

    TGUCT.cast_info.name,
    TGUCT.cast_info.text,
    TGUCT.cast_info.texture,
    TGUCT.cast_info.startTime,
    TGUCT.cast_info.endTime,
    _,
    TGUCT.cast_info.castGUID,
    _,
    TGUCT.cast_info.spellId = CastingInfo()
end

function TGUCT.UNIT_SPELLCAST_DELAYED(unit, castGUID, spellID)
    if unit ~= "player" then
        return
    end

    dbg("UNIT_SPELLCAST_DELAYED unit: ", unit, " castGUID: ", castGUID,
        " spellID: ", spellID)

    TGUCT.cast_info.name,
    TGUCT.cast_info.text,
    TGUCT.cast_info.texture,
    TGUCT.cast_info.startTime,
    TGUCT.cast_info.endTime,
    _,
    TGUCT.cast_info.castGUID,
    _,
    TGUCT.cast_info.spellId = CastingInfo()
end

function TGUCT.UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID)
    if unit ~= "player" then
        return
    end

    dbg("UNIT_SPELLCAST_SUCCEEDED unit: ", unit, " castGUID: ", castGUID,
        " spellID: ", spellID)

    -- Push the spellcast if we care about it.
    local event_cast = TGEventCast:new(GetTime(), castGUID, spellID)
    if event_cast.castInfo then
        TGUCT.PushEventCast(event_cast)
    else
        event_cast:free()
    end
end

function TGUCT.UNIT_SPELLCAST_FAILED(unit, castGUID, spellID)
    if unit ~= "player" then
        return
    end

    dbg("UNIT_SPELLCAST_FAILED unit: ", unit, " castGUID: ", castGUID,
        " spellID: ", spellID)
end

function TGUCT.UNIT_SPELLCAST_FAILED_QUIET(unit, castGUID, spellID)
    if unit ~= "player" then
        return
    end

    dbg("UNIT_SPELLCAST_FAILED_QUIET unit: ", unit, " castGUID: ", castGUID,
        " spellID: ", spellID)
end

function TGUCT.UNIT_SPELLCAST_INTERRUPTED(unit, castGUID, spellID)
    if unit ~= "player" then
        return
    end

    dbg("UNIT_SPELLCAST_INTERRUPTED unit: ", unit, " castGUID: ", castGUID,
        " spellID: ", spellID)
end

function TGUCT.UNIT_SPELLCAST_STOP(unit, castGUID, spellID)
    if unit ~= "player" then
        return
    end

    dbg("UNIT_SPELLCAST_STOP unit: ", unit, " castGUID: ", castGUID,
        " spellID: ", spellID)

    TGUCT.cast_info.name = nil
end

function TGUCT.UNIT_SPELLCAST_CHANNEL_START(unit, castGUID, spellID)
    if unit ~= "player" then
        return
    end

    dbg("UNIT_SPELLCAST_CHANNEL_START unit: ", unit, " castGUID: ", castGUID,
        " spellID: ", spellID)

    TGUCT.cast_info.name = nil

    TGUCT.channel_info.name,
    TGUCT.channel_info.text,
    TGUCT.channel_info.texture,
    TGUCT.channel_info.startTime,
    TGUCT.channel_info.endTime,
    _,
    _,
    TGUCT.channel_info.spellId = ChannelInfo()
end

function TGUCT.UNIT_SPELLCAST_CHANNEL_UPDATE(unit, castGUID, spellID)
    if unit ~= "player" then
        return
    end

    dbg("UNIT_SPELLCAST_CHANNEL_UPDATE unit: ", unit, " castGUID: ", castGUID,
        " spellID: ", spellID)

    TGUCT.channel_info.name,
    TGUCT.channel_info.text,
    TGUCT.channel_info.texture,
    TGUCT.channel_info.startTime,
    TGUCT.channel_info.endTime,
    _,
    _,
    TGUCT.channel_info.spellId = ChannelInfo()
end

function TGUCT.UNIT_SPELLCAST_CHANNEL_STOP(unit, castGUID, spellID)
    if unit ~= "player" then
        return
    end

    dbg("UNIT_SPELLCAST_CHANNEL_STOP unit: ", unit, " castGUID: ", castGUID,
        " spellID: ", spellID)

    TGUCT.channel_info.name = nil
end

function TGUCT.CLEU_SPELL_CAST_START(cleu_timestamp, _, sourceGUID, _, _, _,
                                     targetGUID, targetName, _, _, _,
                                     spellName, _)
    dbg("CLEU_SPELL_CAST_START sourceGUID: ", sourceGUID, " targetGUID: ",
        targetGUID, " targetName: ", targetName, " spellName: ", spellName)
end

function TGUCT.CLEU_SPELL_CAST_SUCCESS(cleu_timestamp, _, sourceGUID, _, _, _,
                                       targetGUID, targetName, _, _, _,
                                       spellName, _)
    dbg("CLEU_SPELL_CAST_SUCCESS sourceGUID: ", sourceGUID, " targetGUID: ",
        targetGUID, " targetName: ", targetName, " spellName: ", spellName)
    if sourceGUID ~= UnitGUID("player") then
        return
    end

    if TGSpellDB.OVER_TIME_SPELL_LIST[spellName] then
        local cleu_cast = TGCLEUCast:new(cleu_timestamp, "SPELL_CAST_SUCCESS",
                                         targetGUID, targetName, spellName)
        TGUCT.PushCLEUCast(cleu_cast)
    end
end

function TGUCT.CLEU_SPELL_CAST_FAILED(cleu_timestamp, _, sourceGUID, _, _, _,
                                      targetGUID, targetName, _, _, _,
                                      spellName, _, failedType)
    dbg("CLEU_SPELL_CAST_FAILED sourceGUID: ", sourceGUID, " targetGUID: ",
        targetGUID, " targetName: ", targetName, " spellName: ", spellName,
        " failedType: ", failedType)
end

function TGUCT.CLEU_SPELL_DAMAGE(cleu_timestamp, _, sourceGUID, _, _, _,
                                 targetGUID, targetName, _, _, _,
                                 spellName)
    dbg("CLEU_SPELL_CAST_DAMAGE sourceGUID: ", sourceGUID, " targetGUID: ",
        targetGUID, " targetName: ", targetName, " spellName: ", spellName)
end

function TGUCT.CLEU_SPELL_MISSED(cleu_timestamp, _, sourceGUID, _, _, _,
                                 targetGUID, targetName, _, _, _,
                                 spellName, _, missType, isOffHand,
                                 amountMissed, critical)
    dbg("CLEU_SPELL_MISSED sourceGUID: ", sourceGUID, " targetGUID: ",
        targetGUID, " targetName: ", targetName, " spellName: ", spellName,
        " missType: ", missType, " isOffHand: ", isOffHand, " amountMissed: ",
        amountMissed, " critical: ", critical)
    if sourceGUID ~= UnitGUID("player") then
        return
    end

    if TGSpellDB.OVER_TIME_SPELL_LIST[spellName] then
        local cleu_cast = TGCLEUCast:new(cleu_timestamp, "SPELL_MISSED",
                                         targetGUID, targetName, spellName)
        TGUCT.PushCLEUCast(cleu_cast)
    end
end

function TGUCT.CLEU_SPELL_AURA_APPLIED(cleu_timestamp, _, sourceGUID, _, _, _,
                                       targetGUID, targetName, _, _, _,
                                       spellName, _, auraType, amount)
    dbg("CLEU_SPELL_AURA_APPLIED sourceGUID: ", sourceGUID, " targetGUID: ",
        targetGUID, " targetName: ", targetName, " spellName: ", spellName,
        " auraType: ", auraType, " amount: ", amount)
end

function TGUCT.CLEU_UNIT_DIED(cleu_timestamp, _, _, _, _, _, targetGUID,
                              targetName)
    dbg("CLEU_UNIT_DIED targetGUID: ", targetGUID, " targetName: ", targetName)

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

    -- Update cast bar text.
    local currTime  = GetTime()
    local cast_info = nil
    if TGUCT.cast_info.name ~= nil then
        cast_info = TGUCT.cast_info
    elseif TGUCT.channel_info.name ~= nil then
        cast_info = TGUCT.channel_info
    end
    if cast_info ~= nil then
        TGUCT.cast_frame.text:SetText(cast_info.name)
        TGUCT.cast_frame.icon:SetTexture(cast_info.texture)
        TGUCT.cast_frame.icon:Show(cast_info.texture)
        TGUCT.cast_frame.barTexture:SetVertexColor(cast_info.color.r,
                                                   cast_info.color.g,
                                                   cast_info.color.b)

        local length  = cast_info.endTime - cast_info.startTime
        local percent = (currTime*1000 - cast_info.startTime)/length
        if percent < 0 then
            percent = 0
        end
        if percent <= 1 then
            local realWidth = TGUCT.cast_frame.sizeFrame:GetWidth()
            local percentWidth
            if cast_info.shrink then
                percentWidth = math.floor((1-percent)*realWidth + 0.5)
            else
                percentWidth = math.floor(percent*realWidth + 0.5)
            end
            if (percentWidth <= 0) then
                percentWidth = 1
            end
            TGUCT.cast_frame.bar:SetWidth(percentWidth)
            TGUCT.cast_frame.bar:Show()
        else
            TGUCT.cast_frame.text:SetText("--")
            TGUCT.cast_frame.icon:Hide()
            TGUCT.cast_frame.bar:Hide()
            cast_info.name = nil
        end
    else
        TGUCT.cast_frame.text:SetText("--")
        TGUCT.cast_frame.icon:Hide()
        TGUCT.cast_frame.bar:Hide()
    end

    -- Start by removing any old spells from the casting list
    local removedOne
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
    if (cast_info == nil and numSpells == 0) then
        TGUCTFrame:Hide()
        return
    end
    TGUCTFrame:Show()

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
        f.castTrackerBarFrame:SetWidth(percentWidth)
        
        local elapsed = currTime - ec.timestamp
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
    TGUCTFrame:SetHeight(11 + numSpells*15 + 15)
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
