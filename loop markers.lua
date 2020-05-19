ardour {
	["type"]    = "EditorAction",
	name        = "Loop markers",
	license     = "MIT",
	author      = "David Healey",
	description = [[Play loop from selected marker to next marker]]
}

function factory ()
  return function ()
      
    local sr = Session:nominal_sample_rate ()
		local sel = Editor:get_selection() -- Get current selection
		local loc = Session:locations():list();
		local mark = sel.markers:table()[1] -- get first selected marker

    -- sort locations by position
    function sortByPosition(a, b)
      return a < b        
    end
    
    local locations = {}
    for l in loc:iter() do
      table.insert(locations, l:start())
    end

    table.sort(locations, sortByposition)    

    if mark ~= nil and mark:_type() == ArdourUI.MarkerType.Mark == true then
      
      if string.find(mark:name(), "LOOP START") ~= nil then
      
        --local nextMarkPos = Session:locations():first_mark_after (mark:position(), false)        
        local id = mark:name():sub(1, 1);
        
        -- search for loop end marker with same ID
        local nextMark
        for i = 1, #locations, 1 do
          local l = Session:locations():first_mark_at(locations[i], sr/100)
          if l ~= nil and l:is_mark() and l:start() > mark:position() and l:name():find("LOOP END") ~= nil and l:name():sub(1, 1) == id then
            nextMark = l
            break
          end
        end
      
        if nextMark ~= nil then
          -- get range start and end points
          local startPos = mark:position()
          local endPos = nextMark:start()
            
          if startPos ~= nil and endPos ~= nil then
            -- assign loop range
            Editor:	set_loop_range (startPos, endPos, "set loop range")      
            Editor:access_action ("Transport", "Loop") -- start playback
          end
        else
          msg = LuaDialog.Message ("Loop Marker", "Loop end marker not found", LuaDialog.MessageType.Info, LuaDialog.ButtonType.OK)
          msg:run()          
        end
      else
        msg = LuaDialog.Message ("Loop Marker", "Not a loop start marker", LuaDialog.MessageType.Info, LuaDialog.ButtonType.OK)
        msg:run()
      end
    end
    
  end
end