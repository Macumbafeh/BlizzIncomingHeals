local HealComm = LibStub:GetLibrary("LibHealComm-3.0")
local addon = {}
local AceTimer = LibStub("AceTimer-3.0")

-- Assert color codes for clarity
local COLOR_GREEN = "|cff00ff00"  -- Green
local COLOR_RED = "|cffff0000"    -- Red
local COLOR_YELLOW = "|cffffff00" -- Yellow
local COLOR_RESET = "|r"         -- Reset

local lastStatusBar

function addon:OnEnable()
    self.activeHealers = {} -- table to store healer names
    HealComm.RegisterCallback(self, "HealComm_DirectHealStart", "HealingStart")
    HealComm.RegisterCallback(self, "HealComm_DirectHealStop", "HealingStop")
    HealComm.RegisterCallback(self, "HealComm_HealModifierUpdate", "HealModifierUpdate")
    HealComm.RegisterCallback(self, "HealComm_DirectHealDelayed", "HealComm_DirectHealDelayed")
end

--------------------------------------------------------------------------------
----  Healing Start
--------------------------------------------------------------------------------

-- Adding this outside of your function to keep track of total heals
addon.totalHealMap = addon.totalHealMap or {}

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

        -- Calculate heal values and create heal status bar
        local maxHealth = UnitHealthMax(targetName)
        local curHealth = UnitHealth(targetName)
        local healthDeficit = maxHealth - curHealth
        local effectiveHealSize = math.min(healSize, healthDeficit)

        -- Calculate heal modifier
        local healModifier = HealComm:UnitHealModifierGet(targetName)
        effectiveHealSize = effectiveHealSize * healModifier

        -- Update total heals
        addon.totalHealMap[targetName] = (addon.totalHealMap[targetName] or 0) + effectiveHealSize

        -- Print total expected heal size and effective heal size
        print(string.format(COLOR_GREEN .. "%d" .. COLOR_RESET .. " + " .. COLOR_RED .. "%d" .. COLOR_RESET .. " = " .. COLOR_YELLOW .. "%d" .. COLOR_RESET,
                effectiveHealSize, addon.totalHealMap[targetName] - effectiveHealSize, addon.totalHealMap[targetName]))

        if totalIncomingHeal > 0 then
            -- for now preventing new bar to be created if there is already incoming heal
            --print(targetName .. " is already being healed for a total of " .. totalIncomingHeal .. " HP.")
        else
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
                    lastStatusBar:SetValue(healedHealth)
                    return lastStatusBar
                end

                -- Create a new status bar
                local width = effectiveHealSize / maxHealth * frameHealthBar:GetWidth()
                local healedHealth = curHealth + effectiveHealSize
                local statusBar = CreateFrame("StatusBar", "BlizzIncomingHealsStatusBar", frameHealthBar)
                statusBar:SetSize(frameHealthBar:GetWidth(), frameHealthBar:GetHeight())
                statusBar:SetPoint("LEFT", frameHealthBar, "LEFT", 0, 0)
                statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
                statusBar:SetStatusBarColor(0, 1, 0, 0.6)
                statusBar:SetMinMaxValues(0, maxHealth)
                statusBar:SetValue(healedHealth)
                statusBar:SetFrameLevel(frameHealthBar:GetFrameLevel() - 1) -- Set the frame level below the health bar
                statusBar:SetFrameStrata(frameHealthBar:GetFrameStrata())
                statusBar:Show()
                local remainingTime = endTime - GetTime()
                function addon:PrintAndHideStatusBar(statusBar)
                    if statusBar then
                        --print("Timer has ended, hiding...")
                        statusBar:Hide()
                        statusBar:SetValue(0)
                        -- Reset accumulated healing for the target
                        addon.totalHealMap[targetName] = 0
                    end
                end

                statusBar.timerID = AceTimer:ScheduleTimer(function() self:PrintAndHideStatusBar(statusBar) end, remainingTime)
                lastStatusBar = statusBar -- Update the last status bar reference

                --print(string.format("%s heals %s for %d", healerName, targetName, effectiveHealSize))
                return statusBar
            end


            --------------------------------------------------------------------------------
            -- Status bar creation ENDS
            --------------------------------------------------------------------------------
            --------------------------------------------------------------------------------
            -- Healing Start CONTINUES
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
end

function addon:GetIncomingHealAmount(targetName, healerName)
    local incomingHealBefore, incomingHealAfter, _, nextSize, nextName = HealComm:UnitIncomingHealGet(targetName, GetTime())
    if nextName and nextName == healerName then
        return nextSize
    end
    return 0
end


--------------------------------------------------------------------------------
---- Some debug codes.
--------------------------------------------------------------------------------


    --===== Prints whatever is inside local addon = {} table. Usage /run PrintAddonTableContains() =====--

    --function PrintAddonTableContains()
    --    for key, value in pairs(addon) do
    --        print(key, value)
    --    end
    --end



--------------------------------------------------------------------------------
---- HealModifierUpdate
    -- fires when someone gains buff/debuff that affects healing size.
--------------------------------------------------------------------------------

    -- TODO: update bar when the modifier changed, while casting.
    function addon:HealModifierUpdate(event, unit, targetName, healModifier)
        if unit == "player" then
            -- Update healing modifier for the player
            -- You can use the healModifier value for further calculations or updates
            --print(string.format("Healing modifier updated for player: %s", healModifier))
        elseif unit:sub(1, 5) == "party" then
            -- Update healing modifier for party members
            local partyIndex = tonumber(unit:sub(6))
            -- You can use the healModifier value for further calculations or updates
            --print(string.format("Healing modifier updated for party member %d: %s", partyIndex, healModifier))
        elseif unit:sub(1, 4) == "raid" then
            -- Update healing modifier for raid members
            local raidIndex = tonumber(unit:sub(5))
            -- You can use the healModifier value for further calculations or updates
            --print(string.format("Healing modifier updated for raid member %d: %s", raidIndex, healModifier))
        end
    end


-------------------------------------------------------------------------------------------------------
---- DirectHealDelayed
    -- For now just prints when someone who is healing you is getting his cast delayed, like taking damage.
        -- Possible usage is to UPDATE in how many seconds will you receive the heal.
            -- But that needs HealingStart to be using endTime to create the timer... :)
                -- This function works via this event: UNIT_SPELLCAST_DELAYED
-------------------------------------------------------------------------------------------------------

function addon:HealComm_DirectHealDelayed(event, healerName, healSize, endTime, ...)
    for i = 1, select('#', ...) do
        local targetName = select(i, ...)

        local timeRemaining = endTime - GetTime()
        --print(string.format("|cFFFF0000%s's|r healing on |cFF00FF00%s|r has been delayed. It will be completed in |cFFFFFF00%.2f|r seconds.", healerName, targetName, timeRemaining))

        -- Cancel the existing timer and create a new one in case of player
        if addon.playerStatusBar and targetName == UnitName("player") then
            --AceTimer:CancelTimer(addon.playerStatusBar.timerID, true)
            AceTimer:CancelTimer(addon.playerStatusBar.timerID, true)
            addon.playerStatusBar.timerID = AceTimer:ScheduleTimer(function() self:PrintAndHideStatusBar(addon.playerStatusBar) end, endTime - GetTime())
        end

        -- Cancel the existing timer and create a new one in case of target
        if addon.targetStatusBar and UnitIsUnit(targetName, "target") then
            AceTimer:CancelTimer(addon.targetStatusBar.timerID, true)
            addon.targetStatusBar.timerID = AceTimer:ScheduleTimer(function() self:PrintAndHideStatusBar(addon.targetStatusBar) end, endTime - GetTime())
        end

        -- Cancel the existing timer and create a new one in case of party members
        for partyIndex = 1, 5 do
            local partyUnitID = "party" .. partyIndex
            if addon["party" .. partyIndex .. "StatusBar"] and UnitIsUnit(targetName, partyUnitID) then
                AceTimer:CancelTimer(addon["party" .. partyIndex .. "StatusBar"].timerID, true)
                addon["party" .. partyIndex .. "StatusBar"].timerID = AceTimer:ScheduleTimer(function() self:PrintAndHideStatusBar(addon["party" .. partyIndex .. "StatusBar"]) end, endTime - GetTime())
            end
        end
    end
end


--------------------------------------------------------------------------------
---- HealingStop
    -- Fires when:
        -- Someone stopped his cast.
        -- Someone got interrupted.
--------------------------------------------------------------------------------

function addon:HealingStop(event, healerName, healSize, succeeded, ...)
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

            -- Print statements added here
            --print("Target Name: " .. targetName)
            --print("Healer Name: " .. healerName)
            --print("Healers Left: " .. tostring(healersLeft))

            -- If there are no healers left, hide the bar
            if not healersLeft then
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

                -- Repeat the logic for party status bars accordingly...
                for partyIndex = 1, 5 do
                    local partyStatusBar = self["party" .. partyIndex .. "StatusBar"]
                    if partyStatusBar then
                        partyStatusBar:Hide()
                        partyStatusBar:SetValue(0)
                        self["party" .. partyIndex .. "StatusBar"] = nil
                    end
                end
                if lastStatusBar then
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

