ardour {
	["type"]    = "EditorAction",
	name        = "Assign note names to regions",
	license     = "MIT",
	author      = "David Healey",
	description = [[Rename regions by assigning assending note names]]
}

function factory ()

	local notes_to_regions_input_values --Persistent variable (session lifespan)

	return function ()

    -- sort regions by position
    function sortByPosition(a, b)
      return a:position() < b:position()
    end
      
		function numToPitch (n)
      local notes = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
			return notes[(n % 12) + 1] .. math.floor(n / 12 - 2)
    end
			
		-- Define dialog

		-- When avaiable use previously used values as defaults
		local defaults = notes_to_regions_input_values
		if defaults == nil then
			defaults = {}
			defaults["note"] = 0
			defaults["num_rr"] = 4
		end

		local dialog_options = {
			{ type = "number", key = "note", title = "MIDI Note", min = 0, max = 127, default = defaults["note"] },
			{ type = "number", key = "num_rr", title = "No. of Round Robin", min = 1, max = 127, default = defaults["num_rr"] },
		}

		-- undo stuff
		local add_undo = false -- keep track of changes
		Session:begin_reversible_command ("Assign note names to regions")

		-- show dialog
		local od = LuaDialog.Dialog ("Note names to regions", dialog_options)
		local rv = od:run()

		if rv then

			rename_regions_input_values = rv --Save in persistent variable
			local sel = Editor:get_selection() -- Get current selection
			local rl = sel.regions:regionlist()
			local loc = Session:locations():list();

			-- Sort regions by positions
			local regions = {};
			for key, r in pairs(rl:table()) do
				table.insert(regions, r)
			end
			table.sort(regions, sortByPosition)

			-- iterate over sorted regions and rename
			local count = 0
			local noteNum = 0;
			local name = ""
			
			for i, r in ipairs(regions) do
			  
  		  -- preare for undo operation
        r:to_stateful():clear_changes()
				
				if count == 0 then
					noteNum = noteNum + 1;
					name = numToPitch (rv.note + noteNum - 1)
				end

				count = (count + 1) % rv.num_rr;

        r:set_name(name)
				
				if not Session:add_stateful_diff_command(r:to_statefuldestructible()):empty() then
					add_undo = true
				end
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