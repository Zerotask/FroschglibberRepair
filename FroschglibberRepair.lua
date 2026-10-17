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

local warningFrame
local previewWarning = false
local FULL_WIDTH = 400
local FULL_HEIGHT = 330
local MINIMIZED_WIDTH = 42
local MINIMIZED_HEIGHT = 32

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

local function RepairAtMerchant()
    if FroschglibberRepairDB.autoRepair and CanMerchantRepair() then
        local useGuildBank = FroschglibberRepairDB.repairSource == "guild" and IsInGuild()
        RepairAllItems(useGuildBank)
    end
end

local function SellGrayItems()
    if not FroschglibberRepairDB.autoSell then
        return
    end

    for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots do
            local item = C_Container.GetContainerItemInfo(bag, slot)
            if item and item.hyperlink then
                local _, _, quality = C_Item.GetItemInfo(item.hyperlink)
                if quality == Enum.ItemQuality.Poor then
                    C_Container.UseContainerItem(bag, slot)
                end
            end
        end
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

    local repairSourceSetting = Settings.RegisterAddOnSetting(
        category, ADDON_NAME .. "_RepairSource", "repairSource",
        FroschglibberRepairDB, Settings.VarType.String,
        "Reparaturkosten bezahlen mit", "guild"
    )
    local function repairSourceOptions()
        return {
            {
                controlType = Settings.ControlType.Radio,
                label = "Gildenbank bevorzugen",
                text = "Gildenbank bevorzugen",
                value = "guild",
            },
            {
                controlType = Settings.ControlType.Radio,
                label = "Eigene Tasche",
                text = "Eigene Tasche",
                value = "personal",
            },
        }
    end
    Settings.CreateDropdown(
        category,
        repairSourceSetting,
        repairSourceOptions,
        "Wählt die bevorzugte Quelle für automatische Reparaturkosten."
    )

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
    elseif command == "reset" then
        FroschglibberRepairDB.threshold = DEFAULT_THRESHOLD
        FroschglibberRepairDB.minimized = false
        if warningFrame then
            SetMinimized(false)
        end
        UpdateWarning()
        print("|cff70d070FroschglibberRepair: Schwelle auf 50% gesetzt und Frosch eingeblendet.|r")
    else
        print("|cff70d070FroschglibberRepair Befehle:|r /frosch test, /frosch hide, /frosch reset")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
events:RegisterEvent("UNIT_INVENTORY_CHANGED")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        warningFrame = CreateWarningFrame()
        local settingsOK, settingsError = pcall(CreateSettings)
        if not settingsOK then
            print("|cffff4040FroschglibberRepair Einstellungen konnten nicht geladen werden:|r " .. tostring(settingsError))
        end
        C_Timer.After(1, UpdateWarning)
    elseif event == "MERCHANT_SHOW" then
        RepairAtMerchant()
        SellGrayItems()
    elseif event == "UNIT_INVENTORY_CHANGED" then
        if unit == "player" then
            UpdateWarning()
        end
    else
        UpdateWarning()
    end
end)
