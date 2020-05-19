ardour {
	["type"]    = "EditorAction",
	name        = "Rename Ranges For Sample Library",
	license     = "MIT",
	author      = "David Healey",
	description = [[Rename range markers associated with selected regions to aid exporting samples]]
}

function factory ()

  local region_range_marker_input_values --Persistent variable (session lifespan)

	return function ()

		local sel = Editor:get_selection() -- Get current selection
		local rl = sel.regions:regionlist()
		local loc = Session:locations():list();

    -- FUNCTIONS --

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
          name = name .. "_" .. math.floor(input["note"] + count)
			  end
      end
			if input["lo_vel"] ~= -1 then name = name .. "_lovel" .. math.floor(input["lo_vel"]) end
			if input["hi_vel"] ~= -1 then name = name .. "_hivel" .. math.floor(input["hi_vel"]) end
			if input["dyn"] ~= -1 then name = name .. "_dynamic" .. math.floor(input["dyn"]) end
			if input["num_rr"] > 0 then name = name .. "_rr" .. rr end

			return name
		end
		
		function groupRegionsByName(region_list)
		  
		  local results = {}
		  
		  for i, r in pairs(rl:table ()) do
  
		    if results[r:name ()] == nil then
		      results[r:name ()] = {}
		    end
		    
		    table.insert(results[r:name ()], r)
		  end
		  
		  return results
		  
    end
		
		-- MAIN --

		-- Define dialog

		-- When avaiable use previously used values as defaults
		local defaults = region_range_marker_input_values
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
			{ type = "number", key = "lo_vel", title = "Low Velocity", min = -1, max = 127, default = defaults["lo_vel"] },
			{ type = "number", key = "hi_vel", title = "High Velocity", min = -1, max = 127, default = defaults["hi_vel"] },
			{ type = "number", key = "dyn", title = "Dynamic", min = -1, max = 127, default = defaults["dyn"] },
			{ type = "number", key = "num_rr", title = "No. of Round Robin", min = 0, max = 24, default = defaults["num_rr"] },
			{ type = "number", key = "rr", title = "First Round Robin", min = 0, max = 127, default = defaults["rr"] }
		}

		-- show dialog
		local od = LuaDialog.Dialog ("Rename Region Ranges", dialog_options)
		local rv = od:run()
		
		if rv then

			region_range_marker_input_values = rv --Save in persistent variable

      -- check for missing RRs			
			local region_sets = groupRegionsByName(rl)
			
			local message = ""
			if rv.num_rr ~= 0 then
  			for i, set in pairs(region_sets) do
          if #set ~= rv.num_rr then
            message = message .. i .. " = " .. #set .. " found\r"
          end
        end
      end
      
      if message ~= "" then
        od = LuaDialog.Message ("Round Robin Count", "The following notes have incorrect RR counts: \r" .. message, LuaDialog.MessageType.Warning, LuaDialog.ButtonType.OK)
        od:run()
      else
        -- progress dialog  
        local pdialog = LuaDialog.ProgressWindow ("Rename Ranges", true)

  			-- Sort region positions
  			local positions = {};
  			for key, r in pairs(rl:table()) do
  				table.insert(positions, r:position())
  			end
  			table.sort(positions)

  			-- Iterate positions and find matching ranges (if any) then rename
  			local count = 0
  			for k, p in ipairs(positions) do --Each region position
  				for l in loc:iter() do --Each location (range marker)
				
  					if (l:is_range_marker() == true and l:start() == p) then --If marker starts at region position

  			  		-- Update progress
          		if pdialog:progress (count / #positions, count .. "/" .. #positions) then
          			break
          		end
					
  						l:set_name(get_name(count, rv))
  						count = count + 1
  					end
  				end

  			end
      end
		end

		od=nil
		collectgarbage()
		
		-- hide modal progress dialog and destroy it
		if pdialog ~= nil then
      pdialog:done ()
		end

	end
end