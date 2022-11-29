ardour {
	["type"]    = "EditorAction",
	name        = "Play from mouse cursor",
	license     = "MIT",
	author      = "David Healey",
	description = [[Start playback from mouse]]
}

function factory ()
    return function ()
      
      Editor:access_action ("Editor", "set-playhead") -- move cursor
      Editor:access_action ("Transport", "Roll") -- start playback
    
    end
end