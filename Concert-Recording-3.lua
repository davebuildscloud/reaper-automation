-- Concert-Recording-3.lua
-- Explode SOURCE track into 6 mono channel tracks using REAPER's native
-- "Item: Explode multichannel audio or MIDI items to new one-channel items" action.
-- This creates truly mono items — one swim lane per microphone.
-- After explode, renames tracks from "SOURCE [chan N]" to mic names.
-- Idempotent: exits gracefully if all 6 named tracks already exist with items.

local r = reaper
local function P(s) r.ShowConsoleMsg(s .. "\n") end
local function die(msg) r.ShowMessageBox(msg, "Concert Recording", 0); error(msg) end

-- Mic assignment: Zoom F8n Pro channel order for Blue Ox 2026
local CHANNEL_NAMES = {
  "KM184-L",   -- ch 1
  "KM184-R",   -- ch 2
  "KM185-L",   -- ch 3
  "KM185-R",   -- ch 4
  "DPA4017-L", -- ch 5
  "DPA4017-R", -- ch 6
}

-- REAPER built-in action: "Item: Explode multichannel audio or MIDI items to new one-channel items"
-- If this fails with "created no tracks", find the correct ID:
--   1. REAPER → Actions → Show action list
--   2. Search: explode multichannel
--   3. Right-click → Copy command ID → paste below
local EXPLODE_CMD = 40894

P("=== Concert-Recording-3: Explode Channels ===")

-- ---- Idempotency: all 6 named tracks already have items? ----
local function build_track_map()
  local m = {}
  for t = 0, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, t)
    local _, nm = r.GetTrackName(tr)
    m[nm] = tr
  end
  return m
end

local function unmute_channel_items(tmap)
  -- Always unmute all items on all 6 channel tracks.
  -- REAPER's explode action inherits item-level mute from source items;
  -- this corrects that even on subsequent idempotency runs.
  local fixed = 0
  for _, name in ipairs(CHANNEL_NAMES) do
    local tr = tmap[name]
    if tr then
      for i = 0, r.CountTrackMediaItems(tr) - 1 do
        local item = r.GetTrackMediaItem(tr, i)
        if r.GetMediaItemInfo_Value(item, "B_MUTE") ~= 0 then
          r.SetMediaItemInfo_Value(item, "B_MUTE", 0)
          fixed = fixed + 1
        end
      end
    end
  end
  if fixed > 0 then P("Unmuted " .. fixed .. " item(s) on channel tracks.") end
end

local track_map = build_track_map()
local all_done = true
for _, name in ipairs(CHANNEL_NAMES) do
  local tr = track_map[name]
  if not tr or r.CountTrackMediaItems(tr) == 0 then all_done = false; break end
end
if all_done then
  P("All 6 channel tracks already present with items.")
  -- Fix SOURCE folder depth (in case it was left as a folder parent)
  for t = 0, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, t)
    local _, nm = r.GetTrackName(tr)
    if nm == "SOURCE" then
      r.SetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH", 0)
      break
    end
  end
  -- Fix channel track states
  for _, name in ipairs(CHANNEL_NAMES) do
    local tr = track_map[name]
    if tr then
      r.SetMediaTrackInfo_Value(tr, "B_MUTE",        0)
      r.SetMediaTrackInfo_Value(tr, "B_MAINSEND",    1)
      r.SetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH", 0)
    end
  end
  unmute_channel_items(track_map)
  r.UpdateArrange()
  r.Main_OnCommand(40026, 0)
  P("=== Done (already exploded) ===")
  return
end

-- ---- Find SOURCE track ----
local src_tr = nil
for t = 0, r.CountTracks(0) - 1 do
  local tr = r.GetTrack(0, t)
  local _, nm = r.GetTrackName(tr)
  if nm == "SOURCE" then src_tr = tr; break end
end
if not src_tr then die("SOURCE track not found. Run Concert-Recording-2 first.") end
local n_src = r.CountTrackMediaItems(src_tr)
if n_src == 0 then die("SOURCE track has no items. Run Concert-Recording-2 first.") end
P("SOURCE: " .. n_src .. " item(s)")

-- ---- Delete any pre-existing channel tracks (clean slate before explode) ----
for t = r.CountTracks(0) - 1, 0, -1 do
  local tr = r.GetTrack(0, t)
  local _, nm = r.GetTrackName(tr)
  local is_chan = (nm:match("^SOURCE %[chan %d+%]$") ~= nil)
  for _, name in ipairs(CHANNEL_NAMES) do
    if nm == name then is_chan = true; break end
  end
  if is_chan then r.DeleteTrack(tr) end
end
P("Old channel tracks removed.")

-- Re-find SOURCE after deletes
src_tr = nil
for t = 0, r.CountTracks(0) - 1 do
  local tr = r.GetTrack(0, t)
  local _, nm = r.GetTrackName(tr)
  if nm == "SOURCE" then src_tr = tr; break end
end
n_src = r.CountTrackMediaItems(src_tr)
P("SOURCE still has " .. n_src .. " item(s).")

-- ---- Flatten SOURCE folder depth so exploded tracks are NOT children ----
-- If SOURCE is a folder parent (I_FOLDERDEPTH=1), the exploded channel tracks
-- will be created as its children and will route THROUGH the muted SOURCE → silence.
local src_depth = r.GetMediaTrackInfo_Value(src_tr, "I_FOLDERDEPTH")
if src_depth ~= 0 then
  r.SetMediaTrackInfo_Value(src_tr, "I_FOLDERDEPTH", 0)
  P("SOURCE folder depth reset to 0 (was " .. src_depth .. ").")
end

-- ---- Select all SOURCE items, deselect everything else ----
r.Main_OnCommand(40289, 0)  -- Unselect all items
for j = 0, n_src - 1 do
  r.SetMediaItemSelected(r.GetTrackMediaItem(src_tr, j), true)
end
P("Selected " .. n_src .. " SOURCE items.")

-- ---- Run REAPER's native multichannel explode ----
local tracks_before = r.CountTracks(0)
r.Main_OnCommand(EXPLODE_CMD, 0)
r.UpdateArrange()
local new_tracks = r.CountTracks(0) - tracks_before
P("Explode action (cmd=" .. EXPLODE_CMD .. ") created " .. new_tracks .. " new track(s).")

if new_tracks == 0 then
  die(
    "Explode action (cmd " .. EXPLODE_CMD .. ") created no tracks.\n\n" ..
    "To find the correct action ID:\n" ..
    "  1. REAPER → Actions → Show action list\n" ..
    "  2. Search: explode multichannel\n" ..
    "  3. Right-click the action → Copy command ID\n" ..
    "  4. Update EXPLODE_CMD near the top of Concert-Recording-3.lua\n" ..
    "     and re-run."
  )
end

-- ---- Find the resulting "SOURCE [chan N]" tracks ----
local chan_tracks = {}
track_map = build_track_map()
for nm, tr in pairs(track_map) do
  local ch_str = nm:match("^SOURCE %[chan (%d+)%]$")
  if ch_str then
    chan_tracks[tonumber(ch_str)] = tr
  end
end

-- Verify all 6 channels are present
local missing = {}
for ch = 1, 6 do
  if not chan_tracks[ch] then table.insert(missing, ch) end
end
if #missing > 0 then
  local all_names = {}
  for nm, _ in pairs(track_map) do table.insert(all_names, nm) end
  table.sort(all_names)
  die(
    "Missing SOURCE [chan " .. table.concat(missing, ", ") .. "] after explode.\n\n" ..
    "Tracks present:\n  " .. table.concat(all_names, "\n  ")
  )
end

-- ---- Rename and configure each channel track ----
for ch = 1, 6 do
  local tr    = chan_tracks[ch]
  local name  = CHANNEL_NAMES[ch]
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
  r.SetMediaTrackInfo_Value(tr, "B_MAINSEND",    1)  -- send to master
  r.SetMediaTrackInfo_Value(tr, "B_MUTE",        0)  -- ensure track is unmuted
  r.SetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH", 0)  -- ensure not a folder
  -- Unmute all items — REAPER's explode action inherits item-level mute
  -- from the source items (even when only the track, not the items, was muted).
  local n = r.CountTrackMediaItems(tr)
  for i = 0, n - 1 do
    local item = r.GetTrackMediaItem(tr, i)
    r.SetMediaItemInfo_Value(item, "B_MUTE", 0)
  end
  P(string.format("  ch%d → %-12s  %d item(s), items unmuted", ch, name, n))
end

-- ---- Post-explode: flatten SOURCE (explode action resets it to folder parent) ----
-- Must run AFTER rename loop so src_tr is still valid.
r.SetMediaTrackInfo_Value(src_tr, "I_FOLDERDEPTH", 0)
P("SOURCE folder depth reset to 0 (post-explode).")

r.UpdateArrange()
r.Main_OnCommand(40026, 0)
P("Channels exploded and renamed. Project saved.")
P("=== Done ===")
