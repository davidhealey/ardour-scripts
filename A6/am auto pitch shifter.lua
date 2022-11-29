ardour {
	["type"]    = "EditorAction",
	name        = "AM Pitch Shift",
	license     = "MIT",
	author      = "David Healey",
	description = [[Automatically adds automation data for a pitch shifter plugin to correct sample tuning.]]
}
function factory () return function ()

  local sel = Editor:get_selection()
  local rl = sel.regions:regionlist()
	local sr = Session:nominal_sample_rate()

  local vamp = ARDOUR.LuaAPI.Vamp("vamp-aubio:aubiopitch", sr)

	local automationIndex = 2 -- pitch in cents

	-- prepare undo operation
	local add_undo = false -- keep track if something has changed
	Session:begin_reversible_command ("Auto Pitch Shift")

	-- get first track
	local route = Session:get_remote_nth_route(0)
	assert (not route:isnil (), "Invalid first track")

	--Look for the AM Pitch shifter plugin in the first 5 plugin slots
	local plugin
	for i = 0, 6, 1 do
     plugin = route:nth_plugin(i):to_insert();

     if plugin then
       local name = plugin:display_name()
           
       if name == "AM pitchshifter" then
         break
       else
        plugin = nil
       end   
     end
  end
  
  assert(plugin, "AM Pitch Shifter not found")

  --FUNCTIONS-- 
  function round(n)
    return n + 0.5 - (n + 0.5) % 1
  end

 function mean( t )
    local sum = 0
    local count= 0

    for k,v in pairs(t) do
      if type(v) == 'number' then
        sum = sum + v
        count = count + 1
      end
    end

    return (sum / count)
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
      return round(math.log(ratio) / math.log(2) * 1200) 
        
  end
  
	function analyzeRegion(r, length)

		-- place to gather detected frequencies
		local freqs = {};
      
		function callback(data, ts)

      if data:table()[0] ~= nil and ts ~= nil and ts < r:length () * length / 100 then
 
        for i, f in ipairs(data:table()[0]:table()) do
            
          local value = f.values:table()[1] -- extract frequency value
          table.insert(freqs, value)
          
        end
      end
  	  
		end

    -- Run the plugin
		vamp:analyze (r:to_readable (), 0, callback)

    -- reset for next region
		vamp:reset ()

		return freqs
  	  
  end

  function addEnvelopePoints(offset, r)

   -- get AutomationList, ControlList and ParameterDescriptor of the first plugin's first parameter (cents)
    local al, cl, pd = ARDOUR.LuaAPI.plugin_automation (plugin, automationIndex)

		-- get state for undo
		local before = al:get_state ()

    -- if there are no events aready add one at the begining
    if cl:events():size() == 0 then
      cl:add(0, 1, false, false)
    end

    -- add automation points
    local pos = r:position()
    local len = r:length()

    cl:clear(pos - 0.1 * sr, pos + len + 0.1 * sr) -- remove old points for region
        
    -- add zero point
    cl:editor_add (pos - 0.1 * sr, 0, false)

    cl:editor_add(pos - 0.05 * sr, offset, false)

    cl:editor_add(pos + len + 0.05 * sr, offset, false)

    cl:editor_add(pos + len + 0.1 * sr, 0, false)

		-- get state for undo
		local after = al:get_state ()
    Session:add_command (al:memento_command (before, after))
    add_undo = true
  end

  --MAIN--

  -- setup dialog
	local dialog_options = {
		{type = "dropdown", key = "pitchtype", title = "Pitch Detection Method", values = {["YIN"]=0, ["Spectral"]=1, ["Schmitt"]=2, ["Fast Harmonic"]=3, ["YIN + FFT"]=4}, default="YIN + FFT"},
		{type = "number", key = "minfreq", title = "Minimum Fundamental Frequency (Hz)", min = 1, max = sr/2, default = 30},
		{type = "number", key = "maxfreq", title = "Maximum Fundamental Frequency (Hz)", min = 1, max = sr/2, default = 1500},
    {type = "radio", key = "wraprange", title = "Octave wrapping", values = {["Yes"] = 1, ["No"] = 0}, default = "No"},
    {type = "slider", key = "silencethreshold", title = "Silence Threshold (dB)", min = -120, max = 0, default = -90},
    {type = "slider", key = "length", title = "Analysis Length (%)", min = 0, max = 100, default = 25},
	}

 	local od = LuaDialog.Dialog ("Auto Pitch Shift", dialog_options)
  local rv = od:run ()

  -- progress dialog  
  local pdialog = LuaDialog.ProgressWindow ("Auto Pitch Shift", true)
	
	if rv then
    
    vamp:plugin ():setParameter ("pitchtype", rv.pitchtype)
    vamp:plugin ():setParameter ("minfreq", rv.minfreq)
    vamp:plugin ():setParameter ("maxfreq", rv.maxfreq)
    vamp:plugin ():setParameter ("wraprange", rv.wraprange)
    vamp:plugin ():setParameter ("silencethreshold", rv.silencethreshold)

    --Each selected region
  	for i, r in ipairs (rl:table ()) do

  		-- Update progress
  		if pdialog:progress (i / rl:size (), i .. "/" .. rl:size ()) then
  			break
  		end

      -- Test if it's an audio region
      if r:to_audioregion ():isnil () then goto continue end

      -- analyze region and get table of detected frequencies
      local frequencies = analyzeRegion (r, rv.length)
            
      -- get average frequency
      local avg = mean (frequencies)

  		--If frequency value is returned
  		if avg ~= nil and type(avg) == "number" then
        local offset = getOffset(avg) -- calculate number of cents difference between avg and closest note
  			addEnvelopePoints(offset, r)
      end

  		-- reset the plugin (prepare for next iteration)
  		vamp:reset ()

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
