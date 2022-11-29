ardour {
	["type"]    = "EditorAction",
	name        = "Space Regions Single Track",
	license     = "MIT",
	author      = "David Healey",
	description = [[Separate selected regions by a specified time interval - for use with single track]]
}

function factory ()
    return function ()

      -- Sorts regions by position, left to right
      function sortByPosition (a, b)
        return a:position () < b:position ()        
      end
			
      local sel = Editor:get_selection ()
      local rl = sel.regions:regionlist ()

      if rl:size () > 0 then
                
      	-- prompt settings
      	local dialog_options = {{type="number", key="interval", title="Interval (Sec)", min=1, max=30, step=1, digits=1, default=3}}

  			-- prompt user for interval
    		local od = LuaDialog.Dialog ("Space Regions", dialog_options)
    		local rv = od:run ()

        -- undo stuff
  			local add_undo = false
  			Session:begin_reversible_command ("Space Regions")

  			--Dialog response
    		if (rv) then
    		  
          --Sort regions by position
          local sorted = {}
          for r in rl:iter () do
      		  table.insert (sorted, r)    		    		
      	  end
        
          table.sort(sorted, sortByPosition)
    		  
    		  -- Reposition regionds
    			local last_r -- previous iterated region
      		local last_pos -- position of previous region
			    local last_length -- length of previous region

    		  for i, r in ipairs (sorted) do
    	
    			  -- preare for undo operation
            r:to_stateful ():clear_changes ()
												
            if last_r then
							last_pos = last_r:position () -- get timeline position of last region
							last_length = last_r:length () -- get length of last region

							local offset = last_length + Temporal.timecnt_t(rv["interval"] * Session:nominal_sample_rate ())
              r:set_position(last_pos + offset)
            end

            last_r = r

  					-- create a diff of the performed work, add it to the session's undo stack
  					if not Session:add_stateful_diff_command (r:to_statefuldestructible ()):empty () then
  						add_undo = true
  					end
            
    		  end
    		  
    		end
      end
  
    	od = nil
    	rl = nil
			collectgarbage ()

			-- all done, commit the combined Undo Operation
			if add_undo then
				-- the 'nil' Command here mean to use the collected diffs added above
				Session:commit_reversible_command (nil)
			else
				Session:abort_reversible_command ()
			end

    end
end
