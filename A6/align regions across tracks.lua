ardour {
	["type"]    = "EditorAction",
	name        = "Align Regions Across Tracks",
	license     = "MIT",
	author      = "David Healey",
	description = [[Aligns the selected regions across tracks]]
}

function factory ()
    return function ()

      local sr = Session:nominal_sample_rate()
			local sel = Editor:get_selection ()
			local rl = sel.regions:regionlist()
			local last_r
			local last_pos
			local last_length

      -- FUNCTIONS --

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

      -- sort regions by position
      function sortByPosition(a, b)
        return a:position() < b:position()
      end

			-- MAIN --

			local add_undo = false -- keep track of changes
			Session:begin_reversible_command ("Align Regions")

      -- sort regions on each track
			local sorted = {}
			local playlists = {}
			for key, r in pairs(rl:table ()) do
			  
			  local playlist = r:playlist ()
			  
			  if sorted[playlist:name ()] == nil then
			    sorted[playlist: name()] = {}
			    table.insert(playlists, playlist)
			  end
			  
			  table.insert(sorted[playlist:name ()], r)
			end	  
			
			for i = 1, #playlists, 1 do
        table.sort(sorted[playlists[i]:name ()], sortByPosition)
			end
      
      -- got through each playlist and arrange regions based on position of first playlist
      
      local master = sorted[playlists[1]:name ()] -- first playlist's regions
      for i = 2, #playlists, 1 do
        
        regions = sorted[playlists[i]:name ()]
        
        for j = 1, #regions, 1 do
          
          if master[j] == nil then break end
          
          -- preare for undo operation
          regions[j]:to_stateful():clear_changes()
              
          regions[j]:set_position(master[j]:position(), 0)
          
					-- create a diff of the performed work, add it to the session's undo stack and check if it is not empty
					if not Session:add_stateful_diff_command (regions[j]:to_statefuldestructible()):empty () then
						add_undo = true
					end
          
        end
        
      end

			collectgarbage()

			-- all done, commit the combined Undo Operation
			if add_undo then
				-- the 'nil' Command here mean to use the collected diffs added above
				Session:commit_reversible_command(nil)
			else
				Session:abort_reversible_command()
			end

    end
end
