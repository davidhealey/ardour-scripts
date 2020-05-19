ardour {
	["type"]    = "EditorAction",
	name        = "Rubberband Pitch Shift",
	license     = "MIT",
	author      = "David Healey",
	description = [[Automatically adds automation data for a pitch shifter plugin to correct sample tuning.]]
}
function factory () return function ()

  local sel = Editor:get_selection()
  local rl = sel.regions:regionlist()
	local sr = Session:nominal_sample_rate()

	local vamp = ARDOUR.LuaAPI.Vamp("libardourvamppyin:pyin", sr)
  vamp:plugin():setParameter ("lowampsuppression", 0.0) -- Don't supress low amplitude estimates

	local pitchPluginName = "Rubberband (Mono)"
	local automationIndex = 1
	local useSemiTones = false

	-- prepare undo operation
	local add_undo = false -- keep track if something has changed
	Session:begin_reversible_command ("Auto Pitch Shift")

	-- get first track
	local route = Session:get_remote_nth_route(0)
	assert (not route:isnil (), "Invalid first track")

  --Look for the plugin in the first 5 plugin slots
	local plugin
	for i = 0, 6, 1 do
     plugin = route:nth_plugin(i):to_insert();

     if plugin and plugin:isnil() == false then
       local name = plugin:display_name()

       if name == pitchPluginName then
         break
       else
        plugin = nil
       end

     end
  end

	assert(plugin, "Plugin not found")

  --FUNCTIONS--
  function freqToCentsOffset(f)

  	local lnote = (math.log(f) - math.log(440)) / math.log(2) + 4.0
  	local oct = math.floor(lnote)

  	local cents = 1200 * (lnote - oct)
  	local noteNames = {"A", "A#", "B", "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#"}
    local note = ""

  	local offset = 50.0

  	if cents < 50 then
  		note = "A "
  	elseif cents >= 1150 then
  		note = "A "
  		cents = cents - 1200
  		oct = oct + 1;
  	else
  		for i = 1, 11, 1 do
  			if cents >= offset and cents < offset + 100 then
  				note = noteNames[i+1]
  				cents = cents - (i * 100)
  				break
  			end
  			offset = offset + 100
  		end
  	end

  	--print(f, " - ", note .. oct) -- helpful when debugging

  	if useSemiTones == true then
      return cents / 100
  	else
      return cents
  	end

  end

  function addEnvelopePoints(f, r)

   -- get AutomationList, ControlList and ParameterDescriptor of the first plugin's first parameter (cents)
    local al, cl, pd = ARDOUR.LuaAPI.plugin_automation (plugin, automationIndex)

		-- get state for undo
		local before = al:get_state ()

    -- if there are no events aready add one at the begining
    if cl:events():size() == 0 then
      cl:add(0, 0, false, false)
    end

    -- calculate number of cents difference between f and closest note
    local offset = freqToCentsOffset(f)

    -- add automation points
    local pos = r:position()
    local len = r:length()

    cl:clear(pos + 1, pos + len - 1) -- remove old points for region

    cl:add(pos - 0.1 * sr, 0, false, false)
    cl:add(pos, -offset, false, false)
    cl:clear(pos + 1 - 0.1 * sr, pos - 1)

    cl:add(pos + len, -offset, false, false)
    cl:clear(pos + 1, pos + len - 1)

    cl:add(pos + len + 0.1 * sr, 0, false, false)
    cl:clear(pos + len + 1, pos + len - 1 + 0.1 * sr)

		-- get state for undo
		local after = al:get_state ()
    Session:add_command (al:memento_command (before, after))
    add_undo = true
  end

  --MAIN--
  
  local pdialog = LuaDialog.ProgressWindow ("Auto Pitch Shift", true)

  --Each selected region
	for i, r in ipairs (rl:table ()) do

		-- Update progress
		if pdialog:progress (i / rl:size (), i .. "/" .. rl:size ()) then
			break
		end

    -- Test if it's an audio region
    if r:to_audioregion ():isnil () then goto continue end

 		vamp:analyze (r:to_readable (), 0, nil)

		-- get remaining features (end of analyis)
    local feats = vamp:plugin():getRemainingFeatures()
		local fl = feats:table()[5] --5 = frequency

		--If frequency value is returned
		if (fl and fl:size() > 0) then
			freq = fl:at(0).values:at(0) -- store frequency of region
			addEnvelopePoints(freq, r)
    end

		-- reset the plugin (prepare for next iteration)
		vamp:reset ()

    ::continue::

  end

	-- all done, commit the combined Undo Operation
	if add_undo then
		-- the 'nil' Commend here mean to use the collected diffs added above
		Session:commit_reversible_command (nil)
	else
		Session:abort_reversible_command ()
	end
	
  -- hide modal progress dialog and destroy it
	if pdialog ~= nil then
    pdialog:done ()
	end

end end
