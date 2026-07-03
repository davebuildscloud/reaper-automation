-- Concert-Recording-6.lua
-- Add ReaEQ to master track and open it for manual configuration
-- Click OK in the dialog when done — settings are saved as part of the project
-- Idempotent: if ReaEQ is already on master, asks whether to re-open for editing

local r = reaper
local function P(s) r.ShowConsoleMsg(s .. "\n") end
local function die(msg) r.ShowMessageBox(msg, "Concert Recording", 0); error(msg) end

local function pause(msg)
  local tmp = "/tmp/concert_recording_6.scpt"
  local f = io.open(tmp, "w")
  if f then
    f:write('display dialog "' .. msg:gsub('"', '\\"') .. '" buttons {"OK"} default button "OK"\n')
    f:close()
    os.execute("osascript " .. tmp)
  else
    r.ShowMessageBox(msg, "Concert Recording — EQ", 0)
  end
end

local function get_or_add_fx(track, name)
  for i = 0, r.TrackFX_GetCount(track) - 1 do
    local _, nm = r.TrackFX_GetFXName(track, i, "")
    if nm:lower():find(name:lower(), 1, true) then return i, false end
  end
  local idx = r.TrackFX_AddByName(track, name, false, -1)
  if idx < 0 then die("Could not add FX: " .. name) end
  return idx, true
end

P("=== Concert-Recording-6: Master EQ ===")

local master = r.GetMasterTrack(0)

-- Check if EQ already present
local eq_idx = -1
for i = 0, r.TrackFX_GetCount(master) - 1 do
  local _, nm = r.TrackFX_GetFXName(master, i, "")
  if nm:lower():find("reaeq", 1, true) then eq_idx = i; break end
end

local PRESET_NAME = "concert-recording"

if eq_idx >= 0 then
  P("ReaEQ already on master at FX index " .. eq_idx .. ".")
else
  eq_idx = r.TrackFX_AddByName(master, "ReaEQ (Cockos)", false, -1)
  if eq_idx < 0 then die("Could not add ReaEQ (Cockos) to master track.") end
  P("ReaEQ added to master at FX index " .. eq_idx .. ".")
end

-- Apply saved preset
local preset_ok = r.TrackFX_SetPreset(master, eq_idx, PRESET_NAME)
if preset_ok then
  P("Preset applied: \"" .. PRESET_NAME .. "\"")
  r.Main_OnCommand(40026, 0)
  P("Project saved.")
  P("=== Done ===")
else
  -- Preset not found — fall back to manual
  P("WARNING: Preset \"" .. PRESET_NAME .. "\" not found.")
  r.Main_OnCommand(40026, 0)
  P("Project saved.")
  P("")
  P("ACTION REQUIRED:")
  P("  1. View > Master Track to show the master")
  P("  2. Click FX on the Master track")
  P("  3. Configure ReaEQ, then save preset as \"" .. PRESET_NAME .. "\"")
  P("  4. Run Concert-Recording-7 to continue")
  pause(
    "EQ preset \"" .. PRESET_NAME .. "\" was not found.\n\n" ..
    "Please:\n" ..
    "  1. View → Master Track\n" ..
    "  2. Click FX on the Master track\n" ..
    "  3. Configure ReaEQ\n" ..
    "  4. Save preset as \"" .. PRESET_NAME .. "\"\n\n" ..
    "Then run Concert-Recording-6 again."
  )
  P("=== Done (preset missing — configure manually) ===")
end
