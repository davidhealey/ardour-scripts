ardour {
	["type"]    = "EditorAction",
	name        = "Bulk Rename Regions",
	license     = "MIT",
	author      = "David Healey",
	description = [[Rename selected regions]]
}

function factory ()

	local bulk_rename_regions_input_values --Persistent variable (session lifespan)

	return function ()

		-- Define dialog

		-- When avaiable use previously used values as defaults
		local defaults = bulk_rename_regions_input_values
		if defaults == nil then
			defaults = {}
			defaults["name"] = ""
		end

		local dialog_options = {{ type = "entry", key = "name", title = "New Name", default = defaults["name"] }}

		-- undo stuff
		local add_undo = false -- keep track of changes
		Session:begin_reversible_command ("Bulk Rename Regions")

		-- show dialog
		local od = LuaDialog.Dialog ("Rename Regions", dialog_options)
		local rv = od:run()

		if rv then
			bulk_rename_regions_input_values = rv --Save in persistent variable
			local sel = Editor:get_selection() -- Get current selection
			local rl = sel.regions:regionlist()

			-- Rename regions
			for key, r in pairs(rl:table()) do
				-- preare for undo operation
		    r:to_stateful():clear_changes()
        r:set_name(rv["name"])
				if not Session:add_stateful_diff_command(r:to_statefuldestructible()):empty() then
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
	end
end
