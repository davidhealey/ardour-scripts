ardour {
	["type"]    = "EditorAction",
	name        = "Rename ranges for loops",
	license     = "MIT",
	author      = "David Healey",
	description = [[Rename range markers for loop point export]]
}

function factory ()

	return function ()

		local sel = Editor:get_selection() -- Get current selection
		local rl = sel.regions:regionlist()
		local loc = Session:locations():list();

    -- FUNCTIONS --
	
		-- MAIN --

  	for key, r in pairs(rl:table()) do

      local pos = r:position ()
      local len = r:length ()
      local name
      
  		for l in loc:iter() do --Each location (range marker)
				
  			if l:is_range_marker() == true then -- is a range marker
  				if l:start() == pos then --If marker starts at begining of region
  					name = l:name() 
  				end
				  
  				if (l:start() > pos and l:start() < pos + len) then --If marker starts within region				
  					l:set_name("LOOP - " .. name)
  				end
				  
  			end				
  		end
    end
	

		
		collectgarbage()

	end
end