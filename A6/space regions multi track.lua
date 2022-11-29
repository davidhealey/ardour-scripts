ardour {
	["type"]    = "EditorAction",
	name        = "Space Regions",
	license     = "MIT",
	author      = "David Healey",
	description = [[Separate selected regions by a specified time interval - works across tracks]]
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

			-- MAIN
			local sel = Editor:get_selection () -- get current selection
			local sel_regions = sel.regions:regionlist()
			local last_r
			local last_pos
			local last_length

			-- prompt settings
    	local dialog_options = {{type="number", key="interval", title="Interval (Sec)", min=1, max=30, step=1, digits=1, default=3}}

			-- prompt user for interval
  		local od = LuaDialog.Dialog ("Space Regions", dialog_options)
  		local rv = od:run()

			local add_undo = false -- keep track of changes
			Session:begin_reversible_command ("Space Regions")

			--Dialog response
  		if (rv) then

				-- iterate over all tracks in the session
				for route in Session:get_routes():iter() do

					local track = route:to_track ()
					if track:isnil () then goto continue end

					-- get track's playlist
					local playlist = track:playlist ()
          
          -- get region list
					local rl = playlist:region_list()

					-- reset for each track
					last_r = nil
					
					-- iterate over each region on track
					for r in rl:iter() do

						if is_selected(r, sel_regions) then -- if region is selected

	   		      -- preare for undo operation
              r:to_stateful():clear_changes()

							if last_r then
								last_pos = last_r:position() -- get timeline position of last region
								last_length = last_r:length() -- get length of last region
								r:set_position(last_pos + last_length + (rv["interval"] * Session:nominal_sample_rate()), 0)
							end
							last_r = r
						end

						-- create a diff of the performed work, add it to the session's undo stack
						-- and check if it is not empty
						if not Session:add_stateful_diff_command (r:to_statefuldestructible()):empty () then
							add_undo = true
						end

					end
					::continue::
				end
  		end

    	od=nil
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
