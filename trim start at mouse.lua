ardour {
	["type"]    = "EditorAction",
	name        = "Trim start at mouse",
	license     = "MIT",
	author      = "David Healey",
	description = [[Trims the start of the region under the mouse]]
}

function factory ()
    return function ()
      
      Editor:access_action ("Editor", "set-playhead") -- move cursor
      Editor:access_action ("Region", "trim-front") -- trim region start
    
    end
end