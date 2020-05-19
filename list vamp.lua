ardour {
	["type"]    = "EditorAction",
	name        = "List Vamp Plugins",
	license     = "MIT",
	author      = "David Healey",
	description = [[Lists available vamp plugins]]
}

function factory ()
    return function ()

	local plugins = ARDOUR.LuaAPI.Vamp.list_plugins ();
	for id in plugins:iter () do
		print ("--", id)
	end
end
end
