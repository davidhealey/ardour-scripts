ardour {
	["type"]    = "EditorAction",
	name        = "AM Pitchshift Up (Playhead Region)",
	license     = "MIT",
	author      = "David Healey",
	description = [[Increase AM pitch shifter automation points by 0.001, must be on first track]]
}

function factory () 
  return function ()
	
    local sr = Session:nominal_sample_rate()

	  -- prepare undo operation
    local add_undo = false -- keep track if something has changed
    Session:begin_reversible_command ("AM Pitch Shifter")
	      
		-- get first track
		local route = Session:get_remote_nth_route(0)
		assert (not route:isnil ())
  	
		--Look for the rubber band plugin in the first 5 plugin slots
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
    	
		assert(plugin, "AM Pitchshifter not found")
  	
  	function getRegionAtCursor()
  	  
  	  local cf = Session:transport_sample() -- playhead position

      local t = route:to_track ()
        
      -- get track's playlist
      local playlist = t:playlist ()
                       
      -- get region list
      local rl = playlist:region_list()
   	  
  	  for r in rl:iter () do
  	    
        local pos = r:position ()
        local len = r:length ()

        if cf >= pos and cf <= pos + len then
  	     return r
  	    end
  	  end
  	  
  	  return nil
 
    end
  	  	
    -- get AutomationList, ControlList and ParameterDescriptor of the first plugin's first parameter (cents)
    local al, cl, pd = ARDOUR.LuaAPI.plugin_automation (plugin, 2)

    if cl:events ():size () ~= 0 then
      
      if not al:isnil () then
      
        local region = getRegionAtCursor();

        if region ~= nil then                
          
          local before = al:get_state ()

          for e in cl:events ():iter () do
          
            local ts = e.when;
            local v = e.value;
            
            if ts >= region:position () - 0.05 * sr and ts <= region:position () + region:length () + 0.05 * sr then
              cl:add(ts, v + 3, false, false) 
            end
            
          end

          -- save undo
          local after = al:get_state ()
          Session:add_command (al:memento_command (before, after))
          add_undo = true

        end       
      end     
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