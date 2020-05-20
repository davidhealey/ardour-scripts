ardour {
	["type"]    = "EditorAction",
	name        = "X42 Pitch Shifter AutoTune (Aubio)",
	license     = "MIT",
	author      = "David Healey",
	description = [[Automatically adds automation data for a pitch shifter plugin to create an auto-tune effect.]]
}
function factory () return function () 
  
  -- GLOBALS --
  local sr = Session:nominal_sample_rate ()
  local sel = Editor:get_selection ()
	local rl = sel.regions:regionlist ()
	
	--Using aubrio pitch detection vamp plugin
	local vamp = ARDOUR.LuaAPI.Vamp("vamp-aubio:aubiopitch", sr)
	
	local automationIndex = 6 -- pitch in semitones
  
	-- prepare undo operation
	local add_undo = false -- keep track if something has changed
	Session:begin_reversible_command ("Pitch Shifter AutoTune")
  
	-- get first track
	local route = Session:get_remote_nth_route(0)
	assert (not route:isnil (), "Invalid first track")
    
  local plugin --populated by dropdown menu selection
    
	--Look for the x42-Autotune plugin in the first 5 plugin slots
	local plugin
	for i = 0, 6, 1 do
     plugin = route:nth_plugin(i):to_insert();

     if plugin then
       local name = plugin:display_name()

       if name == "x42-Autotune" then
         break
       else
        plugin = nil
       end   
     end
  end
  
	assert(plugin, "x42-Autotune not found")

  --FUNCTIONS--   
  function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
  end
  
  function pow(b, e)
    return b ^ e
  end

  function getOffset(f)
  
      -- convert to nearest midi note
      local pitch = round (69 + 12 * (math.log (f/440) / math.log (2.0)))
    
      -- convert to frequency
      local f2 = 440*pow (2, (pitch-69)/12)
    
      -- get the ratio of the difference between f and f2
      local ratio = f2 / f
    
      -- convert to cents and return
      return round(math.log(ratio) / math.log(2) * 1200) / 100
        
  end
  
  function addEnvelopePoints(data, r, n)
        
   -- get AutomationList, ControlList and ParameterDescriptor of the first plugin's first parameter (cents)
    local al, cl, pd = ARDOUR.LuaAPI.plugin_automation (plugin, automationIndex)

		-- get state for undo
		local before = al:get_state ()
      
    -- if there are no events aready add one at the begining
    if cl:events():size() == 0 then
      cl:add(0, 0, false, false)
    end
    
    -- remove old automation for the region
    cl:clear(r:position(), r:position() + r:length())
    
    -- add zero point
    cl:editor_add (r:position() - 0.1 * sr, 0, false)

    -- 1/nth of region's length - points will be spaced this distance apart - but clustered at the beginning
    local interval = r:length() / n

    -- add the rest of the pitch points
    local offset = 0
    local lastPos = r:position()
    local lastOffset = nil
    for i, d in ipairs(data) do
      if (d.timestamp > lastPos + interval or d.timestamp < r:position() + interval * 5) and d.timestamp < r:position() + r:length() - 1.5 * sr then        
          offset = getOffset(d.value) -- get offset from frequency value
          if offset ~= lastOffset and (offset < 50 and offset > -50) then
            cl:editor_add (d.timestamp, offset, false) -- add pitch point
            lastPos = d.timestamp -- update last position
            lastOffset = offset
        end
      end 
    end
    
    cl:editor_add(r:position() + r:length() - 0.3 * sr, offset, false) -- add final pitch point   
    cl:editor_add(r:position() + r:length() + 0.1 * sr, 0, false) -- add zero point
    
		-- get state for undo
		local after = al:get_state ()
    Session:add_command (al:memento_command (before, after))
    add_undo = true
  end
  
  function analyzeRegion(r)
  		
		-- place to gather detected frequencies and timestamps
		local data = {};
    local pos = r:position()

		function callback(fl, ts)
      
      if ts ~= nil then
        if fl:table()[0] ~= nil then
          for i, f in ipairs(fl:table()[0]:table()) do
            local d = {["timestamp"]=pos+ts, ["value"]=f.values:table ()[1]}
            table.insert(data, d) 
          end
        end
      end
		end

    -- Run the plugin
		vamp:analyze (r:to_readable (), 0, callback)
			
		-- get remaining features
		callback (vamp:plugin ():getRemainingFeatures ())
		
    -- reset for next region
		vamp:reset ()
			
		return data
  end
  
  
  --MAIN-- 
				
  -- setup dialog
	local dialog_options = {
		{type = "dropdown", key = "pitchtype", title = "Pitch Detection Method", values = {["YIN"]=0, ["Spectral"]=1, ["Schmitt"]=2, ["Fast Harmonic"]=3, ["YIN + FFT"]=4}, default="Fast Harmonic"},
		{type = "number", key = "minfreq", title = "Minimum Fundamental Frequency (Hz)", min = 1, max = sr/2, default = 40},
		{type = "number", key = "maxfreq", title = "Maximum Fundamental Frequency (Hz)", min = 1, max = sr/2, default = 2500},
    {type = "radio", key = "wraprange", title = "Octave wrapping", values = {["Yes"] = 1, ["No"] = 0}, default = "No"},
    {type = "slider", key = "silencethreshold", title = "Silence Threshold (dB)", min = -120, max = 0, default = -75},
    {type = "number", key = "interval", title = "Point spacing as fraction of region", min = 20, max = 100, default = 70},
	}

 	local od = LuaDialog.Dialog ("Pitch Shifter Autotune", dialog_options)
  local rv = od:run ()
	
  -- progress dialog  
  local pdialog = LuaDialog.ProgressWindow ("AM Auto Tune", true)
	
	if (rv) then		
    
    vamp:plugin ():setParameter ("pitchtype", rv.pitchtype)
    vamp:plugin ():setParameter ("minfreq", rv.minfreq)
    vamp:plugin ():setParameter ("maxfreq", rv.maxfreq)
    vamp:plugin ():setParameter ("wraprange", rv.wraprange)
    vamp:plugin ():setParameter ("silencethreshold", rv.silencethreshold)
				
    -- each selected region
    for i, r in ipairs (rl:table ()) do
 	
      -- Update progress
  		if pdialog:progress (i / rl:size (), i .. "/" .. rl:size ()) then
  			break
  		end
 	 	
      -- Test if it's an audio region
      if r:to_audioregion ():isnil () then goto continue end
 	   		
   		local result = analyzeRegion(r)
		
  		--If values are returned
  		if #result > 0 then
  			addEnvelopePoints(result, r, rv.interval)
  		end
		    
      ::continue::
    
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