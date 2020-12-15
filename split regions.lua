ardour {
	["type"]    = "EditorAction",
	name        = "Split Regions",
	license     = "MIT",
	author      = "David Healey",
	description = [[Split selected regions at note onsets]]
}

function factory () return function ()

  -- GLOBAL --
  local sr = Session:nominal_sample_rate ()
	local sel = Editor:get_selection () -- get current selection
	local rl = sel.regions:regionlist ()
	local vamp = ARDOUR.LuaAPI.Vamp("libardourvampplugins:amplitudefollower", sr)
	vamp:plugin (): initialise(1, 2048, 2048)
  local pdialog -- progress dialog

  -- get first track
	local route = Session:get_remote_nth_route(0)
	assert (not route:isnil (), "Invalid first track")
	
	local track = route:to_track ()
	
  -- get track's playlist
	local playlist = track:playlist ()

	local add_undo = false -- keep track of changes
  Session:begin_reversible_command ("Split Regions")

  -- FUNCTIONS --

  function analyzeRegion(r)
  		
		local result = {};

		function callback(fl, ts)      
      if ts ~= nil then
        if fl:table()[0] ~= nil then
          for i, f in ipairs(fl:table()[0]:table()) do
            local v = f.values:table()[1]
            local d = {["ts"]=ts, ["db"]=20 * math.log (v) / math.log(10)}
            table.insert(result, d)
          end
        end
      end
		end

    -- Run the plugin
		vamp:analyze (r:to_readable (), 0, callback)
		
    -- reset for next region
		vamp:reset ()

		return result
  end
  
  function splitRegion(region, peaks, threshold, precut)
    
    -- get split points
    local splits = {}
    local high = false
    
    for i = 1, #peaks, 1 do
      local ts = peaks[i].ts
      local db = peaks[i].db
      
      if db > threshold and high == false then
        table.insert(splits, ts)
        high = true
      elseif db < threshold then
        high = false
      end
    end
        
    -- make the splits
    for i, ts in pairs(splits) do

  		if pdialog:progress (i / #splits, "Processing " .. i .. "/" .. #splits) then
  			break
  		end

      local pos = region:position () + ts

      for region in playlist:regions_at(pos):iter () do
        playlist:split_region(region, ARDOUR.MusicSample (pos-precut, 0))
      end
    end

  end
  
  -- MAIN --
  
  -- setup dialog
  local dialog_options = {
		{type = "number", key = "threshold", title = "Silence Threshold (dB)", min = -120, max = 0, default = -60},
		{type = "number", key = "precut", title = "Precut, time before onset (ms)", min = 0, max = 1000, default = 250}
	}

	-- show dialog
  local od = LuaDialog.Dialog ("Split Regions", dialog_options)
  local rv = od:run ()
	
  if rv then
    
    pdialog = LuaDialog.ProgressWindow ("Split Regions", true)
       
    -- clear existing changes, prepare "diff" of state for undo
    playlist:to_stateful ():clear_changes ()

    -- analyze regions and store onsets indexed by playlist's track ID
    local onsets = {}
    for i, r in ipairs (rl:table ()) do
      
      -- Update progress
  		if pdialog:progress (i / rl:size (), "Analyzing Region " .. i .. "/" .. rl:size ()) then
  			break
  		end

      local peaks = analyzeRegion(r)
      splitRegion(r, peaks, rv.threshold, (rv.precut * sr) / 1000)

    end

    if not Session:add_stateful_diff_command (playlist:to_statefuldestructible ()):empty () then
			add_undo = true -- is something has changed, we need to save it at the end.
    end

	end
	
  od = nil
	collectgarbage ()
	
	-- all done, commit the combined Undo Operation
	if add_undo then
		-- the 'nil' Commend here mean to use the collected diffs added above
		Session:commit_reversible_command (nil)
	else
		Session:abort_reversible_command ()
	end
		
  -- hide modal progress dialog and destroy it
	if pdialog ~= nil then
    pdialog:done ()
	end
		
end end
