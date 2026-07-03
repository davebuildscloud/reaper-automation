-- Concert-Recording-1.lua
-- Set project sample rate (96kHz) and FLAC render settings
-- Output folder = same folder as the source WAV files
-- Idempotent: detects correct settings already in place

local r = reaper
local function P(s) r.ShowConsoleMsg(s .. "\n") end
local function die(msg) r.ShowMessageBox(msg, "Concert Recording", 0); error(msg) end

P("=== Concert-Recording-1: Export Options ===")

-- Find any media item to discover the WAV source folder
local wav_folder = nil
for t = 0, r.CountTracks(0) - 1 do
  local tr = r.GetTrack(0, t)
  for i = 0, r.CountTrackMediaItems(tr) - 1 do
    local item = r.GetTrackMediaItem(tr, i)
    local take = r.GetActiveTake(item)
    if take then
      local src  = r.GetMediaItemTake_Source(take)
      local path = r.GetMediaSourceFileName(src, "")
      if path and path ~= "" then
        wav_folder = path:match("^(.+)/[^/]+$")
        break
      end
    end
  end
  if wav_folder then break end
end

if not wav_folder then
  die("No media files found in project.\nLoad your WAV files first, then run this script.")
end
P("WAV source folder: " .. wav_folder)

-- Derive show name from the WAV folder (e.g. "20260626-ChickenWireEmpire")
-- Used to name the FLAC output file explicitly so it's always correct
-- regardless of what the REAPER project file is called.
local show_name = wav_folder:match("([^/]+)$")
P("Show name: " .. show_name)

-- Check / set project sample rate
local sr = r.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
if sr == 96000 then
  P("Sample rate: 96000 Hz (already set)")
else
  r.GetSetProjectInfo(0, "PROJECT_SRATE",        96000, true)
  r.GetSetProjectInfo(0, "PROJECT_SRATEUSEPROJ", 1,     true)
  local new_sr = r.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
  P("Sample rate: set to " .. new_sr .. " Hz")
end

-- Check / set FLAC render settings
-- REAPER stores RENDER_FORMAT as base64.
-- "calf" + 24-bit + compression-5 blob base64-encodes to "Y2FsZhgAAAAFAAAA"
-- (raw bytes: 63 61 6C 66 18 00 00 00 05 00 00 00)
local FLAC_B64   = "Y2FsZhgAAAAFAAAA"
local _, cur_fmt = r.GetSetProjectInfo_String(0, "RENDER_FORMAT", "", false)
local cur_srate  = r.GetSetProjectInfo(0, "RENDER_SRATE",    0, false)
local cur_chans  = r.GetSetProjectInfo(0, "RENDER_CHANNELS", 0, false)
local _, cur_out = r.GetSetProjectInfo_String(0, "RENDER_FILE",   "", false)

-- Accept either base64 form ("Y2Fs") or raw-bytes form ("calf") in case of REAPER version differences
local function is_flac_fmt(s)
  return s and (s:sub(1,4) == "Y2Fs" or s:sub(1,4) == "calf")
end

local render_file = wav_folder .. "/" .. show_name .. ".flac"

local already_set = is_flac_fmt(cur_fmt)
                 and cur_srate == 96000
                 and cur_chans == 2
                 and cur_out   == render_file

if already_set then
  P("Render settings already correct:")
  P("  Format:  FLAC 24-bit")
  P("  Rate:    96000 Hz")
  P("  Output:  " .. cur_out)
else
  r.GetSetProjectInfo_String(0, "RENDER_FORMAT",   FLAC_B64,     true)
  r.GetSetProjectInfo(0,        "RENDER_SRATE",    96000,        true)
  r.GetSetProjectInfo(0,        "RENDER_CHANNELS", 2,            true)
  r.GetSetProjectInfo(0,        "RENDER_SETTINGS", 0,            true) -- master mix
  r.GetSetProjectInfo_String(0, "RENDER_FILE",     render_file,  true)
  P("Render settings applied:")
  P("  Format:  FLAC 24-bit compression-5")
  P("  Rate:    96000 Hz")
  P("  Output:  " .. render_file)
end

r.Main_OnCommand(40026, 0)
P("Project saved.")
P("=== Done ===")
