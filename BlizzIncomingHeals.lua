local HealComm = LibStub:GetLibrary("LibHealComm-3.0")
local addon = {}

local statusBars = {} -- Table to store all status bars


function addon:OnEnable()
    HealComm.RegisterCallback(self, "HealComm_DirectHealStart", "HealingStart")
    HealComm.RegisterCallback(self, "HealComm_DirectHealStop", "HealingStop")
    --HealComm.RegisterCallback(self, "HealComm_HealModifierUpdate", "HealModifierUpdate")
    --HealComm.RegisterCallback(self, "HealComm_DirectHealDelayed", "HealComm_DirectHealDelayed")
end

--------------------------------------------------------------------------------
--  Healing Start
--------------------------------------------------------------------------------

function addon:HealingStart(event, healerName, healSize, endTime, ...)
    for i = 1, select('#', ...) do
        local targetName = select(i, ...)
        -- Set the appropriate frameHealthBar based on the targetName
        local frameHealthBar
        if UnitIsUnit(targetName, "target") then
            frameHealthBar = TargetFrameHealthBar

        end
        if targetName == UnitName("player") then
            frameHealthBar = PlayerFrameHealthBar
        end

        -- If frameHealthBar is still not assigned, check party members
        if frameHealthBar then
            for partyIndex = 1, 5 do
                local partyUnitID = "party" .. partyIndex
                local partyFrame = _G["PartyMemberFrame" .. partyIndex]
                if partyFrame and UnitIsUnit(targetName, partyUnitID) then
                    frameHealthBar = partyFrame.healthbar
                    --break
                end
            end
        end



        if frameHealthBar then
            -- Check if the last status bar is for the same target
            if lastStatusBar and lastStatusBar.frameHealthBar == frameHealthBar then
                lastStatusBar:SetValue(curHealth + effectiveHealSize)
                return lastStatusBar
            end

            for _, statusBar in ipairs(statusBars) do
                if statusBar.targetName == targetName then
                    statusBar:SetValue(curHealth + effectiveHealSize)
                    return statusBar
                end
            end

            local maxHealth = UnitHealthMax(targetName)
            local curHealth = UnitHealth(targetName)
            local healthDeficit = maxHealth - curHealth
            local effectiveHealSize = math.min(healSize, healthDeficit)
            -- Calculate heal modifier
            local healModifier = HealComm:UnitHealModifierGet(targetName)
            effectiveHealSize = effectiveHealSize * healModifier

            -- Create a new status bar
            local width = effectiveHealSize / maxHealth * frameHealthBar:GetWidth()
            local healedHealth = curHealth + effectiveHealSize
            local statusBar = CreateFrame("StatusBar", nil, frameHealthBar)
            -- Set up the status bar properties
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
            table.insert(statusBars, statusBar) -- Add the new status bar to the table
        end
    end
end


--------------------------------------------------------------------------------
-- HealModifierUpdate
-- fires when someone gains buff/debuff that affects healing size.
--------------------------------------------------------------------------------

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


-------------------------------------------------------------------------------------------------------
-- DirectHealDelayed
    -- For now just prints when someone who is healing you is getting his cast delayed, like taking damage.
        -- Possible usage is to UPDATE in how many seconds will you receive the heal.
            -- But that needs HealingStart to be using endTime to create the timer... :)
                -- This function works via this event: UNIT_SPELLCAST_DELAYED
-------------------------------------------------------------------------------------------------------

function addon:HealComm_DirectHealDelayed(event, healerName, healSize, endTime, ...)
    for i = 1, select('#', ...) do
        local targetName = select(i, ...)
        -- Handle the delayed healing for each target as needed
        print(string.format("%s's healing on %s has been delayed. New completion time: %f", healerName, targetName, endTime))
        -- You can update UI elements or perform other actions based on the delayed healing information
    end
end


--------------------------------------------------------------------------------
-- HealingStop
    -- Fires when:
        -- Someone stopped his cast.
        -- Someone got interrupted.
--------------------------------------------------------------------------------

function addon:HealingStop(event, healerName, healSize, succeeded, ...)
    for i = #statusBars, 1, -1 do
        print(i)
        local statusBar = statusBars[i]
        statusBar:Hide()
        statusBar:SetValue(0)
        table.remove(statusBars, i) -- Remove the status bar from the table
    end
end

addon:OnEnable()

