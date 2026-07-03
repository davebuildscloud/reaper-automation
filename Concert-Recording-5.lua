-- Concert-Recording-5.lua
-- Set fader levels implementing 20/30/50 mix ratio
--   KM184  pair = 20% of mix → -7.96 dB per channel
--   KM185  pair = 30% of mix → -4.44 dB per channel
--   DPA4017 pair = 50% of mix →  0.00 dB per channel (reference)
-- Idempotent: exits if levels are already correct (within 0.1 dB)

local r = reaper
local function P(s) r.ShowConsoleMsg(s .. "\n") end
local function die(msg) r.ShowMessageBox(msg, "Concert Recording", 0); error(msg) end
local function db2lin(db) return 10 ^ (db / 20) end
local function lin2db(v)  return 20 * math.log(math.max(v, 1e-9)) / math.log(10) end

P("=== Concert-Recording-5: Mix Levels (20/30/50) ===")

local VOLS_DB = {
  ["KM184-L"]   = -7.96,
  ["KM184-R"]   = -7.96,
  ["KM185-L"]   = -4.44,
  ["KM185-R"]   = -4.44,
  ["DPA4017-L"] =  0.00,
  ["DPA4017-R"] =  0.00,
}

-- Check if already done
local needs_update = false
local found = 0
for t = 0, r.CountTracks(0) - 1 do
  local tr = r.GetTrack(0, t)
  local _, nm = r.GetTrackName(tr)
  if VOLS_DB[nm] then
    found = found + 1
    local actual_db = lin2db(r.GetMediaTrackInfo_Value(tr, "D_VOL"))
    if math.abs(actual_db - VOLS_DB[nm]) > 0.1 then needs_update = true end
  end
end

if found < 6 then
  die(found .. " of 6 channel tracks found. Run Concert-Recording-3 first.")
end

if not needs_update then
  P("Mix levels already correct. Nothing to do.")
  P("=== Done (already set) ===")
  return
end

-- Apply levels
for t = 0, r.CountTracks(0) - 1 do
  local tr = r.GetTrack(0, t)
  local _, nm = r.GetTrackName(tr)
  if VOLS_DB[nm] then
    r.SetMediaTrackInfo_Value(tr, "D_VOL", db2lin(VOLS_DB[nm]))
    local actual_db = lin2db(r.GetMediaTrackInfo_Value(tr, "D_VOL"))
    P(string.format("  %-12s  %.2f dB", nm, actual_db))
  end
end

r.Main_OnCommand(40026, 0)
P("Mix levels set. Project saved.")
P("=== Done ===")
