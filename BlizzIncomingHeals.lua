local HealComm = LibStub:GetLibrary("LibHealComm-3.0")
local addon = CreateFrame("Frame")

local lastStatusBar

function addon:OnEnable()
    HealComm.RegisterCallback(self, "HealComm_DirectHealStart", "HealingStart")
    HealComm.RegisterCallback(self, "HealComm_DirectHealStop", "HealingStop")
    HealComm.RegisterCallback(self, "HealComm_HealModifierUpdate", "HealModifierUpdate")
    HealComm.RegisterCallback(self, "HealComm_DirectHealDelayed", "HealComm_DirectHealDelayed")
    self:RegisterEvent("UNIT_HEALTH")
    self:RegisterEvent("UNIT_MAXHEALTH")
    self:SetScript("OnEvent", function(self, event, ...)
        if event == "UNIT_HEALTH" then
            addon:UNIT_HEALTH(...)
        elseif event == "UNIT_MAXHEALTH" then
            addon:UNIT_MAXHEALTH(...)
        end
    end)
end

function addon:UNIT_HEALTH(event, unit)
    print(event)
    if lastStatusBar then
        lastStatusBar:Hide()
    end

    if self.targetStatusBar then
        self.targetStatusBar = createHealStatusBar(TargetFrameHealthBar)
    end

    if self.playerStatusBar then
        self.playerStatusBar = createHealStatusBar(PlayerFrameHealthBar)
    end

    -- Same for party status bars...
end

function addon:UNIT_MAXHEALTH(event, unit)
    print(event)
    if lastStatusBar then
        lastStatusBar:Hide()
    end
    lastStatusBar:Hide()
    if self.targetStatusBar then
        self.targetStatusBar = createHealStatusBar(TargetFrameHealthBar)
    end

    if self.playerStatusBar then
        self.playerStatusBar = createHealStatusBar(PlayerFrameHealthBar)
    end

    -- Same for party status bars...
end

function addon:HealingStart(event, healerName, healSize, endTime, ...)
    for i=1, select('#', ...) do
        local targetName = select(i, ...)

        local maxHealth = UnitHealthMax(targetName)
        local curHealth = UnitHealth(targetName)
        local healthDeficit = maxHealth - curHealth
        local effectiveHealSize = math.min(healSize, healthDeficit)
        -- Calculate heal modifier
        local healModifier = HealComm:UnitHealModifierGet(targetName)
        effectiveHealSize = effectiveHealSize * healModifier

            function createHealStatusBar(frameHealthBar)
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
    for i = 1, select('#', ...) do
        local targetName = select(i, ...)
        -- Handle the delayed healing for each target as needed
        print(string.format("%s's healing on %s has been delayed. New completion time: %f", healerName, targetName, endTime))
        -- You can update UI elements or perform other actions based on the delayed healing information
    end
end



function addon:HealingStop(event, healerName, healSize, succeeded, ...)
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
    print("stop")
    lastStatusBar = nil -- Reset the last status bar reference
end

--function addon:HandleSpellcastFailed(event, unit)
--    -- Reset the bars when a spellcast fails
--    if unit == "player" or unit == "target" or UnitInParty(unit) then
--        self:HealingStop(event, UnitName(unit), 0, false)
--    end
--end
--
---- Register the event handler
--addon:RegisterEvent("UNIT_SPELLCAST_FAILED")
--
---- Set the handler function for the event
--addon:SetScript("OnEvent", function(self, event, ...)
--    if event == "UNIT_SPELLCAST_FAILED" then
--        addon:HandleSpellcastFailed(event, ...)
--    end
--end)


addon:OnEnable()