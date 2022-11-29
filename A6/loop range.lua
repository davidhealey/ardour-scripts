ardour {
	["type"]    = "EditorAction",
	name        = "Loop range",
	license     = "MIT",
	author      = "David Healey",
	description = [[Loop selected range]]
}

function factory ()
  return function ()
      
		local sel = Editor:get_selection() -- Get current selection
		local rangeMarker = sel.markers:table()[1] -- get first selected marker (should be a range marker)
				
	   if rangeMarker ~= nil then
      
      -- get range start and end points
      local startPos = rangeMarker:position()
      local endPos
      
      local loc = Session:locations():list()
      for l in loc:iter() do --Each location (range marker)
				
        if l:is_range_marker() == true and l:start() == startPos then -- if marker starts at region position				
          endPos = startPos + l:length ()
          break
				end
			end
      
      if startPos ~= nil and endPos ~= nil then
        -- assign loop range
        Editor:	set_loop_range (startPos, endPos, "set loop range")
      
        Editor:access_action ("Transport", "Loop") -- start playback
      end
    end 
    
  end
end