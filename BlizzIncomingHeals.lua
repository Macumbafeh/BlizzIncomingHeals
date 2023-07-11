--------------------------------------------------------------------------------
---- BlizzIncomingHeals TBC 2.4.3
---- Idea by Macumba
---- Coding by Sattva and Macumba
---- Addon uses LibHealComm 3.0 callbacks.
--------------------------------------------------------------------------------


    local HealComm = LibStub:GetLibrary("LibHealComm-3.0")
    local addon = {}
    addon.healerStatusBars = addon.healerStatusBars or {}

    local AceTimer = LibStub("AceTimer-3.0")

    -- Assert color codes for clarity
    local COLOR_GREEN = "|cff00ff00"  -- Green
    local COLOR_RED = "|cffff0000"    -- Red
    local COLOR_YELLOW = "|cffffff00" -- Yellow
    local COLOR_RESET = "|r"         -- Reset

    local lastStatusBar

    function addon:OnEnable()
        self.activeHealers = {} -- table to store healer names
        self.totalHealMap = self.totalHealMap or {}
        HealComm.RegisterCallback(self, "HealComm_DirectHealStart", "HealingStart")
        HealComm.RegisterCallback(self, "HealComm_DirectHealStop", "HealingStop")
        --HealComm.RegisterCallback(self, "HealComm_HealModifierUpdate", "HealModifierUpdate")
        --HealComm.RegisterCallback(self, "HealComm_DirectHealDelayed", "HealComm_DirectHealDelayed")
    end

--------------------------------------------------------------------------------
----  Healing Start
--------------------------------------------------------------------------------

    function addon:HealingStart(event, healerName, healSize, endTime, ...)
        for i = 1, select('#', ...) do
            local targetName = select(i, ...)

            -- Check if the target is already being healed
            local totalIncomingHeal = 0
            if self.activeHealers[targetName] then
                for healer, _ in pairs(self.activeHealers[targetName]) do
                    if healer ~= healerName then
                        totalIncomingHeal = totalIncomingHeal + self:GetIncomingHealAmount(targetName, healer)
                    end
                end
            end

            --print(targetName) -- Print the targetName


            -- Calculate heal values and create heal status bar
            local maxHealth = UnitHealthMax(targetName)
            local curHealth = UnitHealth(targetName)
            local healthDeficit = maxHealth - curHealth
            local effectiveHealSize = math.min(healSize, healthDeficit)

            -- Calculate heal modifier
            local healModifier = HealComm:UnitHealModifierGet(targetName)
            effectiveHealSize = effectiveHealSize * healModifier

            ---- totalHealMap
            --print(effectiveHealSize)
            -- Update total heals
            addon.totalHealMap[targetName] = (addon.totalHealMap[targetName] or 0) + effectiveHealSize

            -- Print total expected heal size and effective heal size
            print(string.format(COLOR_GREEN .. "%d" .. COLOR_RESET .. " + " .. COLOR_RED .. "%d" .. COLOR_RESET .. " = " .. COLOR_YELLOW .. "%d" .. COLOR_RESET,
                    effectiveHealSize, addon.totalHealMap[targetName] - effectiveHealSize, addon.totalHealMap[targetName]))


                -- Calculate heal values and create heal status bar
                local maxHealth = UnitHealthMax(targetName)
                local curHealth = UnitHealth(targetName)
                local healthDeficit = maxHealth - curHealth
                local effectiveHealSize = math.min(healSize, healthDeficit)
                -- Calculate heal modifier
                local healModifier = HealComm:UnitHealModifierGet(targetName)
                effectiveHealSize = effectiveHealSize * healModifier



                --------------------------------------------------------------------------------
                ---- Create Incoming Heal Status Bar
                --------------------------------------------------------------------------------

                local function createHealStatusBar(frameHealthBar)
                    -- Check if the last status bar is for the same target
                    if lastStatusBar and lastStatusBar.frameHealthBar == frameHealthBar then
                        --print(healedHealth.."  healedhealth 1")
                        --print(addon.totalHealMap[targetName].. "  healmap 1")
                        lastStatusBar:SetValue(healedHealth)
                        return lastStatusBar
                    end

                    -- Create a new status bar
                    local width = effectiveHealSize / maxHealth * frameHealthBar:GetWidth()
                    local healedHealth = curHealth + effectiveHealSize
                    local statusBar = CreateFrame("StatusBar", "BlizzIncomingHealsStatusBar", frameHealthBar)
                    statusBar:SetSize(frameHealthBar:GetWidth(), frameHealthBar:GetHeight())
                    --print(frameHealthBar:GetWidth())
                    statusBar:SetPoint("LEFT", frameHealthBar, "LEFT", 0, 0)
                    statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

                    -- Add the status bar to the healer's list of status bars
                    addon.healerStatusBars[healerName] = addon.healerStatusBars[healerName] or {}
                    table.insert(addon.healerStatusBars[healerName], statusBar)
                    if totalIncomingHeal > 0 then
                        statusBar:SetStatusBarColor(1, 1, 0, 1) -- Yellow color
                    else
                        statusBar:SetStatusBarColor(1, 1, 1, 1) -- White color
                    end
                    statusBar:SetMinMaxValues(0, maxHealth)
                    --print(healedHealth.."  2")
                    --print(addon.totalHealMap[targetName].. "  healmap 2")

                    statusBar:SetValue(curHealth + addon.totalHealMap[targetName])

                    statusBar:SetFrameLevel(frameHealthBar:GetFrameLevel() - 1) -- Set the frame level below the health bar
                    statusBar:SetFrameStrata(frameHealthBar:GetFrameStrata())
                    statusBar:Show()

                    lastStatusBar = statusBar -- Update the last status bar reference

                    --print(string.format("%s heals %s for %d", healerName, targetName, effectiveHealSize))
                    return statusBar
                end


                --------------------------------------------------------------------------------
                -- Status bar creation ENDS
                --------------------------------------------------------------------------------
                --------------------------------------------------------------------------------
                ---- Healing Start CONTINUES
                --------------------------------------------------------------------------------


                -- Check if the target is the current target or player
                if UnitIsUnit(targetName, "target") then
                    self.targetStatusBar = createHealStatusBar(TargetFrameHealthBar)
                end
                if targetName == UnitName("player") then
                    self.playerStatusBar = createHealStatusBar(PlayerFrameHealthBar)
                end

                -- Check if any of the party members are being healed
                for partyIndex = 1, 5 do
                    local partyUnitID = "party" .. partyIndex
                    local partyFrame = _G["PartyMemberFrame" .. partyIndex]
                    if partyFrame and UnitIsUnit(targetName, partyUnitID) then
                        self["party" .. partyIndex .. "StatusBar"] = createHealStatusBar(partyFrame.healthbar)
                    end
                end

                -- Store active healers
                if not self.activeHealers[targetName] then
                    self.activeHealers[targetName] = {}
                end
                self.activeHealers[targetName][healerName] = true

        end
    end

    --------------------------------------------------------------------------------
    ---- Next func is used for getting total healing amount.
    --------------------------------------------------------------------------------


    function addon:GetIncomingHealAmount(targetName, healerName)
        local incomingHealBefore, incomingHealAfter, _, nextSize, nextName = HealComm:UnitIncomingHealGet(targetName, GetTime())
        if nextName and nextName == healerName then
            return nextSize
        end
        return 0
    end


--------------------------------------------------------------------------------
---- HealingStop
    ------ Fires IF:
        -- Someone stopped his cast.
        -- Someone got interrupted.
--------------------------------------------------------------------------------

    function addon:HealingStop(event, healerName, healSize, succeeded, ...)

        -- Reset all status bars created by the healer
        if addon.healerStatusBars[healerName] then
            for _, statusBar in ipairs(addon.healerStatusBars[healerName]) do
                statusBar:Hide()
                statusBar:SetValue(0)
            end
            addon.healerStatusBars[healerName] = {}  -- Clear the list of status bars for the healer
        end

        for i = 1, select('#', ...) do
            local targetName = select(i, ...)
            --print("|cFFFF0000Healing Stop is called|r")
            if self.activeHealers[targetName] then
                self.activeHealers[targetName][healerName] = nil

                -- Check if there are any healers left
                local healersLeft = false
                for _ in pairs(self.activeHealers[targetName]) do
                    healersLeft = true
                    break
                end


                -- If there are no healers left, hide the bar
                if not healersLeft then
                    if lastStatusBar then
                        --print("laststatus")
                        lastStatusBar:Hide()
                    end
                    lastStatusBar = nil -- Reset the last status bar reference
                    -- Reset total heal
                    addon.totalHealMap[targetName] = 0
                end
            end
        end
    end


    addon:OnEnable()


--------------------------------------------------------------------------------
-- HealModifierUpdate
-- fires when someone gains buff/debuff that affects healing size.
------ UPDATE: WE DO NOT USE IT YET.
--------------------------------------------------------------------------------

-- TODO: update bar when the modifier changed, while casting.
function addon:HealModifierUpdate(event, unit, targetName, healModifier)
end


-------------------------------------------------------------------------------------------------------
-- DirectHealDelayed
-- For now just prints when someone who is healing you is getting his cast delayed, like taking damage.
-- Possible usage is to UPDATE in how many seconds will you receive the heal.
-- But that needs HealingStart to be using endTime to create the timer... :)
-- This function works via this event: UNIT_SPELLCAST_DELAYED
---- UPDATE: WE DO NOT USE IT YET.
-------------------------------------------------------------------------------------------------------

function addon:HealComm_DirectHealDelayed(event, healerName, healSize, endTime, ...)
end

