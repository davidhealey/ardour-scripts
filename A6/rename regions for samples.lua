ardour {
	["type"]    = "EditorAction",
	name        = "Rename Regions For Sample Library",
	license     = "MIT",
	author      = "David Healey",
	description = [[Rename selected regions to aid exporting samples]]
}

function factory ()

	local rename_regions_input_values --Persistent variable (session lifespan)

	return function ()

    -- sort regions by position
    function sortByPosition(a, b)
      return a:position() < b:position()
    end
      
		-- assemble the name
		function get_name(count, input)
			local name = ""
			local rr = math.floor(input["rr"] + (count % input["num_rr"])) -- calculate rr number
			
			if input["inst"] ~= "" then name = name .. input["inst"] end
			if input["art"] ~= "" then name = name .. "_" .. input["art"] end			
			if input["note"] ~= -1 then
			  if input["num_rr"] > 0 then
			    name = name .. "_" .. math.floor(input["note"] + (count / input["num_rr"]))
			  else
          name = name .. "-" .. math.floor(input["note"] + count)
			  end
      end
			if input["lo_vel"] ~= -1 then name = name .. "_lovel" .. math.floor(input["lo_vel"]) end
			if input["hi_vel"] ~= -1 then name = name .. "_hivel" .. math.floor(input["hi_vel"]) end
			if input["dyn"] ~= -1 then name = name .. "_dynamic" .. math.floor(input["dyn"]) end
			if input["num_rr"] > 0 then name = name .. "_rr" .. rr end

			return name
		end

		-- Define dialog

		-- When avaiable use previously used values as defaults
		local defaults = rename_regions_input_values
		if defaults == nil then
			defaults = {}
			defaults["inst"] = ""
			defaults["art"] = ""
			defaults["note"] = -1
			defaults["lo_vel"] = -1
			defaults["hi_vel"] = -1
			defaults["dyn"] = -1
			defaults["num_rr"] = 3
			defaults["rr"] = 0
		end

		local dialog_options = {
			{ type = "entry", key = "inst", title = "Instrument", default = defaults["inst"] },
			{ type = "entry", key = "art", title = "Articulation", default = defaults["art"] },
			{ type = "number", key = "note", title = "MIDI Note", min = -1, max = 127, default = defaults["note"] },
			{ type = "slider", key = "lo_vel", title = "Low Velocity", min = -1, max = 127, default = defaults["lo_vel"] },
			{ type = "slider", key = "hi_vel", title = "High Velocity", min = -1, max = 127, default = defaults["hi_vel"] },
			{ type = "slider", key = "dyn", title = "Dynamic", min = -1, max = 16, default = defaults["dyn"] },
			{ type = "slider", key = "num_rr", title = "No. of Round Robin", min = 0, max = 127, default = defaults["num_rr"] },
			{ type = "slider", key = "rr", title = "First Round Robin", min = 0, max = 127, default = defaults["rr"] }
		}

		-- undo stuff
		local add_undo = false -- keep track of changes
		Session:begin_reversible_command ("Rename Regions")

		-- show dialog
		local od = LuaDialog.Dialog ("Rename Regions", dialog_options)
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
			for i, r in ipairs(regions) do
			  
  		  -- preare for undo operation
        r:to_stateful():clear_changes()

        r:set_name(get_name(i-1, rv))
				
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