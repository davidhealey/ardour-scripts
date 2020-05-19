ardour {
	["type"]    = "EditorAction",
	name        = "Rubberband AutoTune",
	license     = "MIT",
	author      = "David Healey",
	description = [[Automatically adds automation data for a pitch shifter plugin to create an auto-tune effect.]]
}
function factory () return function () 
  
  local sel = Editor:get_selection ()
  local rl = sel.regions:regionlist ()
	local sr = Session:nominal_sample_rate ()	
	local vamp = ARDOUR.LuaAPI.Vamp("libardourvamppyin:pyin", sr)
  vamp:plugin():setParameter ("lowampsuppression", 0.0) -- Don't supress low amplitude estimates  	
	
	local automationIndex = 1
	local useSemiTones = false
  
	-- prepare undo operation
	local add_undo = false -- keep track if something has changed
	Session:begin_reversible_command ("Rubberband AutoTune")
  
	-- get first track
	local route = Session:get_remote_nth_route(0)
	assert (not route:isnil (), "Invalid first track")
    
  --Look for the plugin in the first 5 plugin slots
	local plugin
	for i = 0, 6, 1 do
     plugin = route:nth_plugin(i):to_insert();
         
     if plugin and plugin:isnil() == false then
       local name = plugin:display_name()

       if name == "Rubberband (Mono)" or name == "Rubber Band Mono Pitch Shifter" then
         break
       else
        plugin = nil
       end
           
     end
  end
	
	assert(plugin, "Plugin not found")  
  
  --FUNCTIONS--            
  function freqToCentsOffset(f)

  	local lnote = (math.log(f) - math.log(440)) / math.log(2) + 4.0
  	local oct = math.floor(lnote)
  	  	
  	local cents = 1200 * (lnote - oct)
  	local noteNames = {"A", "A#", "B", "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#"}
    local note = ""
    
  	local offset = 50.0

  	if cents < 50 then
  		note = "A "
  	elseif cents >= 1150 then
  		note = "A "
  		cents = cents - 1200
  		oct = oct + 1;
  	else
  		for i = 1, 11, 1 do
  			if cents >= offset and cents < offset + 100 then
  				note = noteNames[i+1]
  				cents = cents - (i * 100)
  				break
  			end
  			offset = offset + 100
  		end
  	end
  	
  	--print(f, " - ", note .. oct) -- helpful when debugging
  	
  	if useSemiTones == true then
      return cents / 100
  	else
      return cents
  	end

  end 
  
  function addEnvelopePoints(f, data, r)
        
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
    
    -- one 10th of region's length - points will be spaced this distance apart
    local interval = r:length()/10
    
    -- calculate number of cents difference between f and closest note    
    local offset = freqToCentsOffset(f)
    
    cl:add(r:position() - 0.1 * sr, 0, false, false) -- add zero point
    
    cl:add(r:position() + 0.2 * sr, -offset, false, false) -- add first pitch point
    cl:clear(r:position(), r:position() - 1 + 0.2 * sr) -- clean up buggy guard points

    -- add the rest of the pitch points
    local lastPos = r:position() + 0.2 * sr
    local lastOffset
    for i, d in ipairs(data) do
      if d.timestamp > lastPos + interval and d.timestamp < r:position() + r:length() - 1.5 * sr then
        offset = freqToCentsOffset(d.value) -- get offset from frequency value
        cl:add(d.timestamp, -offset, false, false) -- add pitch point
        cl:clear(lastPos+1, d.timestamp-1) -- clean up buggy guard points
        lastPos = d.timestamp -- update last position
      end 
    end
    
    offset = freqToCentsOffset(f) -- get pitch offset from fixed frequency value
    cl:add(r:position() + r:length() - 0.3 * sr, -offset, false, false) -- add final pitch point
    cl:clear(lastPos+1, r:position() + r:length() - 1 + 0.3 * sr) -- clean up buggy guard points    
    cl:add(r:position() + r:length() + 0.1 * sr, 0, false, false) -- add zero point
    cl:clear(r:position() + r:length() - 0.3 * sr, r:position() + r:length() - 1 + 0.1 * sr) -- clean up buggy guard points
    
		-- get state for undo
		local after = al:get_state ()
    Session:add_command (al:memento_command (before, after))
    add_undo = true
  end    
  
  --MAIN-- 
				
  --Each selected region
	for r in rl:iter () do
 	
 	  local freq = nil
 	  local data = {}
 	
    -- Test if it's an audio region
    if r:to_audioregion ():isnil () then goto continue end
 	
 		-- callback to handle Vamp-Plugin analysis results
		function callback (feats)
									
			if feats and feats:size() > 0 then
			  
			  local f = feats:table()[0]:table()[1] -- frequency candidates
			  local p = feats:table()[1]:table()[1] -- probabilities
        
        local ts = Vamp.RealTime.realTime2Frame (f.timestamp, sr)
        
        local d = {["timestamp"]=r:position()+ts, ["value"]=0, ["probability"]=0.2} 
        -- get f candidates with highest probability        
        for i, v in ipairs(p.values:table()) do -- each probability
        
          if v > d.probability then
            d.value = f.values:table()[i]
            d.probability = v
          end
        end
        
        -- probability must be higher than 0.2 to be included
        if d.probability > 0.2 then
          table.insert(data, d)
        end
			end
			return false
		end
 	
 		vamp:analyze (r:to_readable (), 0, callback)

		-- get remaining features (end of analyis)
    local feats = vamp:plugin():getRemainingFeatures()
		local fl = feats:table()[5] --5 = frequency
		
		--If frequency value is returned
		if (fl and fl:size() > 0) then
			freq = fl:at(0).values:at(0) -- store frequency of region
			addEnvelopePoints(freq, data, r)
    end

		-- reset the plugin (prepare for next iteration)
		vamp:reset ()
		    
    ::continue::
    
  end
  
	-- all done, commit the combined Undo Operation
	if add_undo then
		-- the 'nil' Commend here mean to use the collected diffs added above
		Session:commit_reversible_command (nil)
	else
		Session:abort_reversible_command ()
	end

end end