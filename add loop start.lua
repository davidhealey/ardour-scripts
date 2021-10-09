ardour {
	["type"]    = "EditorAction",
	name        = "add loop start",
	license     = "MIT",
	author      = "David Healey",
	description = [[Insert loop start location marker]]
}

function factory ()
  return function ()

		function round(n)
      return n + 0.5 - (n + 0.5) % 1
    end

		--Main
		local sel = Editor:get_selection ()
    local rl = sel.regions:regionlist ()
    local sr = Session:nominal_sample_rate ()
		local pos = Session:transport_sample ()

		for r in rl:iter() do

			if r:position () <= pos and r:position () + r:length () > pos then
				Editor:add_location_mark (pos)
				local mark = Session:locations():mark_at(pos, sr / 100)
				mark:set_name (1 .. " LOOP START-" .. round(pos - r:position ()))
				mark:lock ()
				break
			end

		end

  end
end
