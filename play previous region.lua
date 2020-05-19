ardour {
	["type"]    = "EditorAction",
	name        = "Play previous region",
	license     = "MIT",
	author      = "David Healey",
	description = [[Moves cursor to the previous region and enables transport-play]]
}

function factory ()
    return function ()

      Editor:access_action ("Transport", "Stop") -- stop playback
      Editor:access_action ("Editor", "select-topmost") -- select first track
      Editor:access_action ("Editor", "select-next-route") -- select second track
      Editor:access_action ("Editor", "playhead-to-previous-region-sync") -- move playhead
      Editor:access_action ("Transport", "Roll") -- start playback

    end
end