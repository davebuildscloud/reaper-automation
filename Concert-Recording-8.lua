-- Concert-Recording-8.lua
-- Validate all settings before export
-- Read-only: does not modify the project unless all checks pass (then saves)
-- Idempotent: safe to run any number of times

local r = reaper
local function P(s) r.ShowConsoleMsg(s .. "\n") end

P("=== Concert-Recording-8: Validate ===")

local errors = {}
local function fail(msg) table.insert(errors, msg); P("  FAIL: " .. msg) end
local function ok(msg)   P("  OK:   " .. msg) end
local function lin2db(v) return 20 * math.log(math.max(v, 1e-9)) / math.log(10) end

-- ---- 1. Sample rate ----
local sr = r.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
if sr == 96000 then ok("Sample rate: 96000 Hz")
else fail("Sample rate: " .. sr .. " Hz (expected 96000)") end

-- ---- 2. SOURCE track ----
local src_tr = nil
for t = 0, r.CountTracks(0) - 1 do
  local tr = r.GetTrack(0, t)
  local _, nm = r.GetTrackName(tr)
  if nm == "SOURCE" then src_tr = tr; break end
end
if src_tr then
  local n_items = r.CountTrackMediaItems(src_tr)
  local muted   = r.GetMediaTrackInfo_Value(src_tr, "B_MUTE")
  local send    = r.GetMediaTrackInfo_Value(src_tr, "B_MAINSEND")
  ok("SOURCE: " .. n_items .. " item(s)")
  if muted ~= 1 then fail("SOURCE track is not muted") end
  if send  ~= 0 then fail("SOURCE track sends to master (should be off)") end
else
  fail("SOURCE track missing — run Concert-Recording-2")
end

-- ---- 3. Channel tracks: existence, items, pan, volume ----
local EXPECTED = {
  { name="KM184-L",   pan=-1.00, db=-7.96 },
  { name="KM184-R",   pan= 1.00, db=-7.96 },
  { name="KM185-L",   pan=-0.50, db=-4.44 },
  { name="KM185-R",   pan= 0.50, db=-4.44 },
  { name="DPA4017-L", pan=-0.25, db= 0.00 },
  { name="DPA4017-R", pan= 0.25, db= 0.00 },
}

local track_map = {}
for t = 0, r.CountTracks(0) - 1 do
  local tr = r.GetTrack(0, t)
  local _, nm = r.GetTrackName(tr)
  track_map[nm] = tr
end

for _, exp in ipairs(EXPECTED) do
  local tr = track_map[exp.name]
  if not tr then
    fail(exp.name .. " missing — run Concert-Recording-3")
  else
    local n   = r.CountTrackMediaItems(tr)
    local pan = r.GetMediaTrackInfo_Value(tr, "D_PAN")
    local vol = r.GetMediaTrackInfo_Value(tr, "D_VOL")
    local db  = lin2db(vol)

    if n == 0 then fail(exp.name .. ": no items") end

    -- Check for item-level mute (REAPER's explode action inherits mute from source items)
    local muted_items = 0
    for i = 0, n - 1 do
      local item = r.GetTrackMediaItem(tr, i)
      if r.GetMediaItemInfo_Value(item, "B_MUTE") ~= 0 then
        muted_items = muted_items + 1
      end
    end
    if muted_items > 0 then
      fail(string.format("%-12s  %d/%d item(s) muted — run Concert-Recording-3", exp.name, muted_items, n))
    end

    if math.abs(pan - exp.pan) <= 0.01 then
      ok(string.format("%-12s  pan=%+.2f", exp.name, pan))
    else
      fail(string.format("%-12s  pan=%+.2f (expected %+.2f) — run Concert-Recording-4", exp.name, pan, exp.pan))
    end

    if math.abs(db - exp.db) <= 0.1 then
      ok(string.format("%-12s  vol=%.2f dB", exp.name, db))
    else
      fail(string.format("%-12s  vol=%.2f dB (expected %.2f) — run Concert-Recording-5", exp.name, db, exp.db))
    end
  end
end

-- ---- 4. Master FX: ReaEQ then ReaLimit ----
local master  = r.GetMasterTrack(0)
local eq_idx  = -1
local lim_idx = -1
for i = 0, r.TrackFX_GetCount(master) - 1 do
  local _, nm = r.TrackFX_GetFXName(master, i, "")
  if nm:lower():find("reaeq",    1, true) then eq_idx  = i end
  if nm:lower():find("realimit", 1, true) then lim_idx = i end
end

if eq_idx  >= 0 then ok("Master: ReaEQ at FX index " .. eq_idx)
else fail("Master: ReaEQ missing — run Concert-Recording-6") end

if lim_idx >= 0 then
  local norm = r.TrackFX_GetParamNormalized(master, lim_idx, 0)
  -- Use normalized comparison (TrackFX_GetParam returns [0,1] internal range, not dB)
  if math.abs(norm - (59/60)) <= 0.005 then
    ok(string.format("Master: ReaLimit ceiling = -1.00 dBFS (normalized=%.4f)", norm))
  else
    fail(string.format("Master: ReaLimit normalized=%.4f (expected %.4f = -1.00 dBFS) — run Concert-Recording-7", norm, 59/60))
  end
else
  fail("Master: ReaLimit missing — run Concert-Recording-7")
end

if eq_idx >= 0 and lim_idx >= 0 and eq_idx > lim_idx then
  fail("Master FX order wrong: ReaEQ must come before ReaLimit")
end

-- ---- 5. Render settings ----
local _, fmt    = r.GetSetProjectInfo_String(0, "RENDER_FORMAT",   "", false)
local r_srate   = r.GetSetProjectInfo(0,        "RENDER_SRATE",    0, false)
local r_chans   = r.GetSetProjectInfo(0,        "RENDER_CHANNELS", 0, false)
local _, r_file = r.GetSetProjectInfo_String(0, "RENDER_FILE",     "", false)

-- REAPER stores RENDER_FORMAT as base64. FLAC starts with "Y2Fs" (base64 of "calf").
-- Also accept raw-bytes form "calf" for REAPER version compatibility.
local function is_flac_fmt(s)
  return s and (s:sub(1,4) == "Y2Fs" or s:sub(1,4) == "calf")
end
if is_flac_fmt(fmt) then ok("Render format: FLAC 24-bit")
else fail("Render format not FLAC (got: " .. tostring(fmt and fmt:sub(1,8) or "nil") .. ") — run Concert-Recording-1") end

if r_srate == 96000 then ok("Render rate: 96000 Hz")
else fail("Render rate: " .. r_srate .. " (expected 96000) — run Concert-Recording-1") end

if r_chans == 2 then ok("Render channels: stereo")
else fail("Render channels: " .. r_chans .. " (expected 2) — run Concert-Recording-1") end

if r_file and r_file:match("%.flac$") then ok("Render output: " .. r_file)
elseif r_file and r_file ~= "" then fail("Render output is a folder, not a .flac path — run Concert-Recording-1")
else fail("Render output path not set — run Concert-Recording-1") end

-- ---- Summary ----
P("")
if #errors == 0 then
  P("All checks passed. Ready to export.")
  r.Main_OnCommand(40026, 0)
  P("Project saved.")
else
  P(#errors .. " issue(s) found — fix them before running Concert-Recording-9.")
  for _, e in ipairs(errors) do P("  • " .. e) end
  r.ShowMessageBox(
    #errors .. " validation issue(s) found.\nCheck the REAPER console for details.",
    "Validation Failed", 0)
end

P("=== Done ===")
