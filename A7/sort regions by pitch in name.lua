ardour {
	["type"]    = "EditorAction",
	name        = "Sort Regions by Pitch in Name",
	license     = "MIT",
	author      = "David Healey",
	description = [[Sorts the selected regions by pitch (in their name) along the timeline]]
}

function factory ()
  return function ()

		function sortByPosition (a, b)
			return a:position () < b:position ()        
		end

		function parse_note_and_octave(region_name)
			local note, octave = region_name:match("([A-G][#b]?)(%d+)")

			if octave then
				octave = tonumber(octave)
			end

 			return note, octave
		end
		
		-- Custom sort function to sort by note and octave
		local function compare_notes(a, b)
	    -- Get the note and octave for both region names
	    local note_a, octave_a = parse_note_and_octave(a)
	    local note_b, octave_b = parse_note_and_octave(b)	    
      local note_order = { ["C"] = 1, ["C#"] = 2, ["D"] = 3, ["D#"] = 4, ["E"] = 5, ["F"] = 6, ["F#"] = 7, ["G"] = 8, ["G#"] = 9, ["A"] = 10, ["A#"] = 11, ["B"] = 12 }

			-- Move invalid values to the end of the table
			if not note_order[note_a] or not octave_a then
				return false
			elseif not note_order[note_b] or not octave_b then
				return true;
			end
			
			if octave_a > octave_b then 
				return false
			elseif octave_b > octave_a then
				return true
			else -- Octave is the same for both 
				if note_order[note_a] < note_order[note_b] then
					return true
				end
			end
			
			return false
			
		end

    local sel = Editor:get_selection ()
    local rl = sel.regions:regionlist ()

		local add_undo = false -- keep track of changes
    Session:begin_reversible_command ("Sort by pitch")

		--Sort regions by position
		local regions_by_position = {}
		
		for r in rl:iter () do
			table.insert (regions_by_position, r)    		    		
		end

		table.sort(regions_by_position, sortByPosition)

    -- Organise regions by note in name
		local regions_by_name = {}
    local start = nil -- position of left most pre-selected region

    for i, r in ipairs (regions_by_position) do
			local name = r:name ()

			if regions_by_name[name] == nil then
				regions_by_name[name] = {}
			end

			table.insert(regions_by_name[name], r);

      --Check if position of this region is further to the left, if so update start
      if start == nil or r:position () < start then
				start = r:position ()
      end
    end

		-- Sort the region names (note names)
		local sorted_region_names = {}

		for name, _ in pairs(regions_by_name) do
		    table.insert(sorted_region_names, name)
		end

		table.sort(sorted_region_names, compare_notes)

    -- progress dialog
    local pdialog = LuaDialog.ProgressWindow ("Sort by Pitch", true)

		-- reposition the groups of regions on the timeline in order of name
    local last_r = nil -- The previous iterated region
		local spacing = Temporal.timecnt_t(1 * Session:nominal_sample_rate ()) -- 1 Second
		local progress = 0;
		 
		for _, name in ipairs(sorted_region_names) do
		    local regions = regions_by_name[name]		    
				
				for i, r in ipairs (regions) do
				
					-- Update progress
					if pdialog:progress (progress / rl:size (), progress .. "/" .. rl:size ()) then
						break
					end
					
					-- prepare for undo operation
					r:to_stateful ():clear_changes ()

					if last_r == nil then
						r:set_position (start)
					else
						local last_pos = last_r:position ()
						local last_length = last_r:length ()
						r:set_position (last_pos + last_length + spacing)
					end

					last_r = r

					-- create a diff of the performed work, add it to the session's undo stack and check if it is not empty
					if not Session:add_stateful_diff_command (r:to_statefuldestructible ()):empty () then
						add_undo = true
					end
				
					progress = progress + 1
				
				end		
				
		end

  	-- drop all region references
		sorted = nil
		collectgarbage ()

		-- all done, commit the combined Undo Operation
		if add_undo then
			-- the 'nil' Command here mean to use the collected diffs added above
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
