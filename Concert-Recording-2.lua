-- Concert-Recording-2.lua
-- Set up SOURCE track: muted, no master send, items stitched end-to-end
--
-- Idempotency rules:
--   DONE   — SOURCE track exists and has items → exit, nothing to do
--   ADOPT  — one non-channel track has items already end-to-end → rename it SOURCE
--   STITCH — collect unique WAV paths from all items, rebuild SOURCE from scratch

local r = reaper
local function P(s) r.ShowConsoleMsg(s .. "\n") end
local function die(msg) r.ShowMessageBox(msg, "Concert Recording", 0); error(msg) end

P("=== Concert-Recording-2: SOURCE Track ===")

local CHAN_NAMES = {
  ["KM184-L"]=true, ["KM184-R"]=true, ["KM185-L"]=true,
  ["KM185-R"]=true, ["DPA4017-L"]=true, ["DPA4017-R"]=true
}

local function configure_source(tr)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", "SOURCE", true)
  r.SetMediaTrackInfo_Value(tr, "B_MUTE",     1)
  r.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)
end

-- ---- Case 1: SOURCE already exists with items ----
for t = 0, r.CountTracks(0) - 1 do
  local tr = r.GetTrack(0, t)
  local _, nm = r.GetTrackName(tr)
  if nm == "SOURCE" then
    local n = r.CountTrackMediaItems(tr)
    if n > 0 then
      P("SOURCE track already exists with " .. n .. " item(s). Ensuring mute/send settings.")
      configure_source(tr)
      r.Main_OnCommand(40026, 0)
      P("Project saved.")
      P("=== Done (already stitched) ===")
      return
    end
  end
end

-- ---- Case 2: One non-channel track with items placed end-to-end ----
-- (e.g. user dragged WAV files into REAPER and chose "end-to-end in single track")
local candidate = nil
local n_candidate_tracks = 0
for t = 0, r.CountTracks(0) - 1 do
  local tr = r.GetTrack(0, t)
  local _, nm = r.GetTrackName(tr)
  if not CHAN_NAMES[nm] and nm ~= "SOURCE" then
    if r.CountTrackMediaItems(tr) > 0 then
      candidate = tr
      n_candidate_tracks = n_candidate_tracks + 1
    end
  end
end

if n_candidate_tracks == 1 then
  local n = r.CountTrackMediaItems(candidate)
  -- Verify items are sequential (end-to-end, no gaps or overlaps > 100ms)
  local ok_seq = true
  local prev_end = nil
  for j = 0, n - 1 do
    local item = r.GetTrackMediaItem(candidate, j)
    local pos  = r.GetMediaItemInfo_Value(item, "D_POSITION")
    local len  = r.GetMediaItemInfo_Value(item, "D_LENGTH")
    if prev_end ~= nil and math.abs(pos - prev_end) > 0.1 then
      ok_seq = false
      P(string.format("  WARNING: gap/overlap at item %d (%.3fs from expected pos)", j+1, pos-prev_end))
    end
    prev_end = pos + len
  end
  if ok_seq then
    P("Found " .. n .. " item(s) end-to-end on existing track. Adopting as SOURCE.")
    configure_source(candidate)
    r.Main_OnCommand(40026, 0)
    P("Project saved.")
    P("=== Done (adopted existing track) ===")
    return
  end
  P("Items not sequential — rebuilding from scratch.")
end

-- ---- Case 3: Stitch from scratch ----
P("Collecting WAV paths from all items...")
local seen  = {}
local paths = {}
for t = 0, r.CountTracks(0) - 1 do
  local tr = r.GetTrack(0, t)
  local _, nm = r.GetTrackName(tr)
  if not CHAN_NAMES[nm] then
    for i = 0, r.CountTrackMediaItems(tr) - 1 do
      local item = r.GetTrackMediaItem(tr, i)
      local take = r.GetActiveTake(item)
      if take then
        local src  = r.GetMediaItemTake_Source(take)
        local path = r.GetMediaSourceFileName(src, "")
        if path and path ~= "" and not seen[path] then
          seen[path] = true
          table.insert(paths, path)
        end
      end
    end
  end
end

if #paths == 0 then
  die("No WAV files found in project. Load your WAV files first.")
end
table.sort(paths)

P("Found " .. #paths .. " WAV file(s):")
for i, p in ipairs(paths) do P(string.format("  [%d] %s", i, p:match("[^/]+$"))) end

-- Delete all non-channel tracks, rebuild SOURCE
for t = r.CountTracks(0) - 1, 0, -1 do
  local tr = r.GetTrack(0, t)
  local _, nm = r.GetTrackName(tr)
  if not CHAN_NAMES[nm] then r.DeleteTrack(tr) end
end

r.InsertTrackAtIndex(0, true)
local src_tr = r.GetTrack(0, 0)
configure_source(src_tr)

local pos = 0.0
for _, path in ipairs(paths) do
  local src = r.PCM_Source_CreateFromFile(path)
  if not src then die("Could not load:\n" .. path) end
  local len = r.GetMediaSourceLength(src, false)
  if len <= 0 then die("Zero-length source:\n" .. path) end
  local item = r.AddMediaItemToTrack(src_tr)
  local take = r.AddTakeToMediaItem(item)
  r.SetMediaItemTake_Source(take, src)
  r.SetMediaItemInfo_Value(item, "D_POSITION", pos)
  r.SetMediaItemInfo_Value(item, "D_LENGTH",   len)
  P(string.format("  pos=%8.2fs  len=%8.2fs  %s", pos, len, path:match("[^/]+$")))
  pos = pos + len
end

r.UpdateArrange()
r.Main_OnCommand(40026, 0)
P(string.format("Total: %.1f min", pos / 60))
P("Project saved.")
P("=== Done ===")
