ardour {
	["type"]    = "EditorAction",
	name        = "Sort Regions Alphabetically",
	license     = "MIT",
	author      = "David Healey",
	description = [[Sorts the selected regions along the timeline]]
}

function factory ()
  return function ()


  	-- sort compare function
  	-- a,b here are http://manual.ardour.org/lua-scripting/class_reference/#ARDOUR:Route
  	-- return true if route "a" should be ordered before route "b"
  	function rsort (a, b)
  		return a:name() < b:name()
  	end

    local sel = Editor:get_selection ()
    local rl = sel.regions:regionlist ()
      
    if rl:size() > 0 then
      
    	local add_undo = false -- keep track of changes
      Session:begin_reversible_command ("Sort Regions")

    	-- create a sortable list of regions
    	local sorted = {}
    	local start = rl:table()[1]:position() -- position of left most selected region
    	
    	for r in rl:iter() do
    		
    		table.insert(sorted, r)
    		
    		--Check if position of this region is further to the left, is so update start
    		if r:position() < start then
    		  start = r:position()
    		end
    		    		
    	end
    	
    	table.sort(sorted, rsort) -- sort the list using the compare function

    	-- Reposition regions, space 1 second apart
    	local last_r = nil -- The previous iterated region
      local last_pos
      local last_length 
	
    	for i, r in ipairs(sorted) do
	  
	      -- preare for undo operation
        r:to_stateful():clear_changes()
	  
    	  if last_r then
    	    last_pos = last_r:position()
    	    last_length = last_r:length()
    	    r:set_position(last_pos + last_length +  Session:nominal_sample_rate(), 0)
    	  else
    	   r:set_position(start, 0)
    	  end
	  
    	  last_r = r
	  
    		-- create a diff of the performed work, add it to the session's undo stack
    		if not Session:add_stateful_diff_command (r:to_statefuldestructible()):empty () then
    			add_undo = true
    		end
	  
    	end

    	-- drop all region references
    	sorted = nil
    	collectgarbage ()
	
    	-- all done, commit the combined Undo Operation
    	if add_undo then
    		-- the 'nil' Command here mean to use the collected diffs added above
    		Session:commit_reversible_command(nil)
    	else
    		Session:abort_reversible_command()
    	end
    end
  end
end