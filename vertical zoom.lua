ardour {
  ["type"] = "EditorAction",
  name = "Vertical Zoom",
  license = "MIT",
  author = "David Healey",
  description = [[Poor man's vertical zoom using gain boost and envelope cut]]
}

function factory ()
  return function ()

    local sel = Editor:get_selection ()
    local rl = sel.regions:regionlist ()
    local target_peak = -1 --dBFS

    if rl:size () > 0 then

      -- prompt settings
      local dialog_options = {
        {type = "radio", key = "action", title = "Action", values = {["Zoom"] = 0, ["Reset"] = 1}, default = 1},
      }

      -- prompt user for interval
      local od = LuaDialog.Dialog ("Vertical Zoom", dialog_options)
      local rv = od:run ()

      -- undo stuff
      local add_undo = false
      Session:begin_reversible_command ("Vertical Zoom")

      --FUNCTIONS
      function getPeak (ar)
        local peak = ar:maximum_amplitude (nil)

        -- check if region is silent
        if (peak > 0) then
          local f_peak = peak / 10 ^ (.05 * target_peak)
          return f_peak
        end
      end

      function updateEnvelope (ar, peak)
				ar:set_envelope_active (true)
				
				local al = ar:envelope ()
				local cl = al:list ()
				
				local before = al:get_state ()
				
				for e in cl:events():iter() do
					if peak ~= 1 then
						e.value = (e.value * peak)
					else
						e.value = 1
					end
	      end				
				
				-- get state for undo
	  		local after = al:get_state ()
	      Session:add_command (al:memento_command (before, after))
	      add_undo = true
      end

      --Dialog response
      if (rv) then

        --Change region gain and envelope
        for r in rl:iter () do

          local ar = r:to_audioregion ()

          if not ar:isnil () then

            -- preare for undo operation
            r:to_stateful ():clear_changes ()

            local peak = 1;

            if rv["action"] == 0 then
              peak = getPeak (ar)
            end

						updateEnvelope (ar, peak) -- shift envelope points

            r:to_audioregion (): set_scale_amplitude (1 / peak) -- apply gain

            -- create a diff of the performed work, add it to the session's undo stack
            if not Session:add_stateful_diff_command (r:to_statefuldestructible ()):empty () then
              add_undo = true
            end
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
