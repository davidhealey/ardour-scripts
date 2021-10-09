ardour {
	["type"]    = "EditorAction",
	name        = "Play at half speed",
	license     = "MIT",
	author      = "David Healey",
	description = [[Start playback at 50% speed]]
}

function factory ()
    return function ()
      Session:request_transport_speed (0.5, true, ARDOUR.TransportRequestSource.TRS_UI)    
    end
end