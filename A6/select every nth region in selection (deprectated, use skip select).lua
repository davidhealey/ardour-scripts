ardour {
	["type"]    = "EditorAction",
	name        = "Select every nth region in selection",
	license     = "MIT",
	author      = "David Healey",
	description = [[Selects every nth region in selection]]
}

function factory ()
  return function ()

    local sel = Editor:get_selection ()
    local rl = sel.regions:regionlist ()

    -- FUNCTIONS -- 
    
    -- sort regions by position
    function sortByPosition(a, b)
      return a:position() < b:position()
    end	
    
    -- MAIN --
    
    if rl:size() > 0 then
    
      -- setup dialog
    	local dialog_options = {
        {type = "number", key = "step", title = "Step", min = 2, max = 100000, default = 2},
    	}
  	
    	-- show dialog
      local od = LuaDialog.Dialog ("Select every nth region", dialog_options)
      local rv = od:run ()
    
      if rv then
        
        -- sort selected regions by position
        local sorted = {}
  			for key, r in pairs(rl:table()) do
  				table.insert(sorted, r)
  			end
        table.sort(sorted, sortByPosition) -- sort the list using the compare function
       

        local sl = ArdourUI.SelectionList () -- empty selection list
        for i, r in ipairs(sorted) do

          if i % rv.step == 0 then
     				-- get RegionView (GUI object to be selected)
    				local region_view = Editor:regionview_from_region (r)
    				-- add it to the list of Objects to be selected
    			 	sl:push_back (region_view);
				  end
          
        end
      
      	-- set/replace current selection in the editor
	      Editor:set_selection (sl, ArdourUI.SelectionOp.Set);  
        
      end
    
    end

		-- drop all region references
		sorted = nil
		collectgarbage ()

  end
end