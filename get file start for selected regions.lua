ardour {
	["type"]    = "EditorAction",
	name        = "Get File Start",
	license     = "MIT",
	author      = "David Healey",
	description = [[Prints the file start value for the selected regions]]
}

function factory ()
    return function ()

      local sel = Editor:get_selection ()
      local rl = sel.regions:regionlist ()
      local sr = Session:nominal_sample_rate()

			local message = ""

      if rl:size () > 0 then
        for r in rl:iter () do
          local hh, mm, ss = ARDOUR.LuaAPI.sample_to_timecode (Timecode.TimecodeFormat.TC25, sr, r:start())
    		  message = message .. "\r" .. hh .. ":" .. mm .. ":" .. ss
    	  end
      end

			if message ~= "" then
				od = LuaDialog.Message ("Start Positions", message, LuaDialog.MessageType.Info, LuaDialog.ButtonType.OK)
				od:run()
			end

    end
end
