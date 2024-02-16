ardour {
	["type"]    = "EditorAction",
	name        = "Rename region sequence",
	license     = "MIT",
	author      = "David Healey",
	description = [[Renames regions in ascending order]]
}

function factory ()
  return function ()

		-- Sorts regions by position, left to right
		function sortByPosition (a, b)
			return a:position () < b:position ()        
		end

    local sel = Editor:get_selection ()
    local rl = sel.regions:regionlist ()

    -- FUNCTIONS --

    -- MAIN --

    if rl:size() > 0 then

      -- setup dialog
    	local dialog_options = {
				{type="dropdown", key="note", title="First Note", values={["C"]=0, ["C#"]=1, ["D"]=2, ["D#"]=3, ["E"]=4, ["F"]=5, ["F#"]=6, ["G"]=7, ["G#"]=8, ["A"]=9, ["A#"]=10, ["B"]=11}, default="C"},
				{type="number", key="octave", title="First Octave", min=-2, max=8, default=3},
        {type = "number", key = "rep", title = "Repetitions", min = 1, max = 20, default = 2},
				{type = "number", key = "increment", title = "Increment", min = 1, max = 12, default = 1}
    	}

    	-- show dialog
      local od = LuaDialog.Dialog ("Rename Region Sequence", dialog_options)
      local rv = od:run ()
			
			-- undo stuff
			local add_undo = false
			Session:begin_reversible_command ("Rename region sequence")

      if rv then

				--Sort regions by position
				local sorted = {}
				for r in rl:iter () do
					table.insert (sorted, r)    		    		
				end

        table.sort(sorted, sortByPosition)

				local notes = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
				local note = rv["note"]
				local octave = rv["octave"]
				local count = 0;
				
				for i, r in ipairs (sorted) do
					
					-- preare for undo operation
					r:to_stateful ():clear_changes ()
					
					local name = notes[note + 1] .. math.floor(octave)
					
					r:set_name(name)

					count = (count + 1) % rv["rep"];
					
					if (count == 0) then						
						
						note = (note + rv["increment"]) % 12
												
						if (note == 0) then
							octave = octave + 1;
						end
					end
					
					-- create a diff of the performed work, add it to the session's undo stack
					if not Session:add_stateful_diff_command (r:to_statefuldestructible ()):empty () then
						add_undo = true
					end

				end
      end
    end
		
		od = nil
		rl = nil

		collectgarbage ()
		
		-- all done, commit the combined Undo Operation
		if add_undo then
			-- the 'nil' Command here mean to use the collected diffs added above
			Session:commit_reversible_command (nil)
		else
			Session:abort_reversible_command ()
		end

  end
end
