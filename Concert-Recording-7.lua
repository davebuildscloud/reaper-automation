-- Concert-Recording-7.lua
-- Add ReaLimit to master track, ceiling -1 dBFS
-- This is the normalization step — prevents clipping without using
-- REAPER's render-time normalize (which has a FLAC corruption bug in v6.66)
-- Idempotent: exits if ReaLimit is already present at correct ceiling

local r = reaper
local function P(s) r.ShowConsoleMsg(s .. "\n") end
local function die(msg) r.ShowMessageBox(msg, "Concert Recording", 0); error(msg) end

P("=== Concert-Recording-7: Normalize (ReaLimit -1 dBFS) ===")

local master = r.GetMasterTrack(0)

-- Find existing ReaLimit if present
local lim_idx = -1
for i = 0, r.TrackFX_GetCount(master) - 1 do
  local _, nm = r.TrackFX_GetFXName(master, i, "")
  if nm:lower():find("realimit", 1, true) then lim_idx = i; break end
end

if lim_idx >= 0 then
  -- Verify ceiling is already -1 dBFS (check normalized value directly)
  local norm = r.TrackFX_GetParamNormalized(master, lim_idx, 0)
  if math.abs(norm - (59/60)) <= 0.005 then
    P(string.format("ReaLimit already at -1.00 dBFS (normalized=%.4f). Nothing to do.", norm))
    P("=== Done (already set) ===")
    return
  else
    P(string.format("ReaLimit present but normalized=%.4f — correcting to %.4f (-1.00 dBFS).", norm, 59/60))
  end
else
  -- Add ReaLimit after EQ (appends to end of FX chain)
  lim_idx = r.TrackFX_AddByName(master, "ReaLimit", false, -1)
  if lim_idx < 0 then die("Could not add ReaLimit to master track.") end
  P("ReaLimit added to master at FX index " .. lim_idx .. ".")
end

-- Set ceiling to -1 dBFS
-- Param 0 = ceiling, range [-60, 0] dB
-- Normalized: 59/60 ≈ 0.9833 maps to -1 dBFS
local TARGET_NORM = 59 / 60
r.TrackFX_SetParamNormalized(master, lim_idx, 0, TARGET_NORM)

-- Verify via normalized value (TrackFX_GetParam returns plugin's internal [0,1] range,
-- not the dB range, so don't use mn/mx for dB conversion)
local norm_rb = r.TrackFX_GetParamNormalized(master, lim_idx, 0)
P(string.format("ReaLimit ceiling: -1.00 dBFS (normalized=%.4f, target=%.4f)", norm_rb, TARGET_NORM))

if math.abs(norm_rb - TARGET_NORM) > 0.005 then
  die(string.format("ReaLimit normalized=%.4f, expected %.4f. Check plugin.", norm_rb, TARGET_NORM))
end

r.Main_OnCommand(40026, 0)
P("Project saved.")
P("=== Done ===")
