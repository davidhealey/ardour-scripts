ardour {
	["type"]    = "EditorAction",
	name        = "Autotune Automation",
	license     = "MIT",
	author      = "David Healey",
	description = [[Inserts "correction" automation points for X42 Autotune plugin]]
}
function factory ()
  
  local autotune_automation_input_values --Persistent variable (session lifespan)

  return function () 
  
    local sel = Editor:get_selection ()
    local rl = sel.regions:regionlist ()
  	local sr = Session:nominal_sample_rate ()
	
  	local pluginName = "Autotune"
  	local automationIndex = 5 -- correction
  
    -- holds reference to plugin
    local plugin
  
  	-- prepare undo operation
  	local add_undo = false -- keep track if something has changed
  	Session:begin_reversible_command ("Automation Tweaker")
  
  	-- get first track
  	local route = Session:get_remote_nth_route(0)
  	assert (not route:isnil (), "Invalid first track")
    
    -- look for the plugin in the first 5 plugin slots
  	for i = 0, 6, 1 do
	  
       plugin = route:nth_plugin(i):to_insert()
         
       if plugin then

         local name = plugin:display_name()

         if name == "x42-Autotune" or name == "x42-Autotune (microtonal)" then
           break
         else
          plugin = nil
         end
       end
    end
    	
  	assert(plugin, "Plugin not found")	
  
    --FUNCTIONS--       
    function addEnvelopePoints(r, inputs)
        
     -- get AutomationList, ControlList and ParameterDescriptor of the first plugin's first parameter (cents)
      local al, cl, pd = ARDOUR.LuaAPI.plugin_automation (plugin, automationIndex)
      
  		-- get state for undo
  		local before = al:get_state ()
      
      -- region position and length
      local pos = r:position()
      local len = r:length()
            
      -- get input data
      local startPoint = pos + ((len / 100) * inputs["start"])
      local attack = pos + ((startPoint - pos) / inputs["attack"])
      local endPoint = pos + len - ((len / 100) * inputs["end"])
      local decay = pos + len - ((pos + len - endPoint) / inputs["decay"])
      local correction = inputs["correction"]
      
      if endPoint < startPoint then
        endPoint = startPoint + 1
      end
      
      cl:clear(pos, pos + len) -- remove existing points for this region
      
      cl:add(pos - 0.2 * sr, 0, false, false) -- add boundary point    
      cl:add(attack, 0, false, false)
      cl:add(startPoint, correction, false, false)
      cl:clear(attack+1, startPoint-1) -- remove guard points
      
      cl:add(endPoint, correction, false, false)
      cl:clear(startPoint + 1, endPoint - 1) -- remove guard points
    
      cl:add(decay, 0, false, false)
      cl:clear(endPoint + 1, decay-1) -- remove guard points
    
  	  cl:add(pos + len + 0.2 * sr, 0, false, false) -- add boundary point
  	  cl:clear(decay + 1, pos + len - 1 + 0.2 * sr) -- remove guard points  	  
  	
  		-- get state for undo
  		local after = al:get_state ()
      Session:add_command (al:memento_command (before, after))
      add_undo = true
    
    end    
  
    --MAIN--
    
		-- When avaiable use previously used values as dialog defaults - only works when script assigned to button
		local defaults = autotune_automation_input_values
		if (defaults == nil) then
			defaults = {}
			defaults["start"] = 10
			defaults["end"] = 10
			defaults["correction"] = 1
			defaults["attack"] = 1.2
			defaults["decay"] = 1.2
		end
    
    -- setup dialog
  	local dialog_options = {
    	{ type = "slider", key = "start", title = "Distance from Start (%)", min = 1, max = 40, default = defaults["start"] },
    	{ type = "slider", key = "end", title = "Distance from End (%)", min = 1, max = 80, default = defaults["end"] },
    	{ type = "slider", key = "correction", title = "Max Correction", min = 0.1, max = 1, digits = 2, default = defaults["correction"] },
      {type = "radio", key = "attack", title = "Attack", values = {["Slow"] = 4, ["Medium"] = 2.5, ["Fast"] = 1.2}, default = defaults["attack"]},
      {type = "radio", key = "decay", title = "Decay", values = {["Slow"] = 4, ["Medium"] = 2.5, ["Fast"] = 1.2}, default = defaults["decay"]}
  	}
	
  	-- show dialog
  	local od = LuaDialog.Dialog ("Autotune Automation", dialog_options)
  	local rv = od:run()
	
  	if rv then
	  
  	  autotune_automation_input_values = rv --Save in persistent variable
	  
      --Each selected region
    	for r in rl:iter () do
        addEnvelopePoints(r, rv)
      end  
    end
  
  	od=nil
  	collectgarbage()
  
  	-- all done, commit the combined Undo Operation
  	if add_undo then
  		-- the 'nil' Commend here mean to use the collected diffs added above
  		Session:commit_reversible_command (nil)
  	else
  		Session:abort_reversible_command ()
  	end

  end
end