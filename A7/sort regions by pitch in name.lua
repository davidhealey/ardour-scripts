ardour {
	["type"]    = "EditorAction",
	name        = "Sort Regions by Pitch in Name",
	license     = "MIT",
	author      = "David Healey",
	description = [[Sorts the selected regions by pitch (in their name) along the timeline]]
}

function factory ()
  return function ()

    -- return true if route "a" should be ordered before route "b"
    function rsort (a, b)

      local notes = {["C"]=1, ["C#"]=2, ["D"]=3, ["D#"]=4, ["E"]=5, ["F"]=6, ["F#"]=7, ["G"]=8, ["G#"]=9, ["A"]=10, ["A#"]=11, ["B"]=12}

  	  -- get region names
  	  local n1 = a:name ()
  	  local n2 = b:name ()

      local l = {string.match(n1,"%D+"), string.match(n2,"%D+")} -- note letter + accidental (if any)
      local o = {string.match(n1,"%d+"), string.match(n2,"%d+")} -- octave number

  	  -- Move invalid values to the end of the table
  	  if not notes[l[1]] then
        return false
      elseif not notes[l[2]] then
        return true
      end

  	  if o[1] and o[2] and notes[l[1]] and notes[l[2]] then -- skip nil values
        if o[1] > o[2] then
          return false
        elseif o[2] > o[1] then
          return true
        else -- if the octave is the same for both
          if notes[l[1]] < notes[l[2]] then
            return true
          end
        end
      end

      return false

    end

    local sel = Editor:get_selection ()
    local rl = sel.regions:regionlist ()

		local add_undo = false -- keep track of changes
    Session:begin_reversible_command ("Sort by pitch")

    -- Sort selected regions by pitch in name
    local sorted = {}
    local start = nil -- position of left most pre-selected region
    for r in rl:iter () do

      table.insert (sorted, r)

      --Check if position of this region is further to the left, is so update start
      if start == nil or r:position () < start then
				start = r:position ()
      end

    end

    table.sort (sorted, rsort) -- sort the list using the compare function

    -- progress dialog
    local pdialog = LuaDialog.ProgressWindow ("Sort by Pitch", true)

     -- reposition the sorted regions on the timeline
     local last_r = nil -- The previous iterated region
     local last_pos
     local last_length

    for i, r in ipairs (sorted) do

      -- Update progress
			if pdialog:progress (i / rl:size (), i .. "/" .. rl:size ()) then
				break
			end

			-- preare for undo operation
      r:to_stateful ():clear_changes ()

      if last_r then
        last_pos = last_r:position ()
        last_length = last_r:length ()
				local offset = last_length + Temporal.timecnt_t(3 * Session:nominal_sample_rate ())
        r:set_position(last_pos + offset)
			else
        r:set_position(start)
      end

      last_r = r

			-- create a diff of the performed work, add it to the session's undo stack and check if it is not empty
			if not Session:add_stateful_diff_command (r:to_statefuldestructible ()):empty () then
				add_undo = true
			end

    end

  	-- drop all region references
		sorted = nil
		collectgarbage ()

		-- all done, commit the combined Undo Operation
		if add_undo then
			-- the 'nil' Command here mean to use the collected diffs added above
      Session:commit_reversible_command (nil)
		else
			Session:abort_reversible_command ()
		end

		-- hide modal progress dialog and destroy it
		if pdialog ~= nil then
      pdialog:done ()
		end

  end
end
