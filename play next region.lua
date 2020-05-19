ardour {
	["type"]    = "EditorAction",
	name        = "Play next region",
	license     = "MIT",
	author      = "David Healey",
	description = [[Moves cursor to the next region and enables transport-play]]
}

function factory ()
    return function ()

      Editor:access_action ("Transport", "Stop") -- stop playback
      Editor:access_action ("Editor", "select-topmost") -- select first track
      Editor:access_action ("Editor", "select-next-route") -- select second track
      Editor:access_action ("Editor", "playhead-to-next-region-sync") -- move cursor
      Editor:access_action ("Transport", "Roll") -- start playback

    end
end