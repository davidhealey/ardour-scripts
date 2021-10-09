ardour {
	["type"]    = "EditorAction",
	name        = "Play at quarter speed",
	license     = "MIT",
	author      = "David Healey",
	description = [[Start playback at 25% speed]]
}

function factory ()
    return function ()
      Session:request_transport_speed (0.25, true, ARDOUR.TransportRequestSource.TRS_UI)    
    end
end