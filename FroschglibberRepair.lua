local ADDON_NAME = ...
local DEFAULT_THRESHOLD = 50
local MIN_THRESHOLD = 0
local MAX_THRESHOLD = 80

FroschglibberRepairDB = FroschglibberRepairDB or {}
if FroschglibberRepairDB.threshold == nil then
    FroschglibberRepairDB.threshold = DEFAULT_THRESHOLD
end
if FroschglibberRepairDB.autoRepair == nil then
    FroschglibberRepairDB.autoRepair = true
end
if FroschglibberRepairDB.autoSell == nil then
    FroschglibberRepairDB.autoSell = false
end
if FroschglibberRepairDB.repairSource == nil then
    FroschglibberRepairDB.repairSource = "guild"
end
if FroschglibberRepairDB.readyCheckWarning == nil then
    FroschglibberRepairDB.readyCheckWarning = true
end
if FroschglibberRepairDB.deathWarning == nil then
    FroschglibberRepairDB.deathWarning = true
end

local warningFrame
local smallFrogFrame
local smallFrogTimer
local previewWarning = false
local FULL_WIDTH = 400
local FULL_HEIGHT = 330
local MINIMIZED_WIDTH = 42
local MINIMIZED_HEIGHT = 32
local SMALL_FROG_SIZE = 110
local READY_CHECK_DURATION = 10
local DEATH_DURATION = 3

local function SaveLayout()
    local point, _, relativePoint, x, y = warningFrame:GetPoint()
    FroschglibberRepairDB.point = point
    FroschglibberRepairDB.relativePoint = relativePoint
    FroschglibberRepairDB.x = x
    FroschglibberRepairDB.y = y
    FroschglibberRepairDB.minimized = warningFrame.minimized
end

local function SetMinimized(minimized)
    warningFrame.minimized = minimized
    warningFrame:SetSize(
        minimized and MINIMIZED_WIDTH or FULL_WIDTH,
        minimized and MINIMIZED_HEIGHT or FULL_HEIGHT
    )
    warningFrame.artwork:SetShown(not minimized)
    warningFrame.message:SetShown(not minimized)
    warningFrame.button:SetText(minimized and "+" or "-")
    warningFrame.button:ClearAllPoints()
    warningFrame.button:SetPoint(
        "TOPRIGHT",
        warningFrame,
        "TOPRIGHT",
        minimized and 2 or -8,
        minimized and 2 or -8
    )
    SaveLayout()
end

local function CreateWarningFrame()
    local frame = _G[ADDON_NAME .. "Warning"]
    if frame then
        frame:Hide()
        for _, region in ipairs({ frame:GetRegions() }) do
            region:Hide()
        end
        for _, child in ipairs({ frame:GetChildren() }) do
            child:Hide()
        end
    else
        frame = CreateFrame("Frame", ADDON_NAME .. "Warning", UIParent)
    end
    warningFrame = frame
    frame:SetSize(FULL_WIDTH, FULL_HEIGHT)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveLayout()
    end)

    frame:SetPoint(
        FroschglibberRepairDB.point or "CENTER",
        UIParent,
        FroschglibberRepairDB.relativePoint or "CENTER",
        FroschglibberRepairDB.x or 0,
        FroschglibberRepairDB.y or 20
    )

    local artwork = frame:CreateTexture(nil, "ARTWORK")
    artwork:SetTexture("Interface\\AddOns\\FroschglibberRepair\\frog.tga")
    artwork:SetSize(300, 300)
    artwork:SetPoint("CENTER", 0, -5)
    frame.artwork = artwork

    local message = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    message:SetPoint("BOTTOM", frame, "TOP", 0, 12)
    message:SetWidth(760)
    message:SetJustifyH("CENTER")
    message:SetText("|cffff4040Geh endlich reparieren du Kacknoob|r")
    frame.message = message

    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(34, 28)
    button:SetText("-")
    button:SetScript("OnClick", function()
        SetMinimized(not frame.minimized)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(frame.minimized and "Frosch anzeigen" or "Frosch minimieren")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    frame.button = button

    SetMinimized(FroschglibberRepairDB.minimized == true)
    frame:Hide()
    return frame
end

local function HasItemBelowThreshold()
    local threshold = FroschglibberRepairDB.threshold / 100
    for slot = 1, 19 do
        local current, maximum = GetInventoryItemDurability(slot)
        if current and maximum and maximum > 0 and current / maximum < threshold then
            return true
        end
    end
    return false
end

local function UpdateWarning()
    if not warningFrame then
        warningFrame = CreateWarningFrame()
    end
    warningFrame:SetShown(previewWarning or HasItemBelowThreshold())
end

-- Returns the durability of the most worn equipped item as a whole
-- percentage, or nil when no equipped item reports a durability.
local function GetLowestDurabilityPercent()
    local lowest
    for slot = 1, 19 do
        local current, maximum = GetInventoryItemDurability(slot)
        if current and maximum and maximum > 0 then
            local ratio = current / maximum
            if lowest == nil or ratio < lowest then
                lowest = ratio
            end
        end
    end
    if lowest == nil then
        return nil
    end
    return math.floor(lowest * 100 + 0.5)
end

local function CreateSmallFrogFrame()
    local frame = CreateFrame("Frame", ADDON_NAME .. "SmallFrog", UIParent)
    frame:SetSize(SMALL_FROG_SIZE, SMALL_FROG_SIZE)
    -- TOOLTIP is the highest frame strata, so the popup stays above the
    -- Blizzard "Freilassen" (release spirit) dialog that shows up on death.
    frame:SetFrameStrata("TOOLTIP")
    frame:SetClampedToScreen(true)

    local backdrop = frame:CreateTexture(nil, "BACKGROUND")
    backdrop:SetAllPoints()
    backdrop:SetColorTexture(0, 0, 0, 0.45)

    local artwork = frame:CreateTexture(nil, "ARTWORK")
    artwork:SetTexture("Interface\\AddOns\\FroschglibberRepair\\frog.tga")
    artwork:SetAllPoints()
    frame.artwork = artwork

    -- The text is drawn above the frog image instead of on top of it, so the
    -- frog stays visible and neither popup covers its face.
    local value = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    value:SetPoint("BOTTOM", frame, "TOP", 0, 2)
    value:SetJustifyH("CENTER")
    value:SetWidth(SMALL_FROG_SIZE + 80)
    value:SetShadowOffset(2, -2)
    frame.value = value

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOM", value, "TOP", 0, 2)
    label:SetShadowOffset(1, -1)
    frame.label = label

    frame:Hide()
    return frame
end

-- Places the small frog in the middle of the screen, moving it out of the way
-- only when the big repair warning is shown and would otherwise be covered.
local function PositionSmallFrogFrame(frame)
    local offset = 130
    local candidates = {
        { "CENTER", "CENTER", 0, 0 },
        { "TOP", "TOP", 0, -offset },
        { "BOTTOM", "BOTTOM", 0, offset },
        { "LEFT", "LEFT", offset, 0 },
        { "RIGHT", "RIGHT", -offset, 0 },
        { "TOPLEFT", "TOPLEFT", 12, -12 },
        { "TOPRIGHT", "TOPRIGHT", -12, -12 },
        { "BOTTOMLEFT", "BOTTOMLEFT", 12, 12 },
        { "BOTTOMRIGHT", "BOTTOMRIGHT", -12, 12 },
    }

    local wLeft, wBottom, wRight, wTop
    if warningFrame and warningFrame:IsShown() then
        wLeft, wBottom = warningFrame:GetLeft(), warningFrame:GetBottom()
        wRight, wTop = warningFrame:GetRight(), warningFrame:GetTop()
    end

    for _, anchor in ipairs(candidates) do
        frame:ClearAllPoints()
        frame:SetPoint(anchor[1], UIParent, anchor[2], anchor[3], anchor[4])
        if not wLeft then
            return
        end
        local left, bottom = frame:GetLeft(), frame:GetBottom()
        local right, top = frame:GetRight(), frame:GetTop()
        if left and not (left < wRight and right > wLeft
            and bottom < wTop and top > wBottom) then
            return
        end
    end
end

-- Shows the small frog with the given text for a limited time.
local function ShowSmallFrog(text, duration, labelText, largeFont)
    if not smallFrogFrame then
        smallFrogFrame = CreateSmallFrogFrame()
    end

    smallFrogFrame.label:SetShown(labelText ~= nil)
    if labelText then
        smallFrogFrame.label:SetText(labelText)
    end
    smallFrogFrame.value:SetFontObject(largeFont and GameFontNormalLarge or GameFontNormal)
    smallFrogFrame.value:SetText(text)

    PositionSmallFrogFrame(smallFrogFrame)
    smallFrogFrame:Show()

    if smallFrogTimer then
        smallFrogTimer:Cancel()
    end
    smallFrogTimer = C_Timer.NewTimer(duration, function()
        smallFrogTimer = nil
        if smallFrogFrame then
            smallFrogFrame:Hide()
        end
    end)
end

-- Shows the small frog with the current durability when a ready check starts.
local function ShowReadyCheckWarning()
    local percent = GetLowestDurabilityPercent()
    local color = "70d070"
    if percent == nil then
        percent = 100
    elseif percent < FroschglibberRepairDB.threshold then
        color = "ff4040"
    end
    ShowSmallFrog(("|cff%s%d%%|r"):format(color, percent),
        READY_CHECK_DURATION, "Haltbarkeit", true)
end

-- Shows the small frog laughing at the player after they died.
local function ShowDeathWarning()
    ShowSmallFrog("|cffffd100Haha du Noob|r", DEATH_DURATION, nil, false)
end

-- Formats an amount of copper as a readable coin string ("2 Gold 45 Silber 34
-- Kupfer"). GetRepairAllCost() and item sell prices are in copper, so they must
-- not be printed with a fixed "Gold" suffix.
local function FormatMoney(copper)
    copper = math.max(0, math.floor(copper or 0))
    if GetCoinTextureString then
        local ok, text = pcall(GetCoinTextureString, copper)
        if ok and type(text) == "string" and text ~= "" then
            return text
        end
    end

    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper % 10000 / 100)
    local remainder = copper % 100
    local parts = {}
    if gold > 0 then
        parts[#parts + 1] = gold .. " Gold"
    end
    if silver > 0 then
        parts[#parts + 1] = silver .. " Silber"
    end
    if remainder > 0 or #parts == 0 then
        parts[#parts + 1] = remainder .. " Kupfer"
    end
    return table.concat(parts, " ")
end

local function RepairAtMerchant()
    if not (FroschglibberRepairDB.autoRepair and CanMerchantRepair()) then
        return
    end

    local cost, canRepair = GetRepairAllCost()
    if not canRepair or cost <= 0 then
        -- Nothing to repair.
        return
    end

    local useGuildBank = (FroschglibberRepairDB.repairSource == "guild"
        and IsInGuild()
        and CanGuildBankRepair()
        and GetGuildBankMoney() >= cost) and true or false

    if not useGuildBank and GetMoney() < cost then
        -- Not enough personal money; the default Blizzard error will show.
        return
    end

    -- Falls back to personal funds when the guild bank cannot be used
    -- (no guild, no permission, or not enough money in the guild bank).
    RepairAllItems(useGuildBank)

    local costText = FormatMoney(cost)
    local sourceText = useGuildBank and " (aus der Gildenbank)" or ""
    print("|cff70d070Froschglibber hat deine Ausrüstung für "
        .. costText .. " repariert." .. sourceText .. "|r")
end

local function SellGrayItems()
    if not FroschglibberRepairDB.autoSell then
        return
    end

    local totalEarned = 0
    local soldCount = 0

    for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots do
            local item = C_Container.GetContainerItemInfo(bag, slot)
            -- quality comes straight from the container, sellPrice still
            -- needs GetItemInfo (nil before the item data is cached).
            if item and item.hyperlink
                and item.quality == Enum.ItemQuality.Poor then
                local _, _, _, _, _, _, _, _, _, _, sellPrice =
                    C_Item.GetItemInfo(item.hyperlink)
                C_Container.UseContainerItem(bag, slot)
                soldCount = soldCount + 1
                if not item.hasNoValue then
                    totalEarned = totalEarned
                        + (sellPrice or 0) * (item.stackCount or 1)
                end
            end
        end
    end

    if soldCount > 0 then
        local earnedText = FormatMoney(totalEarned)
        print("|cff70d070Froschglibber hat deinen Schrott für "
            .. earnedText .. " abgekauft.|r")
    end
end

local function CreateSettings()
    local category = Settings.RegisterVerticalLayoutCategory("FroschglibberRepair")
    local setting = Settings.RegisterAddOnSetting(
        category, ADDON_NAME .. "_Threshold", "threshold",
        FroschglibberRepairDB, Settings.VarType.Number,
        "Reparatur-Schwelle", DEFAULT_THRESHOLD
    )
    setting:SetValueChangedCallback(UpdateWarning)

    local options = Settings.CreateSliderOptions(MIN_THRESHOLD, MAX_THRESHOLD, 1)
    if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
            return string.format("%d%%", value)
        end)
    end
    Settings.CreateSlider(category, setting, options,
        "Bei welchem Haltbarkeitswert der Reparaturhinweis angezeigt wird.")

    local readyCheckSetting = Settings.RegisterAddOnSetting(
        category, ADDON_NAME .. "_ReadyCheckWarning", "readyCheckWarning",
        FroschglibberRepairDB, Settings.VarType.Boolean,
        "Haltbarkeit beim Ready Check zeigen", true
    )
    Settings.CreateCheckbox(category, readyCheckSetting,
        "Zeigt 10 Sekunden lang einen kleinen Frosch mit deiner aktuellen Haltbarkeit, wenn ein Ready Check gestartet wird.")

    local deathSetting = Settings.RegisterAddOnSetting(
        category, ADDON_NAME .. "_DeathWarning", "deathWarning",
        FroschglibberRepairDB, Settings.VarType.Boolean,
        "Frosch bei Tod zeigen", true
    )
    Settings.CreateCheckbox(category, deathSetting,
        "Zeigt 3 Sekunden lang einen kleinen Frosch, der dich auslacht, wenn du stirbst.")

    local autoRepairSetting = Settings.RegisterAddOnSetting(
        category, ADDON_NAME .. "_AutoRepair", "autoRepair",
        FroschglibberRepairDB, Settings.VarType.Boolean,
        "Automatisch reparieren", true
    )
    Settings.CreateCheckbox(category, autoRepairSetting,
        "Repariert beim Öffnen eines reparaturfähigen Händlers automatisch.")

    local autoSellSetting = Settings.RegisterAddOnSetting(
        category, ADDON_NAME .. "_AutoSell", "autoSell",
        FroschglibberRepairDB, Settings.VarType.Boolean,
        "Automatisch verkaufen", false
    )
    Settings.CreateCheckbox(category, autoSellSetting,
        "Verkauft beim Öffnen eines Händlers automatisch graue Gegenstände aus deinen Taschen.")

    -- Without a guild the guild option is unavailable, so reset to personal
    -- before the setting is registered (otherwise the saved value would point
    -- to an option that no longer exists).
    if not IsInGuild() and FroschglibberRepairDB.repairSource == "guild" then
        FroschglibberRepairDB.repairSource = "personal"
    end

    local repairSourceSetting = Settings.RegisterAddOnSetting(
        category, ADDON_NAME .. "_RepairSource", "repairSource",
        FroschglibberRepairDB, Settings.VarType.String,
        "Reparaturkosten bezahlen mit", FroschglibberRepairDB.repairSource
    )
    local function repairSourceOptions()
        local options = {
            {
                controlType = Settings.ControlType.Radio,
                label = "Eigene Tasche",
                text = "Eigene Tasche",
                value = "personal",
            },
        }
        if IsInGuild() then
            table.insert(options, 1, {
                controlType = Settings.ControlType.Radio,
                label = "Gildenbank bevorzugen",
                text = "Gildenbank bevorzugen",
                value = "guild",
            })
        end
        return options
    end
    Settings.CreateDropdown(
        category,
        repairSourceSetting,
        repairSourceOptions,
        "Wählt die bevorzugte Quelle für automatische Reparaturkosten."
    )
    if not IsInGuild() and FroschglibberRepairDB.repairSource == "guild" then
        FroschglibberRepairDB.repairSource = "personal"
    end

    Settings.RegisterAddOnCategory(category)
end

SLASH_FROSCHGLIBBERREPAIR1 = "/frosch"
SLASH_FROSCHGLIBBERREPAIR2 = "/fgr"
SlashCmdList.FROSCHGLIBBERREPAIR = function(message)
    local command = string.lower(message or "")
    if command == "test" or command == "show" then
        previewWarning = true
        UpdateWarning()
        print("|cff70d070FroschglibberRepair: Vorschau eingeblendet.|r")
    elseif command == "hide" then
        previewWarning = false
        UpdateWarning()
        print("|cff70d070FroschglibberRepair: Vorschau ausgeblendet.|r")
    elseif command == "rc" or command == "readycheck" then
        ShowReadyCheckWarning()
        print("|cff70d070FroschglibberRepair: Ready-Check-Haltbarkeit eingeblendet.|r")
    elseif command == "death" or command == "tod" then
        ShowDeathWarning()
        print("|cff70d070FroschglibberRepair: Todes-Frosch eingeblendet.|r")
    elseif command == "reset" then
        FroschglibberRepairDB.threshold = DEFAULT_THRESHOLD
        FroschglibberRepairDB.minimized = false
        if warningFrame then
            SetMinimized(false)
        end
        UpdateWarning()
        print("|cff70d070FroschglibberRepair: Schwelle auf 50% gesetzt und Frosch eingeblendet.|r")
    else
        print("|cff70d070FroschglibberRepair Befehle:|r /frosch test, /frosch hide, /frosch rc, /frosch tod, /frosch reset")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("READY_CHECK")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
events:RegisterEvent("UNIT_INVENTORY_CHANGED")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        warningFrame = CreateWarningFrame()
        smallFrogFrame = CreateSmallFrogFrame()
        local settingsOK, settingsError = pcall(CreateSettings)
        if not settingsOK then
            print("|cffff4040FroschglibberRepair Einstellungen konnten nicht geladen werden:|r " .. tostring(settingsError))
        end
        C_Timer.After(1, UpdateWarning)
    elseif event == "MERCHANT_SHOW" then
        RepairAtMerchant()
        SellGrayItems()
    elseif event == "READY_CHECK" then
        if FroschglibberRepairDB.readyCheckWarning then
            ShowReadyCheckWarning()
        end
    elseif event == "PLAYER_DEAD" then
        if FroschglibberRepairDB.deathWarning then
            ShowDeathWarning()
        end
    elseif event == "UNIT_INVENTORY_CHANGED" then
        if unit == "player" then
            UpdateWarning()
        end
    else
        UpdateWarning()
    end
end)
