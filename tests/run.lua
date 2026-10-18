-- Behaviour test for FroschglibberRepair.
--
-- It loads FroschglibberRepair.lua against a minimal stub of the WoW API and
-- the Settings/C_Timer subsystems, then simulates login, durability updates,
-- ready checks and deaths to verify the addon's behaviour (including that the
-- small frog popups never overlap the big repair warning).
--
-- Usage:
--   lua tests/run.lua [path/to/FroschglibberRepair.lua]
--
-- Exits with a non-zero status when a check fails.

local unpack = table.unpack or unpack
local loadChunk = loadstring or load

local ADDON_PATH = arg and arg[1] or "FroschglibberRepair.lua"
local ADDON_NAME = "FroschglibberRepair"

local function say(...)
  io.write(...)
  io.write("\n")
end

---------------------------------------------------------------- frames
local allFrames = {}
local function GetParentRect(parent)
  if parent == nil or parent == _G.UIParent then
    return 0, 0, 1024, 768 -- left, bottom, right, top
  end
  local l, b, r, t = parent:GetLeft(), parent:GetBottom(), parent:GetRight(), parent:GetTop()
  return l or 0, b or 0, r or 1024, t or 768
end

local frameMT = {}
frameMT.__index = frameMT

function frameMT:SetSize(w, h) self.w, self.h = w, h end
function frameMT:GetSize() return self.w or 0, self.h or 0 end
function frameMT:SetWidth(w) self.w = w end
function frameMT:SetHeight(h) self.h = h end

function frameMT:SetPoint(point, relto, relpoint, x, y)
  if type(relto) ~= "table" then -- SetPoint("CENTER", 0, -5) -> relative to parent
    x, y, relto, relpoint = relpoint, x, self.parent, relto
    if relpoint == nil then relpoint = point end
  end
  self.p = { point or "CENTER", relto, relpoint or point, x or 0, y or 0 }
end

function frameMT:GetPoint()
  local p = self.p
  if not p then return "CENTER", self.parent, "CENTER", 0, 0 end
  return p[1], p[2], p[3], p[4], p[5]
end

function frameMT:ClearAllPoints() self.p = nil end
function frameMT:SetAllPoints(relto) self.allPoints = relto or self.parent end

local function rectOf(f)
  local w, h = f:GetSize()
  local p = f.p or { "CENTER", f.parent, "CENTER", 0, 0 }
  local point, _, _, x, y = p[1], p[2], p[3], p[4], p[5]
  local pl, pb, pr, pt = GetParentRect(p[2])
  local cx, cy = (pl + pr) / 2, (pb + pt) / 2
  local left, bottom
  if point == "TOP" then
    left, bottom = cx + x - w / 2, pt + y - h
  elseif point == "BOTTOM" then
    left, bottom = cx + x - w / 2, pb + y
  elseif point == "LEFT" then
    left, bottom = pl + x, cy + y - h / 2
  elseif point == "RIGHT" then
    left, bottom = pr + x - w, cy + y - h / 2
  elseif point == "TOPLEFT" then
    left, bottom = pl + x, pt + y - h
  elseif point == "TOPRIGHT" then
    left, bottom = pr + x - w, pt + y - h
  elseif point == "BOTTOMLEFT" then
    left, bottom = pl + x, pb + y
  elseif point == "BOTTOMRIGHT" then
    left, bottom = pr + x - w, pb + y
  else -- CENTER
    left, bottom = cx + x - w / 2, cy + y - h / 2
  end
  return left, bottom, left + w, bottom + h
end

function frameMT:GetLeft()   return rectOf(self) end
function frameMT:GetBottom() local _, b = rectOf(self); return b end
function frameMT:GetRight()  local _, _, r = rectOf(self); return r end
function frameMT:GetTop()    local _, _, _, t = rectOf(self); return t end

function frameMT:SetFrameStrata(s) self.strata = s end
function frameMT:SetClampedToScreen() end
function frameMT:SetMovable() self.movable = true end
function frameMT:EnableMouse() end
function frameMT:RegisterForDrag() end
function frameMT:StartMoving() self.moving = true end
function frameMT:StopMovingOrSizing() self.moving = false end
function frameMT:SetScript(ev, fn) self.scripts[ev] = fn end
function frameMT:GetScript(ev) return self.scripts[ev] end
function frameMT:Show() self.shown = true end
function frameMT:Hide() self.shown = false end
function frameMT:IsShown() return self.shown end
function frameMT:SetShown(b) if b then self:Show() else self:Hide() end end
function frameMT:SetText(t) self.text = t end
function frameMT:GetText() return self.text end
function frameMT:SetJustifyH(h) self.halign = h end
function frameMT:SetShadowOffset() end
function frameMT:SetFontObject(o) self.fontobj = o end
function frameMT:SetTexture(p) self.texture = p end
function frameMT:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
function frameMT:GetRegions() return self.regions end
function frameMT:GetChildren() return self.children end
function frameMT:CreateTexture() return CreateRegion("Texture", self) end
function frameMT:CreateFontString(_, _, font)
  local fs = CreateRegion("FontString", self)
  fs.font = font
  return fs
end
function frameMT:RegisterEvent(ev) self.registered[ev] = true end

function CreateFrame(kind, name, parent, template)
  local f = setmetatable({
    kind = kind, name = name, parent = parent or _G.UIParent, template = template,
    shown = false, scripts = {}, registered = {}, regions = {}, children = {},
  }, frameMT)
  if name then _G[name] = f end
  allFrames[#allFrames + 1] = f
  return f
end

function CreateRegion(kind, parent)
  local r = setmetatable({
    kind = kind, parent = parent, shown = true, regions = {}, children = {},
    registered = {},
  }, frameMT)
  local regs = parent.regions
  regs[#regs + 1] = r
  return r
end

_G.UIParent = CreateFrame("Frame", "UIParent")

-- Fires an event on every frame that registered for it.
local function FireEvents(event, ...)
  for _, f in ipairs(allFrames) do
    if f.registered[event] and f.scripts.OnEvent then
      f.scripts.OnEvent(f, event, ...)
    end
  end
end

---------------------------------------------------------------- misc APIs
_G.printed = {}
function print(msg) printed[#printed + 1] = tostring(msg) end

local pendingTimers = {}
_G.C_Timer = {
  After = function(sec, fn)
    pendingTimers[#pendingTimers + 1] = { fn = fn }
    return { Cancel = function() end }
  end,
  NewTimer = function(sec, fn)
    local entry = { fn = fn, canceled = false }
    pendingTimers[#pendingTimers + 1] = entry
    return { Cancel = function() entry.canceled = true end }
  end,
}

-- Runs every timer scheduled so far (the addon's timing is not needed to
-- verify its behaviour, so we just flush them).
local function RunPendingTimers()
  local batch = pendingTimers
  pendingTimers = {}
  for _, t in ipairs(batch) do if not t.canceled then t.fn() end end
end

_G.Settings = { VarType = { Number = "num", Boolean = "bool", String = "str" } }
function Settings.RegisterVerticalLayoutCategory(name) return { name = name, controls = {} } end
function Settings.RegisterAddOnSetting(cat, name, key, db, vt, display, default)
  if db[key] == nil then db[key] = default end
  local s = { name = display, key = key, db = db, default = default, cb = nil }
  function s:SetValueChangedCallback(fn) self.cb = fn end
  cat.controls[#cat.controls + 1] = { type = "setting", s = s }
  return s
end
function Settings.CreateSliderOptions() return { SetLabelFormatter = function() end } end
function Settings.CreateSlider(cat, setting) cat.controls[#cat.controls + 1] = { type = "slider", s = setting } end
function Settings.CreateCheckbox(cat, setting, desc) cat.controls[#cat.controls + 1] = { type = "checkbox", s = setting, desc = desc } end
function Settings.CreateDropdown(cat, setting) cat.controls[#cat.controls + 1] = { type = "dropdown", s = setting } end
function Settings.RegisterAddOnCategory(cat) _G.registeredCategory = cat end
_G.MinimalSliderWithSteppersMixin = { Label = { Right = true } }

_G.DURABILITY = {}
function GetInventoryItemDurability(slot)
  local d = _G.DURABILITY[slot]
  if not d then return nil end
  return unpack(d)
end

function IsInGuild() return _G.IS_IN_GUILD or false end
function CanMerchantRepair() return true end
function GetRepairAllCost() return 1234, true end
function GetMoney() return 999999 end
function RepairAllItems(useGuild) _G.lastRepairGuild = useGuild end
-- Simulates a client where the coin-texture helper is unavailable, which is
-- what made the old code fall back to printing raw copper with a "Gold" suffix.
function GetCoinTextureString() return nil end
_G.CanGuildBankRepair = function() return false end
_G.GetGuildBankMoney = function() return 0 end
_G.Enum = { ItemQuality = { Poor = 0 } }
_G.BACKPACK_CONTAINER = 0
_G.NUM_BAG_SLOTS = 4
_G.C_Container = {
  GetContainerNumSlots = function() return 0 end,
  GetContainerItemInfo = function() return nil end,
  UseContainerItem = function() end,
}
_G.C_Item = { GetItemInfo = function() return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0 end }
_G.GameTooltip = { SetOwner = function() end, SetText = function() end, Show = function() end }
_G.GameTooltip_Hide = function() end
_G.SlashCmdList = {}

---------------------------------------------------------------- load addon
local fh = assert(io.open(ADDON_PATH, "r"), "cannot open " .. ADDON_PATH)
local src = fh:read("*a")
fh:close()

local chunk, err = loadChunk(src, ADDON_PATH)
if not chunk then
  say("LOAD FAILED: " .. tostring(err))
  os.exit(1)
end
chunk(ADDON_NAME)

---------------------------------------------------------------- test helpers
local failures = 0
local function check(cond, msg)
  if cond then
    say("  PASS  " .. msg)
  else
    failures = failures + 1
    say("  FAIL  " .. msg)
  end
end

local function overlap(aL, aB, aR, aT, bL, bB, bR, bT)
  return aL < bR and aR > bL and aB < bT and aT > bB
end

local function rectText(f)
  return string.format("[%d,%d -> %d,%d]", f:GetLeft(), f:GetBottom(), f:GetRight(), f:GetTop())
end

local function noOverlap(a, b)
  return not overlap(a:GetLeft(), a:GetBottom(), a:GetRight(), a:GetTop(),
    b:GetLeft(), b:GetBottom(), b:GetRight(), b:GetTop())
end

---------------------------------------------------------------- login
FireEvents("PLAYER_LOGIN")
RunPendingTimers() -- C_Timer.After(1, UpdateWarning)

local wf = _G[ADDON_NAME .. "Warning"]
local sf = _G[ADDON_NAME .. "SmallFrog"]
check(wf ~= nil, "big repair warning frame created on login")
check(sf ~= nil, "small frog frame created on login")
check(sf.strata == "TOOLTIP",
  "small frog uses TOOLTIP strata so it shows above the release-spirit dialog (got: " .. tostring(sf.strata) .. ")")
check(_G.registeredCategory ~= nil, "settings category registered")

for i = 1, 19 do _G.DURABILITY[i] = { 60, 100 } end
FireEvents("UNIT_INVENTORY_CHANGED", "player")
RunPendingTimers()
check(not wf:IsShown(), "big frog hidden when durability 60% > threshold 50%")

for i = 1, 19 do _G.DURABILITY[i] = { 30, 100 } end
FireEvents("UPDATE_INVENTORY_DURABILITY")
RunPendingTimers()
check(wf:IsShown(), "big frog shown when durability 30% < threshold 50%")

---------------------------------------------------------------- ready check popup
FireEvents("READY_CHECK")
check(sf:IsShown(), "small frog shown on READY_CHECK")
check(sf.value:GetText() == "|cffff404030%|r",
  "value shows red 30% with a valid 8-hex color (got: " .. tostring(sf.value:GetText()) .. ")")
check(sf.label:GetText() == "Haltbarkeit", "label reads Haltbarkeit")
check(sf.label:IsShown(), "label visible on ready check popup")
check(noOverlap(sf, wf), "ready check frog does NOT overlap the big frog (" .. rectText(sf) .. ")")

RunPendingTimers()
check(not sf:IsShown(), "ready check frog hidden after its timer")

---------------------------------------------------------------- death popup
FireEvents("PLAYER_DEAD")
check(sf:IsShown(), "small frog shown on PLAYER_DEAD")
check(sf.value:GetText() == "|cffffd100Haha du Noob|r",
  "death text exact (got: " .. tostring(sf.value:GetText()) .. ")")
check(not sf.label:IsShown(), "no Haltbarkeit label on death popup")
check(noOverlap(sf, wf), "death frog does NOT overlap the big frog (" .. rectText(sf) .. ")")

RunPendingTimers()
check(not sf:IsShown(), "death frog hidden after its timer")

---------------------------------------------------------------- settings toggles
_G.FroschglibberRepairDB.deathWarning = false
FireEvents("PLAYER_DEAD")
check(not sf:IsShown(), "death popup hidden when deathWarning=false")
_G.FroschglibberRepairDB.deathWarning = true

_G.FroschglibberRepairDB.readyCheckWarning = false
FireEvents("READY_CHECK")
check(not sf:IsShown(), "ready check popup hidden when readyCheckWarning=false")
_G.FroschglibberRepairDB.readyCheckWarning = true

---------------------------------------------------------------- slash commands
SlashCmdList.FROSCHGLIBBERREPAIR("rc")
check(sf:IsShown(), "/frosch rc previews the ready check popup")
RunPendingTimers()
SlashCmdList.FROSCHGLIBBERREPAIR("tod")
check(sf:IsShown(), "/frosch tod previews the death popup")
RunPendingTimers()

---------------------------------------------------------------- settings registered
local cat = _G.registeredCategory
local names = {}
for _, c in ipairs(cat.controls) do names[#names + 1] = c.s.name end
local joined = table.concat(names, ", ")
check(joined:find("Haltbarkeit beim Ready Check zeigen", 1, true) ~= nil, "ready check setting registered")
check(joined:find("Frosch bei Tod zeigen", 1, true) ~= nil, "death setting registered")

---------------------------------------------------------------- overlap when the big frog is moved to a corner
wf:ClearAllPoints()
wf:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 12, -12)
FireEvents("READY_CHECK")
check(noOverlap(sf, wf),
  "small frog avoids the big frog moved to a corner (" .. rectText(wf) .. " vs " .. rectText(sf) .. ")")
RunPendingTimers()

-------------------------------------------------- centered popup
for i = 1, 19 do _G.DURABILITY[i] = { 100, 100 } end
FireEvents("UPDATE_INVENTORY_DURABILITY")
RunPendingTimers()
check(not wf:IsShown(), "big frog hidden when durability is full")
FireEvents("PLAYER_DEAD")
local uL, uB, uR, uT = _G.UIParent:GetLeft(), _G.UIParent:GetBottom(), _G.UIParent:GetRight(), _G.UIParent:GetTop()
local sfx, sfy = (sf:GetLeft() + sf:GetRight()) / 2, (sf:GetBottom() + sf:GetTop()) / 2
check(math.abs(sfx - (uL + uR) / 2) < 1 and math.abs(sfy - (uB + uT) / 2) < 1,
  "death frog is centered on screen when the big frog is hidden (" .. rectText(sf) .. ")")
RunPendingTimers()

-------------------------------------------------- money formatting
-- GetRepairAllCost() returns 1234 copper == 12 Silber 34 Kupfer.
FireEvents("MERCHANT_SHOW")
local repairLine
for _, line in ipairs(printed) do
  if line:find("repariert", 1, true) then repairLine = line end
end
check(repairLine ~= nil, "repair message printed on MERCHANT_SHOW")
check(repairLine ~= nil and repairLine:find("12 Silber 34 Kupfer", 1, true) ~= nil,
  "repair cost (1234 copper) is shown as 12 Silber 34 Kupfer (got: " .. tostring(repairLine) .. ")")
check(repairLine ~= nil and repairLine:find("Gold", 1, true) == nil,
  "repair cost is not printed as raw copper with a Gold suffix")

---------------------------------------------------------------- addon chat output
say("")
for _, line in ipairs(printed) do say("addon print> " .. line) end

local allValid = true
for _, line in ipairs(printed) do
  if not line:find("|cff70d070", 1, true) then
    allValid = false
    say("UNEXPECTED COLOR: " .. line)
  end
end
check(allValid, "addon chat messages use the expected color code")

say("")
say(failures == 0 and "ALL CHECKS PASSED" or (failures .. " CHECK(S) FAILED"))
os.exit(failures == 0 and 0 or 1)
