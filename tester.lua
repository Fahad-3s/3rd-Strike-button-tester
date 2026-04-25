-- Button tester LUA script written by Cartola

local p1_life = 0x02028655
local p2_life = 0x0202866D

local p1_hit = 0x0202884D
local p2_hit = 0x02028861

local p1_state       = 0x02068E75
local p2_state       = 0x020691B3
local p1_other_state = 0x02068E73
local p2_other_state = 0x020691B1
local hitboxes       = 0x02009EFC

local function is_parrying(state, other_state)
  return other_state == 0 and (state >= 24 and state <= 27)
end

local p1_parry_high     = 0x02026335
local p1_parry_low      = 0x02026337
local p1_parry_air      = 0x02026339
local p1_parry_antiair  = 0x02026347

local p2_parry_high     = 0x0202673B
local p2_parry_low      = 0x0202673D
local p2_parry_air      = 0x0202673F
local p2_parry_antiair  = 0x0202674D

local function write_parry_p1()
  memory.writebyte(p1_parry_high,    10)
  memory.writebyte(p1_parry_low,     10)
  memory.writebyte(p1_parry_air,     10)
  memory.writebyte(p1_parry_antiair, 10)
end

local function write_parry_p2()
  memory.writebyte(p2_parry_high,    10)
  memory.writebyte(p2_parry_low,     10)
  memory.writebyte(p2_parry_air,     10)
  memory.writebyte(p2_parry_antiair, 10)
end

local p1_button = { "P1 Weak Punch", "P1 Medium Punch", "P1 Strong Punch", "P1 Weak Kick", "P1 Medium Kick", "P1 Strong Kick" }
local p2_button = { "P2 Weak Punch", "P2 Medium Punch", "P2 Strong Punch", "P2 Weak Kick", "P2 Medium Kick", "P2 Strong Kick" }

local speedmode_turbo = true -- Set this to true if you want to simulate at fast forward speed. False for normal speed

local LP, MP, HP, LK, MK, HK = 1, 2, 3, 4, 5, 6

local p1_joystick = { "P1 Up", "P1 Down", "P1 Left", "P1 Right" }
local p2_joystick = { "P2 Up", "P2 Down", "P2 Left", "P2 Right" }

-- ============================================================
-- SETTINGS FILE PARSER
-- ============================================================

local button_map = { LP=1, MP=2, HP=3, LK=4, MK=5, HK=6 }
local direction_map = { Up=1, Down=2, Left=3, Right=4, Forward=5, Back=6, ["2"]=2, ["4"]=6, ["6"]=5, ["8"]=1 }
local btn_names = { "LP", "MP", "HP", "LK", "MK", "HK" }

-- Numpad direction to list of direction indices
-- 1=Down+Back, 2=Down, 3=Down+Forward, 4=Back, 5=neutral, 6=Forward, 7=Up+Back, 8=Up, 9=Up+Forward
local numpad_dirs = {
  [1] = {2, 6},  -- Down + Back
  [2] = {2},     -- Down
  [3] = {2, 5},  -- Down + Forward
  [4] = {6},     -- Back
  [5] = {},      -- Neutral
  [6] = {5},     -- Forward
  [7] = {1, 6},  -- Up + Back
  [8] = {1},     -- Up
  [9] = {1, 5},  -- Up + Forward
}

-- Parse a button entry which may be plain ("MK") or numpad notation ("2MK", "6MP")
-- Returns {btn_index, press_dirs}
local function parse_button_entry(entry)
  entry = entry:match("^%s*(.-)%s*$")
  -- Check for manual threshold suffix e.g. "5HP(40)"
  local entry_no_thresh, thresh_str = entry:match("^(.-)%((%d+)%)$")
  local manual_threshold = nil
  if entry_no_thresh and thresh_str then
    manual_threshold = tonumber(thresh_str)
    entry = entry_no_thresh:match("^%s*(.-)%s*$")
  end
  local numpad, btn_str = entry:match("^(%d)(%a+)$")
  if numpad and btn_str then
    local btn = button_map[btn_str]
    if btn then
      return {btn=btn, dirs=numpad_dirs[tonumber(numpad)] or {}, manual_threshold=manual_threshold}
    end
  end
  -- Plain button name, no direction
  local btn = button_map[entry]
  if btn then
    return {btn=btn, dirs={}, manual_threshold=manual_threshold}
  end
  print("[SETTINGS] Warning: unknown button entry '" .. entry .. "'")
  return nil
end

-- Parse a comma-separated list of button entries
local function parse_buttons_list(str)
  local result = {}
  if not str or str:match("^%s*$") then return result end
  for item in str:gmatch("[^,]+") do
    local entry = parse_button_entry(item)
    if entry then result[#result+1] = entry end
  end
  return result
end

local char_names = {
  [1]  = "Alex",
  [2]  = "Ryu",
  [3]  = "Yun",
  [4]  = "Dudley",
  [5]  = "Necro",
  [6]  = "Hugo",
  [7]  = "Ibuki",
  [8]  = "Elena",
  [9]  = "Oro",
  [10] = "Yang",
  [11] = "Ken",
  [12] = "Sean",
  [13] = "Urien",
  [14] = "Gouki",
  [16] = "Chun-Li",
  [17] = "Makoto",
  [18] = "Q",
  [19] = "Twelve",
  [20] = "Remy",
}

local p1_char = char_names[memory.readbyte(0x02011387)] or "P1"
local p2_char = char_names[memory.readbyte(0x02011388)] or "P2"

-- Convert a list of direction indices to a numpad number
-- Directions: 1=Up, 2=Down, 3=Left, 4=Right, 5=Forward, 6=Back
-- Forward/Back are resolved at press time so here we treat 5=Forward=Right-ish, 6=Back=Left-ish
local function dirs_to_numpad(dirs)
  local up, down, left, right = false, false, false, false
  for _, d in ipairs(dirs) do
    if d == 1 then up = true end
    if d == 2 then down = true end
    if d == 3 then left = true end
    if d == 4 then right = true end
    if d == 5 then right = true end  -- Forward
    if d == 6 then left = true end   -- Back
  end
  if up and left then return 7
  elseif up and right then return 9
  elseif down and left then return 1
  elseif down and right then return 3
  elseif up then return 8
  elseif down then return 2
  elseif left then return 4
  elseif right then return 6
  else return 5
  end
end

-- Build move name like "2LK" or "5MP"
local function move_name(btn_index, press_dirs)
  return tostring(dirs_to_numpad(press_dirs)) .. btn_names[btn_index]
end

local function parse_list(str, map)
  local result = {}
  if not str or str:match("^%s*$") then return result end
  for item in str:gmatch("[^,]+") do
    item = item:match("^%s*(.-)%s*$")
    local val = map[item]
    if val then
      result[#result + 1] = val
    else
      print("[SETTINGS] Warning: unknown value '" .. item .. "'")
    end
  end
  return result
end

local function parse_settings(filepath)
  local f = io.open(filepath, "r")
  if not f then
    print("[SETTINGS] ERROR: Could not open settings file: " .. filepath)
    return nil
  end
  local settings = {}
  for line in f:lines() do
    line = line:match("^%s*(.-)%s*$")
    if line ~= "" and line:sub(1,1) ~= "#" then
      local key, val = line:match("^([%w_]+)%s*=%s*(.-)%s*$")
      if key then settings[key] = val end
    end
  end
  f:close()
  return settings
end

local settings = parse_settings("settings.ini")
if not settings then error("Could not load settings.ini") end

local p1_buttons_list = parse_buttons_list(settings["p1_buttons"])
local p2_buttons_list = parse_buttons_list(settings["p2_buttons"])
local p1_idle_dirs    = parse_list(settings["p1_idle"], direction_map)
local p2_idle_dirs    = parse_list(settings["p2_idle"], direction_map)

if #p1_buttons_list == 0 then error("No valid p1_buttons in settings.ini") end
if #p2_buttons_list == 0 then error("No valid p2_buttons in settings.ini") end

print("[SETTINGS] P1 buttons: " .. settings["p1_buttons"])
print("[SETTINGS] P2 buttons: " .. settings["p2_buttons"])
print("[SETTINGS] P1 idle: " .. (settings["p1_idle"] ~= "" and settings["p1_idle"] or "none"))
print("[SETTINGS] P2 idle: " .. (settings["p2_idle"] ~= "" and settings["p2_idle"] or "none"))


local p1_xpixel = 0x02068CD0+0x1
local p1_xcounter = 0x02068CD0+0x0
local p1_xpos = (memory.readbyte(p1_xpixel) + (memory.readbyte(p1_xcounter) * 256))

local p2_xpixel = 0x02069168+0x1
local p2_xcounter = 0x02069168+0x0
local p2_xpos = (memory.readbyte(p2_xpixel) + (memory.readbyte(p2_xcounter) * 256))

local dist_a = (p2_xpos - p1_xpos)
local dist_b = 48

if p2_xpos <= p1_xpos then

  dist_a = dist_a * -1

end

io.output(file)

do

  if p1_xpos < p2_xpos then

    memory.writebyte(0x02068CD0+0x2, 0)
    memory.writebyte(0x02069168+0x2, 255)   

  elseif p1_xpos > p2_xpos then

    memory.writebyte(0x02068CD0+0x2, 255)
    memory.writebyte(0x02069168+0x2, 0)   
    
  end

   memory.writebyte(0x02011377, 100)
   savestate.save(1)
   savestate.save(2)

   if speedmode_turbo == true then

      emu.speedmode("turbo")

   end
  
    -- Measure full move length (until player returns to idle) for a button
    local function measure_active_frames(button_table, btn_index, joystick_table, press_dirs, is_p1)
      savestate.load(2)
      -- Resolve facing direction
      local xpos1 = memory.readbyte(0x02068CD0+0x1) + (memory.readbyte(0x02068CD0+0x0) * 256)
      local xpos2 = memory.readbyte(0x02069168+0x1) + (memory.readbyte(0x02069168+0x0) * 256)
      local fwd, back
      if is_p1 then
        fwd  = (xpos1 < xpos2) and 4 or 3
        back = (xpos1 < xpos2) and 3 or 4
      else
        fwd  = (xpos2 < xpos1) and 4 or 3
        back = (xpos2 < xpos1) and 3 or 4
      end
      -- Press the button with resolved directions
      local inputs = {[button_table[btn_index]]=true}
      for _, d in ipairs(press_dirs) do
        local rd = (d == 5) and fwd or (d == 6) and back or d
        inputs[joystick_table[rd]] = true
      end
      joypad.set(inputs)
      emu.frameadvance()
      joypad.set({})

      local state_addr       = is_p1 and p1_state       or p2_state
      local other_state_addr = is_p1 and p1_other_state or p2_other_state
      local frame_count = 0

      -- Wait for move to start (either state or other_state becomes non-zero)
      for _ = 1, 500 do
        if memory.readbyte(state_addr) ~= 0 or memory.readbyte(other_state_addr) ~= 0 then break end
        emu.frameadvance()
      end

      -- Count frames until both state and other_state return to zero
      for _ = 1, 500 do
        if memory.readbyte(state_addr) == 0 and memory.readbyte(other_state_addr) == 0 then break end
        frame_count = frame_count + 1
        emu.frameadvance()
      end
      return frame_count
    end

    -- Create a folder path using os.execute mkdir
    local function ensure_dir(path)
      os.execute('mkdir "' .. path .. '" 2>nul')
    end

    for p1i = 1, #p1_buttons_list do
    for p2i = 1, #p2_buttons_list do

      local p1_entry = p1_buttons_list[p1i]
      local p2_entry = p2_buttons_list[p2i]
      local p1_press = p1_entry.btn
      local p2_press = p2_entry.btn
      local p1_press_dirs = p1_entry.dirs
      local p2_press_dirs = p2_entry.dirs

      savestate.load(2)

      -- Measure active frames for each move to set nothing threshold
      local p1_active = p1_entry.manual_threshold or measure_active_frames(p1_button, p1_press, p1_joystick, p1_press_dirs, true)
      local p2_active = p2_entry.manual_threshold or measure_active_frames(p2_button, p2_press, p2_joystick, p2_press_dirs, false)
      local nothing_threshold = math.max(p1_active, p2_active)
      if nothing_threshold < 3 then nothing_threshold = 3 end
      print("Nothing threshold for this combo: " .. nothing_threshold .. " (P1: " .. p1_active .. ", P2: " .. p2_active .. ")")

      savestate.load(2)

      local f_results = {}
      local all_distances = {}  -- { {distance=N, sorted_fs={...}, results={f->outcome}} }

      local p1_name = p1_char .. " " .. move_name(p1_press, p1_press_dirs)
      local p2_name = p2_char .. " " .. move_name(p2_press, p2_press_dirs)

      function dmgreadwin(f, p1_got_hit, p2_got_hit)

          if p2_got_hit and not p1_got_hit then
          local s = "At "..f..", "..p1_name.." beats "..p2_name
          print(s)
          f_results[f] = s
          end

      end

      function dmgreadlose(f, p1_got_hit, p2_got_hit)

          if p1_got_hit and not p2_got_hit then
          local s = "At "..f..", "..p1_name.." loses to "..p2_name
          print(s)
          f_results[f] = s
          end

      end

      function dmgreadtrade(f, p1_got_hit, p2_got_hit)

          if p1_got_hit and p2_got_hit then
          local s = "At "..f..", "..p1_name.." trades with "..p2_name
          print(s)
          f_results[f] = s
          end

      end

      function dmgreadnothing(f, p1_got_hit, p2_got_hit)

          if not p1_got_hit and not p2_got_hit then
          print("nothing")
          f_results[f] = "nothing"
          end

      end

      -- p1_press and p2_press are set from settings above

      -- Track P1's absolute position as a single integer (pixel + counter*256)
      local p1_xpixel = 0x02068CD0+0x1
      local p1_xcounter = 0x02068CD0+0x0
      local p1_pos_abs = memory.readbyte(p1_xpixel) + (memory.readbyte(p1_xcounter) * 256)

      local p2_xpixel = 0x02069168+0x1
      local p2_xcounter = 0x02069168+0x0
      local p2_pos_abs = memory.readbyte(p2_xpixel) + (memory.readbyte(p2_xcounter) * 256)

      -- Helper: test f=-nothing_threshold to +nothing_threshold, return true if any interaction
      local function has_interaction()
        for f = -nothing_threshold, nothing_threshold do
          savestate.load(2)
          memory.writebyte(p1_xpixel, p1_pos_abs % 256)
          memory.writebyte(p1_xcounter, math.floor(p1_pos_abs / 256))
          p1_got_hit = false
          p2_got_hit = false
          local interaction_started = false
          local parry_occurred = false
          local hitbox_appeared = false
          for b = math.min(f, 0) - 1, 10000 do
            write_parry_p1()
            write_parry_p2()
            if is_parrying(memory.readbyte(p1_state), memory.readbyte(p1_other_state))
            or is_parrying(memory.readbyte(p2_state), memory.readbyte(p2_other_state)) then
              parry_occurred = true
              break
            end
            local p1_xpos_b = memory.readbyte(0x02068CD0+0x1) + (memory.readbyte(0x02068CD0+0x0) * 256)
            local p2_xpos_b = memory.readbyte(0x02069168+0x1) + (memory.readbyte(0x02069168+0x0) * 256)
            local p1_back, p1_forward, p2_back, p2_forward
            if p1_xpos_b < p2_xpos_b then
              p1_back, p1_forward = 3, 4
              p2_back, p2_forward = 4, 3
            else
              p1_back, p1_forward = 4, 3
              p2_back, p2_forward = 3, 4
            end
            local function resolve_p1(d)
              if d == 5 then return p1_forward elseif d == 6 then return p1_back else return d end
            end
            local function resolve_p2(d)
              if d == 5 then return p2_forward elseif d == 6 then return p2_back else return d end
            end
            if not parry_occurred then
              local inputs = {}

              -- P1 input
              if f == 0 then
                if b == 0 then
                  inputs[p1_button[p1_press]] = true
                  for _, d in ipairs(p1_press_dirs) do inputs[p1_joystick[resolve_p1(d)]] = true end
                elseif b < 0 then
                  for _, d in ipairs(p1_idle_dirs) do inputs[p1_joystick[resolve_p1(d)]] = true end
                end
              else
                if b == f then
                  inputs[p1_button[p1_press]] = true
                  for _, d in ipairs(p1_press_dirs) do inputs[p1_joystick[resolve_p1(d)]] = true end
                  if f > 0 then interaction_started = true end
                elseif b < f then
                  for _, d in ipairs(p1_idle_dirs) do inputs[p1_joystick[resolve_p1(d)]] = true end
                end
              end

              -- P2 input
              if b == 0 then
                inputs[p2_button[p2_press]] = true
                for _, d in ipairs(p2_press_dirs) do inputs[p2_joystick[resolve_p2(d)]] = true end
                if f <= 0 then interaction_started = true end
              elseif b < 0 then
                for _, d in ipairs(p2_idle_dirs) do inputs[p2_joystick[resolve_p2(d)]] = true end
              end

              joypad.set(inputs)
            end
            emu.frameadvance()
            if memory.readbyte(hitboxes) ~= 0 then hitbox_appeared = true end
            if memory.readbyte(p1_hit) == 1 then p1_got_hit = true end
            if memory.readbyte(p2_hit) == 1 then p2_got_hit = true end
            if interaction_started and b > math.max(f, 0) and hitbox_appeared
               and (p1_got_hit or p2_got_hit)
               and memory.readbyte(p1_state) == 0 and memory.readbyte(p1_other_state) == 0
               and memory.readbyte(p2_state) == 0 and memory.readbyte(p2_other_state) == 0 then break end
            if interaction_started and b > math.max(f, 0) and hitbox_appeared
               and memory.readbyte(p1_state) == 0 and memory.readbyte(p1_other_state) == 0
               and memory.readbyte(p2_state) == 0 and memory.readbyte(p2_other_state) == 0 then break end
          end
          if p1_got_hit or p2_got_hit or parry_occurred then return true end
        end
        return false
      end

      local p1_facing_left = (p1_pos_abs < p2_pos_abs)
      if not has_interaction() then
        -- Phase 1: coarse search — jump 40px closer until interaction found
        while not has_interaction() do
          if p1_facing_left then p1_pos_abs = p1_pos_abs + 40
          else p1_pos_abs = p1_pos_abs - 40 end
          print("Searching... jumping 40px closer")
        end

        -- Phase 2: step back 10px at a time until we land on nothing
        while has_interaction() do
          if p1_facing_left then p1_pos_abs = p1_pos_abs - 10
          else p1_pos_abs = p1_pos_abs + 10 end
          print("Stepping back 10px...")
        end
      end
      print("Starting real test from distance search position")

      while true do

          local p1_xpos = p1_pos_abs
          local p2_xpos = p2_pos_abs

          local distance = (p2_xpos - p1_xpos)

          if p2_xpos <= p1_xpos then

            distance = distance * -1
          
          end

          -- Reset results table for this distance step
          f_results = {}

          print("Distance of " .. distance .. " pixels: ")
              

          -- Function to test a single frame offset f
          local function test_frame(f)

            savestate.load(2)

            -- Write P1's position for this distance step
            memory.writebyte(p1_xpixel, p1_pos_abs % 256)
            memory.writebyte(p1_xcounter, math.floor(p1_pos_abs / 256))

            p1_got_hit = false
            p2_got_hit = false
            local interaction_started = false
            local parry_occurred = false
            local hitbox_appeared = false

            for b = math.min(f, 0) - 1, 10000 do

              write_parry_p1()
              write_parry_p2()

              if is_parrying(memory.readbyte(p1_state), memory.readbyte(p1_other_state))
              or is_parrying(memory.readbyte(p2_state), memory.readbyte(p2_other_state)) then
                parry_occurred = true
                break
              end

              local p1_xpixel_b = 0x02068CD0+0x1
              local p1_xcounter_b = 0x02068CD0+0x0
              local p1_xpos_b = (memory.readbyte(p1_xpixel_b) + (memory.readbyte(p1_xcounter_b) * 256))

              local p2_xpixel_b = 0x02069168+0x1
              local p2_xcounter_b = 0x02069168+0x0
              local p2_xpos_b = (memory.readbyte(p2_xpixel_b) + (memory.readbyte(p2_xcounter_b) * 256))

              -- Determine back/forward directions based on player positions
              local p1_back, p1_forward, p2_back, p2_forward
              if p1_xpos_b < p2_xpos_b then
                p1_back, p1_forward = 3, 4  -- P1 on left: back=Left, forward=Right
                p2_back, p2_forward = 4, 3  -- P2 on right: back=Right, forward=Left
              else
                p1_back, p1_forward = 4, 3  -- P1 on right: back=Right, forward=Left
                p2_back, p2_forward = 3, 4  -- P2 on left: back=Left, forward=Right
              end

              -- Resolve a direction index for a given player (5=Forward, 6=Back, else use as-is)
              local function resolve_p1(d)
                if d == 5 then return p1_forward
                elseif d == 6 then return p1_back
                else return d end
              end
              local function resolve_p2(d)
                if d == 5 then return p2_forward
                elseif d == 6 then return p2_back
                else return d end
              end

                -- Mark interaction as started on the last button press frame
                if (f == 0 and b == 0) or (f ~= 0 and b == math.max(f, 0)) then
                  interaction_started = true
                end

                if not parry_occurred then

                  local inputs = {}

                  -- P1 input
                  if f == 0 then
                    if b == 0 then
                      inputs[p1_button[p1_press]] = true
                      for _, d in ipairs(p1_press_dirs) do inputs[p1_joystick[resolve_p1(d)]] = true end
                    elseif b < 0 then
                      for _, d in ipairs(p1_idle_dirs) do inputs[p1_joystick[resolve_p1(d)]] = true end
                    end
                  else
                    if b == f then
                      inputs[p1_button[p1_press]] = true
                      for _, d in ipairs(p1_press_dirs) do inputs[p1_joystick[resolve_p1(d)]] = true end
                    elseif b < f then
                      for _, d in ipairs(p1_idle_dirs) do inputs[p1_joystick[resolve_p1(d)]] = true end
                    end
                  end

                  -- P2 input
                  if b == 0 then
                    -- P2 press frame
                    inputs[p2_button[p2_press]] = true
                    for _, d in ipairs(p2_press_dirs) do inputs[p2_joystick[resolve_p2(d)]] = true end
                  elseif b < 0 then
                    -- P2 hasn't pressed yet, hold idle
                    for _, d in ipairs(p2_idle_dirs) do inputs[p2_joystick[resolve_p2(d)]] = true end
                  end

                  joypad.set(inputs)

                end

                emu.frameadvance()

              if memory.readbyte(hitboxes) ~= 0 then hitbox_appeared = true end
              if memory.readbyte(p1_hit) == 1 then p1_got_hit = true end
              if memory.readbyte(p2_hit) == 1 then p2_got_hit = true end

              -- Early exit: a hit was detected and both players back to neutral
              if interaction_started
                 and b > math.max(f, 0)
                 and hitbox_appeared
                 and (p1_got_hit or p2_got_hit)
                 and memory.readbyte(p1_state) == 0
                 and memory.readbyte(p1_other_state) == 0
                 and memory.readbyte(p2_state) == 0
                 and memory.readbyte(p2_other_state) == 0 then
                break
              end

              -- Early exit: both players back to neutral (nothing case)
              if interaction_started
                 and b > math.max(f, 0)
                 and hitbox_appeared
                 and memory.readbyte(p1_state) == 0
                 and memory.readbyte(p1_other_state) == 0
                 and memory.readbyte(p2_state) == 0
                 and memory.readbyte(p2_other_state) == 0 then
                break
              end

            end

            dmgreadlose(f, p1_got_hit, p2_got_hit)
            dmgreadtrade(f, p1_got_hit, p2_got_hit)
            dmgreadwin(f, p1_got_hit, p2_got_hit)
            dmgreadnothing(f, p1_got_hit, p2_got_hit)

          end

          -- Test f=0 first
          test_frame(0)

          -- Expand negative direction: test nothing_threshold frames
          for f = -1, -nothing_threshold, -1 do
            test_frame(f)
          end

          -- Expand positive direction: test nothing_threshold frames
          for f = 1, nothing_threshold do
            test_frame(f)
          end

          -- Collect and sort all tested f values, store into all_distances
          local sorted_fs = {}
          for f_val, _ in pairs(f_results) do
            table.insert(sorted_fs, f_val)
          end
          table.sort(sorted_fs)
          table.insert(all_distances, {distance = distance, sorted_fs = sorted_fs, results = f_results})
          f_results = {}

          -- Stop when distance reaches dist_b
          if distance <= dist_b then break end

          -- Move P1 one pixel closer to P2 for the next distance step
          if p1_xpos < p2_xpos then
            p1_pos_abs = p1_pos_abs + 1
          else
            p1_pos_abs = p1_pos_abs - 1
          end

      end

    -- ============================================================
    -- IN-MEMORY POST-PROCESSING
    -- ============================================================

    local p1_move = p1_char .. " " .. move_name(p1_press, p1_press_dirs)
    local p2_move = p2_char .. " " .. move_name(p2_press, p2_press_dirs)

    -- Flip sign: negative->positive, positive->negative, 0->+0
    local function flip_f(f)
      return -f
    end

    -- Format a frame number with sign, always showing +0 for zero
    local function fmt_f(f)
      if f == 0 then return "+0"
      elseif f > 0 then return "+" .. f
      else return tostring(f) end
    end

    -- Format a frame range string, padding to a given width
    local function fmt_range(f1, f2, width)
      local s
      if f1 == f2 then
        s = "At " .. fmt_f(f1) .. ","
      else
        s = "At " .. fmt_f(f1) .. "~" .. fmt_f(f2) .. ","
      end
      while #s < width do s = s .. " " end
      return s
    end

    -- For each distance, group consecutive same-outcome frames (skip nothings)
    -- Returns list of {f_start, f_end, outcome_type} where outcome_type is "wins"/"loses"/"trades"
    local function get_groups(dist_entry)
      local groups = {}
      local cur_type = nil
      local cur_start = nil
      local cur_end = nil
      for _, f_val in ipairs(dist_entry.sorted_fs) do
        local outcome = dist_entry.results[f_val]
        local otype
        if outcome:find("beats") then otype = "wins"
        elseif outcome:find("loses") then otype = "loses"
        elseif outcome:find("trades") then otype = "trades"
        end
        if otype then
          if otype == cur_type then
            cur_end = f_val
          else
            if cur_type then
              table.insert(groups, {f_start=cur_start, f_end=cur_end, otype=cur_type})
            end
            cur_type = otype
            cur_start = f_val
            cur_end = f_val
          end
        else
          if cur_type then
            table.insert(groups, {f_start=cur_start, f_end=cur_end, otype=cur_type})
            cur_type = nil
          end
        end
      end
      if cur_type then
        table.insert(groups, {f_start=cur_start, f_end=cur_end, otype=cur_type})
      end
      return groups
    end

    -- Convert groups to a string key for grouping identical distances
    local function groups_key(groups)
      local parts = {}
      for _, g in ipairs(groups) do
        table.insert(parts, g.f_start .. "," .. g.f_end .. "," .. g.otype)
      end
      return table.concat(parts, "|")
    end

    -- Build grouped distance blocks
    local dist_blocks = {}
    for _, dist_entry in ipairs(all_distances) do
      local groups = get_groups(dist_entry)
      if #groups > 0 then
        local key = groups_key(groups)
        if #dist_blocks > 0 and dist_blocks[#dist_blocks].key == key then
          dist_blocks[#dist_blocks].d_end = dist_entry.distance
        else
          table.insert(dist_blocks, {d_start=dist_entry.distance, d_end=dist_entry.distance, key=key, groups=groups})
        end
      end
    end

    -- Write a file from one player's perspective
    -- flip_sign: negate frame values and swap start/end within each range
    -- flip_outcome: swap wins<->loses
    -- reverse_lines: reverse order of outcome lines within each block
    local function write_file(filename, header, attacker, flip_outcome, flip_sign, reverse_lines)
      local out = io.open(filename, "w")
      out:write(header .. "\n\n")

      -- Create table to eliminate duplicate results at different distances
      merged_dist_blocks = {}
      merged_indices = {}

      -- Create table for cleaned results
      normalised_dist_blocks = {}

      -- Iterates through each and every block and compares with each other to see if they have same results and are not disjointed
      for i, block1 in ipairs(dist_blocks) do
        for j, block2 in ipairs(dist_blocks) do

          -- Variable to see if blocks should be processed
          process = true

          -- If they've been processed already, do not process again
          for _, merged_index in ipairs(merged_indices) do
            if merged_index == i or merged_index == j then
              process = false
            end
          end

          -- If the two blocks are referring to the same block, do not process
          if block1 == block2 then
            process = false
          end

          -- First checks to see if the length of both blocks groups are the same, and if the key is the same
          if #block1.groups == #block2.groups and block1.key == block2.key then
            matching = true
          else
            matching = false
          end

          -- Goes through both blocks' groups to see if all the interactions are the same
          if matching then
            for k, group in pairs(block1.groups) do
              if group.otype ~= block2.groups[k].otype or group.f_start ~= block2.groups[k].f_start or group.f_end ~= block2.groups[k].f_end then
                matching = false
                break
              end
            end
          end

          -- If they are matching and should be processed, do the following
          if matching and process then
            -- Adds these to show that they've been processed
            table.insert(merged_indices, i)
            table.insert(merged_indices, j)

            -- Create a copy of block 1
            block1copy = deep_copy(block1)

            -- Merge the two blocks by start and end
            if block1.d_start > block2.d_start then
              block1copy.d_end = block2.d_end
            else
              block1copy.d_start = block2.d_start
            end

            -- Add them to the merged blocks table
            table.insert(merged_dist_blocks, block1copy)
          elseif process then

            -- Add them to the normalised list to show that they've been processed
            table.insert(merged_indices, i)
            table.insert(merged_indices, j)
            table.insert(normalised_dist_blocks, block1)
            table.insert(normalised_dist_blocks, block2)
          end

        end
      end

      -- Add the merged blocks to the normalised list
      for _, merged_dist_block in ipairs(merged_dist_blocks) do
        table.insert(normalised_dist_blocks, merged_dist_block)
      end

      -- Sorts the normalised list
      table.sort(normalised_dist_blocks, function(a, b)
        return a.d_start > b.d_start
      end)

      -- If there are missing pixel distances, extend blocks to fill the gaps
      for i, block in ipairs(normalised_dist_blocks) do
        if i > 1 then
          if normalised_dist_blocks[i - 1].d_end ~= block.d_start + 1 then
            block.d_start = normalised_dist_blocks[i - 1].d_end - 1
          end
        end
      end

      local block_num = 1
      for _, block in ipairs(dist_blocks) do
        -- Distance header
        local dist_str
        if block.d_start == block.d_end then
          dist_str = "Distance of " .. block.d_start .. " pixels:"
        else
          dist_str = "Distance of " .. block.d_start .. "~" .. block.d_end .. " pixels:"
        end
        out:write("    " .. block_num .. ") " .. dist_str .. "\n\n")
        block_num = block_num + 1

        -- Build output lines for this block
        local out_lines = {}
        for _, g in ipairs(block.groups) do
          -- flip_sign: negate both values and swap start/end
          local f1, f2
          if reverse_lines then
            -- P2 perspective: swap raw values (negating Yun's flipped values)
            f1 = g.f_end
            f2 = g.f_start
          else
            -- P1 perspective: negate raw values, bigger first
            f1 = flip_f(g.f_start)
            f2 = flip_f(g.f_end)
          end
          local otype = g.otype
          if flip_outcome then
            if otype == "wins" then otype = "loses"
            elseif otype == "loses" then otype = "wins" end
          end
          table.insert(out_lines, {f1=f1, f2=f2, otype=otype})
        end

        if reverse_lines then
          local reversed = {}
          for i = #out_lines, 1, -1 do
            table.insert(reversed, out_lines[i])
          end
          out_lines = reversed
        end

        -- Calculate max range string width for alignment
        local max_width = 0
        for _, l in ipairs(out_lines) do
          local s
          if l.f1 == l.f2 then s = "At " .. fmt_f(l.f1) .. ","
          else s = "At " .. fmt_f(l.f1) .. "~" .. fmt_f(l.f2) .. "," end
          if #s > max_width then max_width = #s end
        end
        max_width = max_width + 2

        for _, l in ipairs(out_lines) do
          out:write("        " .. fmt_range(l.f1, l.f2, max_width) .. " " .. attacker .. " " .. l.otype .. "\n")
        end
        out:write("\n")
      end

      out:close()
      print("Written: " .. filename)
    end

    -- Build folder paths and filenames
    local p1_attack = move_name(p1_press, p1_press_dirs)
    local p2_attack = move_name(p2_press, p2_press_dirs)

    local p1_folder = p1_char .. "\\vs " .. p2_char .. "\\" .. p1_attack
    local p2_folder = p2_char .. "\\vs " .. p1_char .. "\\" .. p2_attack

    ensure_dir(p1_char)
    ensure_dir(p1_char .. "\\vs " .. p2_char)
    ensure_dir(p1_folder)
    ensure_dir(p2_char)
    ensure_dir(p2_char .. "\\vs " .. p1_char)
    ensure_dir(p2_folder)

    local p1_filename = p1_folder .. "\\" .. p1_move .. " vs " .. p2_move .. ".txt"
    local p2_filename = p2_folder .. "\\" .. p2_move .. " vs " .. p1_move .. ".txt"

    -- P1 perspective: flip signs, no outcome flip, no line reversal
    write_file(p1_filename, p1_move .. " vs " .. p2_move, p1_move, false, true, false)

    -- P2 perspective: flip signs, flip outcome, reverse lines
    write_file(p2_filename, p2_move .. " vs " .. p1_move, p2_move, true, true, true)

    end
    end

end

emu.speedmode("normal")

print("Outcomes have been exported")