ardour {
	["type"]    = "EditorAction",
	name        = "Trim end at mouse",
	license     = "MIT",
	author      = "David Healey",
	description = [[Trims the end of the region under the mouse]]
}

function factory ()
    return function ()
      
      Editor:access_action ("Editor", "set-playhead") -- move cursor
      Editor:access_action ("Region", "trim-back") -- trim region end
    
    end
end