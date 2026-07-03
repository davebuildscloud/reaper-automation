-- Concert-Recording-4.lua
-- Set pan values on each channel track
-- KM184:    ±1.00 (hard L/R — widest spread)
-- KM185:    ±0.50 (mid)
-- DPA4017:  ±0.25 (narrow centre)
-- Idempotent: exits if pans are already correct

local r = reaper
local function P(s) r.ShowConsoleMsg(s .. "\n") end
local function die(msg) r.ShowMessageBox(msg, "Concert Recording", 0); error(msg) end

P("=== Concert-Recording-4: Pan ===")

local PANS = {
  ["KM184-L"]   = -1.00,
  ["KM184-R"]   =  1.00,
  ["KM185-L"]   = -0.50,
  ["KM185-R"]   =  0.50,
  ["DPA4017-L"] = -0.25,
  ["DPA4017-R"] =  0.25,
}

-- Check if already done
local needs_update = false
local found = 0
for t = 0, r.CountTracks(0) - 1 do
  local tr = r.GetTrack(0, t)
  local _, nm = r.GetTrackName(tr)
  if PANS[nm] then
    found = found + 1
    local actual = r.GetMediaTrackInfo_Value(tr, "D_PAN")
    if math.abs(actual - PANS[nm]) > 0.01 then needs_update = true end
  end
end

if found < 6 then
  die(found .. " of 6 channel tracks found. Run Concert-Recording-3 first.")
end

if not needs_update then
  P("Pan values already correct. Nothing to do.")
  P("=== Done (already set) ===")
  return
end

-- Apply pans
for t = 0, r.CountTracks(0) - 1 do
  local tr = r.GetTrack(0, t)
  local _, nm = r.GetTrackName(tr)
  if PANS[nm] then
    r.SetMediaTrackInfo_Value(tr, "D_PAN", PANS[nm])
    local actual = r.GetMediaTrackInfo_Value(tr, "D_PAN")
    P(string.format("  %-12s  pan = %+.2f", nm, actual))
  end
end

r.Main_OnCommand(40026, 0)
P("Pan values set. Project saved.")
P("=== Done ===")
