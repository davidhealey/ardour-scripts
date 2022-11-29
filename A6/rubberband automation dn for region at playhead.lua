ardour {
	["type"]    = "EditorAction",
	name        = "Rubberband - 5 cents (Playhead Region)",
	license     = "MIT",
	author      = "David Healey",
	description = [[Add - 5 cents by automation points to Rubberband Pitch shift, must be on first track]]
}

function factory () 
  return function ()

    local sr = Session:nominal_sample_rate ()
	  local cf = Session:transport_sample() -- playhead position	
	
	  -- prepare undo operation
    local add_undo = false -- keep track if something has changed
    Session:begin_reversible_command ("Rubberband -5 cents")
	      
		-- get first track
		local route = Session:get_remote_nth_route(0)
		assert (not route:isnil ())
  	
		--Look for the rubber band plugin in the first 5 plugin slots
		local plugin
		for i = 0, 6, 1 do
       plugin = route:nth_plugin(i):to_insert();
         
       if plugin then
         local name = plugin:display_name()
           
         if name == "Rubberband (Mono)" or name == "Rubber Band Stereo Pitch Shifter" then
           break
         else
          plugin = nil
         end
           
       end        
         
    end
    	
		assert(plugin, "Rubberband not found")
  	  	
    -- get AutomationList, ControlList and ParameterDescriptor of the first plugin's first parameter (cents)
    local al, cl, pd = ARDOUR.LuaAPI.plugin_automation (plugin, 1)
      
    -- if there are no events aready add one at the begining
    if cl:events():size() == 0 then
      cl:add(0, 0, false, false)
    end
            
    -- organise existing events by time/position 
    local events = {}      
    for e in cl:events():iter() do
      events[e.when] = e
    end
      
    if not al:isnil () then
        
      local t = route:to_track ()
        
      -- get track's playlist
      local playlist = t:playlist ()
                       
      -- get region list
      local rl = playlist:region_list()
          
			-- get state for undo
			local before = al:get_state ()
          
      for r in rl:iter() do
            
        local pos = r:position() -- start of region
        local len = r:length() -- length of region
        
        if cf >= pos and cf <= pos + len then
                
          -- check if there is already an event at the start of the region
          if events[pos] then
            local current = events[pos].value -- value of current automation point           
            cl:add(pos, current - 5, false, false)
            cl:add(pos + len, current - 5, false, false)
            cl:clear(pos + 1, pos + len - 1)
          else -- add new events
           
            cl:clear(pos + 1, pos + len - 1) -- remove old points for region
          
            cl:add(pos - 0.1 * sr, 0, false, false)
            cl:add(pos, -5, false, false)
            cl:clear(pos + 1 - 0.1 * sr, pos - 1)
            
            cl:add(pos + len, -5, false, false)
            cl:clear(pos + 1, pos + len - 1)
            
            cl:add(pos + len + 0.1 * sr, 0, false, false)
            cl:clear(pos + len + 1, pos + len - 1 + 0.1 * sr)
            
          end        
              
        end
            
      end
      
      -- save undo
      local after = al:get_state ()
      Session:add_command (al:memento_command (before, after))
      add_undo = true
        
    end

		-- all done, commit the combined Undo Operation
		if add_undo then
			-- the 'nil' Commend here mean to use the collected diffs added above
			Session:commit_reversible_command (nil)
		else
			Session:abort_reversible_command ()
		end

  end
end