ardour {
	["type"]    = "EditorAction",
	name        = "Sort Regions by Pitch in Name - multi-track",
	license     = "MIT",
	author      = "David Healey",
	description = [[Sorts the selected regions by pitch (in their name) along the timeline]]
}

function factory ()
  return function ()

		-- check if the region is in the selected regions table
			function is_selected(r, selected)
					local result = false
					for s in selected:iter() do
						if (s == r) then
							result = true
							break
						end
					end
					return result
			end

    -- return true if route "a" should be ordered before route "b"
    function rsort (a, b)
  	    	  
      local notes = {["C"]=1, ["C#"]=2, ["D"]=3, ["D#"]=4, ["E"]=5, ["F"]=6, ["F#"]=7, ["G"]=8, ["G#"]=9, ["A"]=10, ["A#"]=11, ["B"]=12}
  	    	  
  	  -- get region names
  	  local n1 = a:name()
  	  local n2 = b:name()
  	    	  
      local l = {string.match(n1,"%D+"), string.match(n2,"%D+")} -- note letter + accidental (if any) 
      local o = {string.match(n1,"%d+"), string.match(n2,"%d+")} -- octave number
  	  
  	  -- Move invalid values to the end of the table
  	  if not notes[l[1]] then
        return false
      elseif not notes[l[2]] then
        return true
      end
  	  
  	  if o[1] and o[2] and notes[l[1]] and notes[l[2]] then -- skip nil values  	    
        if o[1] > o[2] then
          return false
        elseif o[2] > o[1] then
          return true
        else -- if the octave is the same for both
          if notes[l[1]] < notes[l[2]] then
            return true
          end
        end
      end
           
      return false
  	  
    end

    local sel = Editor:get_selection ()
    local sel_regions = sel.regions:regionlist()

		local add_undo = false -- keep track of changes
    Session:begin_reversible_command ("Sort by pitch")

    -- Reposition regions, space 1 second apart
    local last_r -- The previous iterated region
    local last_pos
    local last_length 
      
    -- iterate over all tracks in the session
    for route in Session:get_routes():iter() do
        
      local t = route:to_track ()
      if t:isnil () then goto continue end
        
      -- get track's playlist
      local playlist = t:playlist ()
                       
      -- get region list
      local rl = playlist:region_list()
        
      -- Sort selected regions by pitch in name
      local sorted = {}
      local start = nil -- position of left most pre-selected region    	
      for r in rl:iter() do
    		    		
        if is_selected(r, sel_regions) then -- if region is selected
          table.insert(sorted, r)
    		
          --Check if position of this region is further to the left, is so update start
          if start == nil or r:position() < start then
						start = r:position()
          end
				end  		
      end
    	
      table.sort(sorted, rsort) -- sort the list using the compare function 
        
      -- reset for each track
      last_r = nil
        
       -- reposition the sorted regions on the timeline
      for i, r in ipairs(sorted) do
	  
	      -- preare for undo operation
        r:to_stateful():clear_changes()
	  
        if last_r then
          last_pos = last_r:position()
          last_length = last_r:length()
          r:set_position(last_pos + last_length +  Session:nominal_sample_rate(), 0)
				else
          r:set_position(start, 0)
        end
	  
        last_r = r
	  	  
  			-- create a diff of the performed work, add it to the session's undo stack and check if it is not empty
  			if not Session:add_stateful_diff_command (r:to_statefuldestructible()):empty() then
  				add_undo = true
  			end
	  	  
      end
        
      ::continue::
        
    end
   
  	-- drop all region references
		sorted = nil
		collectgarbage ()
	
		-- all done, commit the combined Undo Operation
		if add_undo then
			-- the 'nil' Command here mean to use the collected diffs added above
      Session:commit_reversible_command(nil)
		else
			Session:abort_reversible_command()
		end
			
  end
end