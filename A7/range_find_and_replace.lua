ardour {
	["type"]    = "EditorAction",
	name        = "Range Find and Replace",
	license     = "MIT",
	author      = "David Healey",
	description = [[Finds and replaces text in ranges within the current selection of regions.]]
}

function factory ()

  local region_range_marker_input_values --Persistent variable (session lifespan)

	return function ()

		local sel = Editor:get_selection() -- Get current selection
		local rl = sel.regions:regionlist()
		local loc = Session:locations():list();

    -- FUNCTIONS --
		
		-- MAIN --

		-- Define dialog

		-- When avaiable use previously used values as defaults
		local defaults = rename_region_range_input_values
		if defaults == nil then
			defaults = {}
			defaults["find"] = ""
			defaults["replace"] = ""
		end

		local dialog_options = {
			{ type = "entry", key = "find", title = "Find", default = defaults["find"] },
			{ type = "entry", key = "replace", title = "Replace", default = defaults["replace"] },
		}

		-- show dialog
		local od = LuaDialog.Dialog ("Find/Replace", dialog_options)
		local rv = od:run()
		
		if rv then

			rename_region_range_input_values = rv --Save in persistent variable

      -- progress dialog  
      local pdialog = LuaDialog.ProgressWindow ("Find/Replace", true)

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
  					if (l:is_range_marker() == true and l:start():samples() == p:samples()) then --If marker starts at region position

  			  		-- Update progress
          		if pdialog:progress (count / #positions, count .. "/" .. #positions) then
          			break
          		end

							local new_name = string.gsub(l:name(), rv["find"], rv["replace"])					
  						l:set_name(new_name)
  						count = count + 1
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