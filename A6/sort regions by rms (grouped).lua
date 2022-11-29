ardour {
	["type"]    = "EditorAction",
	name        = "Sort Regions by RMS (grouped)",
	license     = "MIT",
	author      = "David Healey",
	description = [[Sorts the selected regions by RMS, maintaining named groups]]
}

function factory ()
  return function ()

		function posSort (a, b)
  		return a:position () < b:position ()
  	end

		function rmsSort (a, b)
  		return a:rms (nil) < b:rms (nil)
  	end

		local function has_value (tab, val)
		    for index, value in ipairs(tab) do
		        if value == val then
		            return true
		        end
		    end

		    return false
		end

		-- main
    local sel = Editor:get_selection ()
    local rl = sel.regions:regionlist ()

		local add_undo = false -- keep track of changes
    Session:begin_reversible_command ("Sort by RMS (grouped)")

		--Sort regions by position
    table.sort (rl:table(), posSort)

		-- Create group index from region names to make sure groups are kept in order along timeline
		local groupIndex = {}
		local start = nil -- position of region farthest to the left

		for i = #rl:table (), 1, -1 do --Iterate in reverse order

			local r = rl:table ()[i]

			if has_value(groupIndex, r:name()) == false then
				table.insert(groupIndex, r:name ())
			end

			--Check if position of this region is further to the left, is so update start
      if start == nil or r:position () < start then
				start = r:position ()
      end

		end

		-- Put regions into groups (regions with the same name)
		local groups = {}

		for i = rl:size (), 1, -1 do

			local r = rl:table ()[i]

			-- Create group if one doesn't exist
			if groups[r:name ()] == nil then
				groups[r:name ()] = {}
			end

			table.insert(groups[r:name ()], r:to_audioregion ())

		end

		--Sort each group of regions by rms and position along timeline
		local last_r = nil -- The previous iterated region
		local last_pos
		local last_length

		-- progress dialog
    local pdialog = LuaDialog.ProgressWindow ("Sort by RMS (grouped)", true)
		local progress = 0;

		for i, v in ipairs(groupIndex) do

			local group = groups[v]

			table.sort(group, rmsSort)

			-- Reposition regions on the timeline
			for j, r in pairs(group) do

				-- Update progress
				if pdialog:progress (progress / rl:size (), "Sorting " .. progress .. "/" .. rl: size()) then
					break
				end

				-- preare for undo operation
	      r:to_stateful ():clear_changes ()

				if last_r then
	        last_pos = last_r:position ()
	        last_length = last_r:length ()
	        r:set_position(last_pos + last_length + 3 * Session:nominal_sample_rate (), 0)
				else
	        r:set_position(start, 0)
	      end

	      last_r = r
				progress = progress + 1

				-- create a diff of the performed work, add it to the session's undo stack and check if it is not empty
				if not Session:add_stateful_diff_command (r:to_statefuldestructible ()):empty () then
					add_undo = true
				end

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
