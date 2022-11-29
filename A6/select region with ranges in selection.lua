ardour {
	["type"]    = "EditorAction",
	name        = "Select regions with ranges in selection",
	license     = "MIT",
	author      = "David Healey",
	description = [[Removes regions from the selection that do not have range markers at their start]]
}

function factory ()
  return function ()

    local sel = Editor:get_selection ()
    local rl = sel.regions:regionlist ()
		local loc = Session:locations():list();

    -- FUNCTIONS --

    -- sort regions by position
    function posSort(a, b)
      return a:position() < b:position()
    end

    -- MAIN --

    if rl:size() > 0 then

        -- sort selected regions by position
        table.sort(rl:table (), posSort)

        local sl = ArdourUI.SelectionList () -- empty selection list
        for i, r in ipairs(rl:table ()) do
					for l in loc:iter() do --Each location (range marker)

  					if (l:is_range_marker() == true and l:start() == r:position ()) then --If marker starts at region position
	     				-- get RegionView (GUI object to be selected)
	    				local region_view = Editor:regionview_from_region (r)
	    				-- add it to the list of Objects to be selected
	    			 	sl:push_back (region_view);
						end
					end
        end

      	-- set/replace current selection in the editor
	      Editor:set_selection (sl, ArdourUI.SelectionOp.Set);

    end

		collectgarbage ()

  end
end
