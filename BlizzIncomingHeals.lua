local HealComm = LibStub:GetLibrary("LibHealComm-3.0")
local addon = "BlizzIncomingHeals"
local addon = {}

function addon:OnEnable()
    HealComm.RegisterCallback(self, "HealComm_DirectHealStart", "HealingStart")
    HealComm.RegisterCallback(self, "HealComm_DirectHealStop", "HealingStop")
    -- Add any additional events to reset the status bar, as needed
end

function addon:HealingStart(event, healerName, healSize, endTime, ...)
    for i=1, select('#', ...) do
        local targetName = select(i, ...)
        
        local maxHealth = UnitHealthMax(targetName)
        local curHealth = UnitHealth(targetName)
        local healthDeficit = maxHealth - curHealth
        local effectiveHealSize = math.min(healSize, healthDeficit)
        
        local function createHealStatusBar(frameHealthBar)
            local width = effectiveHealSize / maxHealth * frameHealthBar:GetWidth()
            local healedHealth = curHealth + effectiveHealSize
            local statusBar = CreateFrame("StatusBar", nil, frameHealthBar)
            statusBar:SetSize(width, frameHealthBar:GetHeight())
            local currentPos = curHealth / maxHealth * frameHealthBar:GetWidth()
            statusBar:SetPoint("LEFT", frameHealthBar, "LEFT", currentPos, 0)
            statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            statusBar:SetStatusBarColor(0, 1, 0)
            statusBar:SetMinMaxValues(0, maxHealth)
            statusBar:SetValue(healedHealth)
            statusBar:SetFrameLevel(frameHealthBar:GetFrameLevel())
            statusBar:SetFrameStrata(frameHealthBar:GetFrameStrata())
            statusBar:Show()
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


function addon:HealingStop(event, healerName, healSize, succeeded, ...)
    if self.targetStatusBar then
        self.targetStatusBar:Hide() -- Hide and reset target status bar
        self.targetStatusBar:SetValue(0)
        self.targetStatusBar = nil
    end
    if self.playerStatusBar then
        self.playerStatusBar:Hide() -- Hide and reset player status bar
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
end

addon:OnEnable()