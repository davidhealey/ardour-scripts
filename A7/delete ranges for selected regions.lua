ardour {
	["type"]    = "EditorAction",
	name        = "Delete ranges for selected regions",
	license     = "MIT",
	author      = "David Healey",
	description = [[Remove ranges that match the start of the select region(s)]]
}

function factory ()
	return function ()
		
		local sel = Editor:get_selection() -- Get current selection
		local rl = sel.regions:regionlist()
		local loc = Session:locations():list();

    -- FUNCTIONS --
    function sortByPosition(a, b)
      return a:position() < b:position()        
		end
		
		-- MAIN --

		-- Sort region positions
		local positions = {};
		for key, r in pairs(rl:table()) do
			table.insert(positions, r:position())
		end
		table.sort(positions)

		-- Iterate positions and find matching ranges (if any) then rename
		for k, p in ipairs(positions) do --Each region position
			for l in loc:iter() do --Each location (range marker)
				if (l:is_range_marker() == true and l:start() == p) then --If marker starts at region position
					Session:locations():remove(l)
				end
			end
		end

		collectgarbage()

	end
end