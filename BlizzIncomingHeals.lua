local HealComm = LibStub:GetLibrary("LibHealComm-3.0")
local addon = {}

local lastStatusBar

function addon:OnEnable()
    HealComm.RegisterCallback(self, "HealComm_DirectHealStart", "HealingStart")
    HealComm.RegisterCallback(self, "HealComm_DirectHealStop", "HealingStop")
    HealComm.RegisterCallback(self, "HealComm_HealModifierUpdate", "HealModifierUpdate")
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

    local function createHealStatusBar(frameHealthBar)
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

function addon:HealModifierUpdate(event, unit, targetName, healModifier)
    if self.targetStatusBar then
        local maxHealth = UnitHealthMax(targetName)
        local curHealth = UnitHealth(targetName)
        local healthDeficit = maxHealth - curHealth
        local effectiveHealSize = math.min(healModifier * healSize, healthDeficit)

        -- Update the existing status bar with the new effective heal size
        self.targetStatusBar:SetValue(curHealth + effectiveHealSize)

        --print(string.format("Heal modifier updated: %s heals %s for %d", healerName, targetName, effectiveHealSize))
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

    lastStatusBar = nil -- Reset the last status bar reference
end


addon:OnEnable()