ardour {
	["type"]    = "EditorAction",
	name        = "Pitch To Region Name (Aubio)",
	license     = "MIT",
	author      = "David Healey",
	description = [[Get pitch note of selected regions and set as region names]]
}

function factory ()
  return function ()

    -- GLOBALS --
    local sr = Session:nominal_sample_rate ()
    local sel = Editor:get_selection ()
  	local sel_regions = sel.regions:regionlist ()
	
  	--Using aubrio pitch detection vamp plugin
  	local vamp = ARDOUR.LuaAPI.Vamp("vamp-aubio:aubiopitch", sr)

    -- FUNCTIONS --
    function round(n)
      return n + 0.5 - (n + 0.5) % 1
    end

   function mean( t )
      local sum = 0
      local count = 0

      if #t > 0 then
        for k, v in pairs(t) do
          if type(v) == 'number' then
            sum = sum + v
            count = count + 1
          end
        end

        return (sum / count)
      else
        return nil
      end
    end
    
    function median( t )
      local temp={}

      -- deep copy table so that when we sort it, the original is unchanged
      -- also weed out any non numbers
      for k,v in pairs(t) do
        if type(v) == 'number' then
          table.insert( temp, v )
        end
      end

      table.sort( temp )

      -- If we have an even number of table elements or odd.
      if math.fmod(#temp,2) == 0 and temp[#temp/2] ~= nil then
        -- return mean value of middle two elements
        return ( temp[#temp/2] + temp[(#temp/2)+1] ) / 2
      else
        -- return middle element
        return temp[math.ceil(#temp/2)]
      end

    end

    function freqToPitch (f)
      local notes = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
      local a = 440 -- A3 Frequency
      local aMidi = 69 -- A3 MIDI note number
      local h = round (12 * math.log (f/a)/math.log (2)) -- Number of half-steps from A
      local m = aMidi + h -- Get the MIDI note number

      return notes[(m % 12)+1] .. math.floor ((m/12)-2) -- Return note name and octave
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
			
  		-- get remaining features
  		callback (vamp:plugin ():getRemainingFeatures ())

  		return freqs
  	  
    end
    
    -- MAIN --
    
    -- prepare undo operation
    local add_undo = false -- keep track if something has changed
  	Session:begin_reversible_command ("Pitch to Region Name")
    
    -- variable for progress dialog
    local pdialog
    
    -- setup dialog
  	local dialog_options = {
    	{type = "dropdown", key = "pitchtype", title = "Pitch Detection Method", values = {["YIN"]=0, ["Spectral"]=1, ["Schmitt"]=2, ["Fast Harmonic"]=3, ["YIN + FFT"]=4}, default="Fast Harmonic"},
    	{type = "number", key = "minfreq", title = "Minimum Fundamental Frequency (Hz)", min = 1, max = sr/2, default = 50},
    	{type = "number", key = "maxfreq", title = "Maximum Fundamental Frequency (Hz)", min = 1, max = sr/2, default = 2500},
      {type = "radio", key = "wraprange", title = "Octave wrapping", values = {["Yes"] = 1, ["No"] = 0}, default = "Yes"},
      {type = "slider", key = "silencethreshold", title = "Silence Threshold (dB)", min = -120, max = 0, default = -75},
      {type = "slider", key = "length", title = "Analysis Length (%)", min = 0, max = 100, default = 45},
      {type = "radio", key = "averaging", title = "Averaging Method", values = {["Mean"] = 0, ["Median"] = 1}, default = "Mean"}
  	}
  	
  	-- show dialog
    local od = LuaDialog.Dialog ("Pitch to Region Name", dialog_options)
    local rv = od:run ()
  	
    if rv then
      vamp:plugin ():setParameter ("pitchtype", rv.pitchtype)
      vamp:plugin ():setParameter ("minfreq", rv.minfreq)
      vamp:plugin ():setParameter ("maxfreq", rv.maxfreq)
      vamp:plugin ():setParameter ("wraprange", rv.wraprange)
      vamp:plugin ():setParameter ("silencethreshold", rv.silencethreshold)
	
      pdialog = LuaDialog.ProgressWindow ("Pitch to Region Name", true)
      
      --Each selected region
  		for i, r in ipairs (sel_regions:table ()) do     

				-- Update progress
				if pdialog:progress (i / sel_regions:size (), i .. "/" .. sel_regions:size ()) then
					break
				end

        -- Test if it's an audio region
        if r:to_audioregion ():isnil () then goto next end       
 				
        -- preare for undo operation
        r:to_stateful ():clear_changes ()

        -- analyze region and get table of detected frequencies
        local frequencies = analyzeRegion (r, rv.length)
            
        -- get average frequency
        local avg
        
        if rv.averaging == 0 then
          avg = mean (frequencies)
        else
          avg = median (frequencies)
        end
        
        -- variable to store region name text
        local name = "Unable to determine pitch"
        
        -- if avg is nan then region is probably unpitched
        if avg ~= nil and type(avg) == "number" then
          name = freqToPitch (avg) -- convert frequency to note name + octave string
        end
        
        -- set rename region
        r:set_name(name)

        -- save changes (if any) to undo command
  			if not Session:add_stateful_diff_command (r:to_statefuldestructible ()):empty () then
  				add_undo = true
  			end

  			::next::
		
  		end
		end

		od = nil
		collectgarbage ()
		
  	-- all done. now commit the combined undo operation
  	if add_undo then
  		-- the 'nil' command here means to use all collected diffs
  		Session:commit_reversible_command (nil)
  	else
  		Session:abort_reversible_command ()
  	end
  	
		-- hide modal progress dialog and destroy it
		if pdialog ~= nil then
      pdialog:done ()
		end

  end
end