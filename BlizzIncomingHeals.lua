local HealComm = LibStub:GetLibrary("LibHealComm-3.0")
local addon = CreateFrame("FRAME")

local lastStatusBar
local remainingTime

function addon:OnEnable()
    print("enable")
    HealComm.RegisterCallback(self, "HealComm_DirectHealStart", "HealingStart")
    HealComm.RegisterCallback(self, "HealComm_DirectHealStop", "HealingStop")
    HealComm.RegisterCallback(self, "HealComm_HealModifierUpdate", "HealModifierUpdate")
    HealComm.RegisterCallback(self, "HealComm_DirectHealDelayed", "HealComm_DirectHealDelayed")
end


local timerFrame

local function UpdateHealingBar()
    local currentTime = GetTime()
    local elapsed = currentTime - timerFrame.startTime

    if remainingTime and remainingTime > 0 then
        remainingTime = remainingTime - elapsed
        if remainingTime <= 0 then
            remainingTime = 0
        end

        if lastStatusBar then
            lastStatusBar:SetValue(remainingTime)
        end
        print("start timer")
    else
        -- Healing is considered complete
        if lastStatusBar then
            lastStatusBar:Hide()
            lastStatusBar:SetValue(0)
            lastStatusBar = nil
        end
        remainingTime = nil
        timerFrame:Hide()
        timerFrame:SetScript("OnUpdate", nil) -- Stop the timer updates
        print("stoptimer")
    end
end




function addon:HealingStart(event, healerName, healSize, endTime, ...)
    --self:RegisterEvent("UNIT_HEALTH")
    --self:SetScript("OnUpdate", function() print("updating") end)
    --print(event)
    print("start")
    remainingTime = endTime - GetTime()
    print(string.format("%s heals. The cast will end in %d seconds.", healerName, remainingTime))

    -- Check if the timer needs to be started
    if remainingTime > 0 then
        if not timerFrame then
            timerFrame = CreateFrame("FRAME")
            timerFrame:SetScript("OnUpdate", UpdateHealingBar)
            timerFrame.startTime = GetTime() -- Store the start time
            timerFrame:Show()
        end
    else
        -- Healing is considered complete
        self:HealingStop()
    end

    if endTime >= GetTime() then addon:HealingStop() end

    for i=1, select('#', ...) do
        local targetName = select(i, ...)

        local maxHealth = UnitHealthMax(targetName)
        local curHealth = UnitHealth(targetName)
        local healthDeficit = maxHealth - curHealth
        local effectiveHealSize = math.min(healSize, healthDeficit)
        -- Calculate heal modifier
        local healModifier = HealComm:UnitHealModifierGet(targetName)
        effectiveHealSize = effectiveHealSize * healModifier

        local function createHealStatusBar(frameHealthBar)
            print("create")
            -- Check if the last status bar is for the same target
            if lastStatusBar and lastStatusBar.frameHealthBar == frameHealthBar then
                lastStatusBar:SetValue(healedHealth)
                return lastStatusBar
            end

            -- Create a new status bar
            local width = effectiveHealSize / maxHealth * frameHealthBar:GetWidth()
            local healedHealth = curHealth + effectiveHealSize
            local statusBar = CreateFrame("StatusBar", nil, frameHealthBar)
            statusBar:SetSize(frameHealthBar:GetWidth(), frameHealthBar:GetHeight())
            statusBar:SetPoint("LEFT", frameHealthBar, "LEFT", 0, 0)
            statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            statusBar:SetStatusBarColor(0, 1, 0, 0.6)
            statusBar:SetMinMaxValues(0, maxHealth)
            statusBar:SetValue(healedHealth)
            statusBar:SetFrameLevel(frameHealthBar:GetFrameLevel() - 1) -- Set the frame level below the health bar
            statusBar:SetFrameStrata(frameHealthBar:GetFrameStrata())
            statusBar:Show()
            lastStatusBar = statusBar -- Update the last status bar reference

            print(string.format("%s heals %s for %d", healerName, targetName, effectiveHealSize))
            return statusBar
        end



        if UnitIsUnit(targetName, "target") then -- Check if the current target is being healed
            self.targetStatusBar = createHealStatusBar(TargetFrameHealthBar)
        end
        if targetName == UnitName("player") then -- Check if the player is being healed
            self.playerStatusBar = createHealStatusBar(PlayerFrameHealthBar)
        end
        -- Check if any of the party members is being healed
        for partyIndex = 1, 5 do
            local partyUnitID = "party" .. partyIndex
            local partyFrame = _G["PartyMemberFrame" .. partyIndex]

            if partyFrame and UnitIsUnit(targetName, partyUnitID) then
                self["party" .. partyIndex .. "StatusBar"] = createHealStatusBar(partyFrame.healthbar)
            end
        end
    end
end



-- TODO: update bar when the modifier changed, while casting.
function addon:HealModifierUpdate(event, unit, targetName, healModifier)
    print("update")
    if unit == "player" then
        -- Update healing modifier for the player
        -- You can use the healModifier value for further calculations or updates
        print(string.format("Healing modifier updated for player: %s", healModifier))
    elseif unit:sub(1, 5) == "party" then
        -- Update healing modifier for party members
        local partyIndex = tonumber(unit:sub(6))
        -- You can use the healModifier value for further calculations or updates
        print(string.format("Healing modifier updated for party member %d: %s", partyIndex, healModifier))
    elseif unit:sub(1, 4) == "raid" then
        -- Update healing modifier for raid members
        local raidIndex = tonumber(unit:sub(5))
        -- You can use the healModifier value for further calculations or updates
        print(string.format("Healing modifier updated for raid member %d: %s", raidIndex, healModifier))
    end
end

-- it prints when someone who is healing you is getting his cast delayed, like taking damage, may be something else?
-- via this event: UNIT_SPELLCAST_DELAYED
function addon:HealComm_DirectHealDelayed(event, healerName, healSize, endTime, ...)
    print("delay")
    for i = 1, select('#', ...) do
        local targetName = select(i, ...)
        -- Handle the delayed healing for each target as needed
        print(string.format("%s's healing on %s has been delayed. New completion time: %f", healerName, targetName, endTime))
        -- You can update UI elements or perform other actions based on the delayed healing information
    end
end

function addon:HealingStop(event, healerName, healSize, succeeded, ...)
    print("stop")
    if self.targetStatusBar then
        self.targetStatusBar:Hide()
        self.targetStatusBar:SetValue(0)
        self.targetStatusBar = nil
    end
    if self.playerStatusBar then
        self.playerStatusBar:Hide()
        self.playerStatusBar:SetValue(0)
        self.playerStatusBar = nil
    end

    -- Hide and reset party status bars
    for partyIndex = 1, 5 do
        local partyStatusBar = self["party" .. partyIndex .. "StatusBar"]
        if partyStatusBar then
            partyStatusBar:Hide()
            partyStatusBar:SetValue(0)
            self["party" .. partyIndex .. "StatusBar"] = nil
        end
    end
    --print("stop")
    lastStatusBar = nil -- Reset the last status bar reference
end


addon:OnEnable()