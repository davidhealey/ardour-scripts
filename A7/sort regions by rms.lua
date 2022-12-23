ardour {
	["type"]    = "EditorAction",
	name        = "Sort Regions by RMS",
	license     = "MIT",
	author      = "David Healey",
	description = [[Sorts the selected regions by RMS]]
}

function factory ()
  return function ()

		function rsort (a, b)
  		return a:rms (nil) < b:rms (nil)
  	end

		-- main
    local sel = Editor:get_selection ()
    local rl = sel.regions:regionlist ()

		local add_undo = false -- keep track of changes
    Session:begin_reversible_command ("Sort by RMS")

		--Sort regions by position
		local sorted = {}
		local start = nil -- position of left most pre-selected region
    for r in rl:iter () do

			table.insert (sorted, r:to_audioregion ())

			--Check if position of this region is further to the left, is so update start
      if start == nil or r:position () < start then
				start = r:position ()
      end
    end

    table.sort (sorted, rsort)

		-- Reposition regions
		local last_r = nil -- The previous iterated region
		local last_pos
		local last_length

		-- progress dialog
    local pdialog = LuaDialog.ProgressWindow ("Sort by RMS", true)

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
				local offset = last_length + Temporal.timecnt_t(1 * Session:nominal_sample_rate ())
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

		collectgarbage()

		-- all done, commit the combined Undo Operation
		if add_undo then
			-- the 'nil' Command here mean to use the collected diffs added above
			Session:commit_reversible_command(nil)
		else
			Session:abort_reversible_command()
		end

		-- hide modal progress dialog and destroy it
		if pdialog ~= nil then
			pdialog:done ()
		end

  end
end
