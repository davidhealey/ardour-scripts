ardour {
	["type"]    = "EditorAction",
	name        = "Skip select regions in selection",
	license     = "MIT",
	author      = "David Healey",
	description = [[Filters regions in the current selection]]
}

function factory ()
  return function ()

    local sel = Editor:get_selection ()
    local rl = sel.regions:regionlist ()

    -- FUNCTIONS --

    -- sort regions by position
    function posSort(a, b)
      return a:position() < b:position()
    end

    -- MAIN --

    if rl:size() > 0 then

      -- setup dialog
    	local dialog_options = {
        {type = "number", key = "skip", title = "Skip", min = 1, max = 1000, default = 2},
    	}

    	-- show dialog
      local od = LuaDialog.Dialog ("Skip select", dialog_options)
      local rv = od:run ()

      if rv then

        -- sort selected regions by position
        table.sort(rl:table (), posSort)

        local sl = ArdourUI.SelectionList () -- empty selection list
				local count = 0;

				for i = rl:size (), 1, -1 do

					local r = rl:table ()[i]

          if count == 0 then
     				-- get RegionView (GUI object to be selected)
    				local region_view = Editor:regionview_from_region (r)
    				-- add it to the list of Objects to be selected
    			 	sl:push_back (region_view);
				  end

					count = (count + 1) % rv.skip

        end

      	-- set/replace current selection in the editor
	      Editor:set_selection (sl, ArdourUI.SelectionOp.Set);

      end

    end

		collectgarbage ()

  end
end
