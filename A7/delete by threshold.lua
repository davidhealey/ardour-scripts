ardour {
	["type"]    = "EditorAction",
	name        = "Delete selected regions by threshold",
	license     = "MIT",
	author      = "David Healey",
	description = [[Deletes selected regions that are shorter than the specified threshold]]
}

function factory ()

    return function ()

      -- GLOBALS --
      local sr = Session:nominal_sample_rate ()
      local sel = Editor:get_selection ()
    	local rl = sel.regions:regionlist ()

    	-- FUNCTIONS --

			--Undo stuff
			local add_undo = false -- keep track of changes
			Session:begin_reversible_command ("Delete by threshold")

			-- prompt settings
    	local dialog_options = {{type="number", key="threshold", title="Threshold (ms)", min=10, max=10000, step=1, default=1000}}

			-- prompt user for input
  		local od = LuaDialog.Dialog ("Delete by threshold", dialog_options)
  		local rv = od:run()

      -- variables for progress dialog
      local pdialog

			--Dialog response
  		if (rv) then

        pdialog = LuaDialog.ProgressWindow ("Delete by threshold", true)

				local regionsToDelete = {}
				local totalToDelete = 0;

        for i, r in ipairs (rl:table ()) do
										
					local pos = r:length ()
					
					if (pos <= Temporal.timecnt_t(rv["threshold"] * Session:nominal_sample_rate () / 1000)) then
						table.insert(regionsToDelete, r)
						totalToDelete = totalToDelete + 1
					end
				end

				for i, r in pairs(regionsToDelete) do

          -- Update progress
      		if pdialog:progress (i / totalToDelete, i .. "/" .. totalToDelete) then
      			break
      		end

					local playlist = r:playlist ()

					-- preare for undo operation
					playlist:to_stateful():clear_changes()

					playlist:remove_region(r)

					-- create a diff of the performed work, add it to the session's undo stack
					if not Session:add_stateful_diff_command (playlist:to_statefuldestructible()):empty () then
						add_undo = true
					end

        end

			end

			od=nil
			collectgarbage()

			-- all done, commit the combined Undo Operation
			if add_undo then
				-- the 'nil' Command here mean to use the collected diffs added above
				Session:commit_reversible_command(nil)
			else
				Session:abort_reversible_command()
			end

      ::out::
    	-- hide modal progress dialog and destroy it
    	if pdialog ~= nil then
        pdialog:done ()
    	end

    end
end
