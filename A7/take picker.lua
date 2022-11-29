ardour {
	["type"]    = "EditorAction",
	name        = "Take Selector",
	license     = "MIT",
	author      = "David Healey",
	description = [[Locks specified number of takes from select regions.]]
}

function factory ()
  return function ()

    -- GLOBALS --
    local sr = Session:nominal_sample_rate ()
    local sel = Editor:get_selection ()
  	local rl = sel.regions:regionlist ()
	
    -- vamp plugin
    local vamp = ARDOUR.LuaAPI.Vamp("libardourvampplugins:qm-similarity", sr)   
    	   
    -- FUNCTIONS --
    
    function round(num, numDecimalPlaces)
      local mult = 10^(numDecimalPlaces or 0)
      return math.floor(num * mult + 0.5) / mult
    end
    
    function table.clone(org)
      return {table.unpack(org)}
    end
     -- sort regions by position
    function sortByPosition(a, b)
      return a:position() < b:position()
    end	
 
		-- Kullback-Leibler Divergence
		function kld(m1, v1, m2, v2)
		  
		  local size = math.min(#m1, #m2, #v1, #v2)
		  local d = -2.0 * size
		  local small = 1e-20

		  for k = 1, size, 1 do
		    local kv1 = v1[k] + small
		    local kv2 = v2[k] + small
		    local km = (m1[k] - m2[k]) + small
		    
		    d = d + kv1 / kv2 + kv2 / kv1
		    d = d + km * (1.0 / kv1 + 1.0 /kv2) * km
		  end
		  
		  d = d / 2.0
		  
		  return d
		  
		end
				
		function compareSimilarities(m, v)

      local n_channels = #m
      local similarity = {}

      for i = 1, n_channels, 1 do
        
        similarity[i] = {}
        
        for j = 1, n_channels, 1 do
          local d = round(kld(m[i], v[i], m[j], v[j]), 3) 
          table.insert(similarity[i], d)
        end
      end      

      return similarity
		  
    end
		            
    function findMostSimilar(data)
        
      local lowest = 1
      local totals = {}
        
      for i, set in pairs(data) do -- each set of similarities (one per channel analysed)

        totals[i] = 0
          
        for j, v in pairs(set) do
          totals[i] = totals[i] + v
        end
          
         -- keep track of set with lowest score (i.e most similar)
        if totals[i] <= totals[lowest] then
          lowest = i
        end
          
      end
        
      -- organise region indexes from lowest to highest similarity value
      local indexes = {}
      local temp = table.clone(data[lowest])
      table.sort(temp)
        
      for i, v1 in pairs(data[lowest]) do
        for j, v2 in pairs(temp) do
          if v1 == v2 then
            indexes[i] = j
          end 
        end
      end

      return indexes
    end
		
    -- MAIN --
    
    -- prepare undo operation
    local add_undo = false -- keep track if something has changed
  	Session:begin_reversible_command ("Take Selector")
    
    -- variable for progress dialog
    local pdialog
    
    -- setup dialog
  	local dialog_options = {
    	{type = "number", key = "count", title = "Number of Takes", min = 1, max = 20, default = 3},
  	}
  	
  	-- show dialog
    local od = LuaDialog.Dialog ("Take Selector", dialog_options)
    local rv = od:run ()
  	
    if rv then
	
      pdialog = LuaDialog.ProgressWindow ("Take Selector", true)
      
		  -- Sort regions by positions
			local sorted = {};
			for key, r in pairs(rl:table()) do
				table.insert(sorted, r)
			end
			table.sort(sorted, sortByPosition)     
     
      -- tables to hold means and variance values from all regions
      local means = {}
      local variances = {}
     
      -- perform vamp analysis and group regions by name
      local region_sets = {}
      for i, r in ipairs (sorted) do

        -- Update progress
    		if pdialog:progress (i / rl:size (), "Analysis: " .. i .. "/" .. rl:size ()) then
    			break
    		end
    		
				-- preare for undo operation
        r:to_stateful():clear_changes()

        -- one means and one variances table per region name set
        if means[r:name ()] == nil then
          means[r:name ()] = {}
          variances[r:name ()] = {}
        end

        -- analyze the region
				ar = r:to_audioregion()
        vamp:analyze (ar:to_readable (), 0, nil)

				-- get remaining features
				local fl = vamp:plugin ():getRemainingFeatures ()

				 -- get the FeatureList
				local m_fl = fl:table()[3] -- [3] = Means
				local v_fl = fl:table()[4] -- [4] = Variances
				
				-- reset table for each region
				local me = {} -- means for region
				local va = {} -- variances for region
				
				for v in m_fl:at(0).values:iter () do
					if v > -1 and v < 1 then
						table.insert(me, v)
					end			
				end

				for v in v_fl:at(0).values:iter () do
					if v > -1 and v < 1 then
						table.insert(va, v)
					 end			
				end
				
				-- add region means and variances to master tables
				table.insert(means[r:name ()], me)
				table.insert(variances[r:name ()], va)
      		
        -- reset for next region
				vamp:reset ()

        -- add region to group
        if region_sets[r:name ()] == nil then
          region_sets[r:name ()] = {}
        end
        
        table.insert(region_sets[r:name ()], r)
      end

      -- lock region_sets based on similarity
      local progress = 0
      for k, set in pairs(region_sets) do

        -- Update progress
    		if pdialog:progress (progress / #region_sets, "Processing: " .. progress .. "/" .. #region_sets) then
    			break
    		end

        local count = {}
          
        if #set > 1 then

  		    local similarities = compareSimilarities(means[k], variances[k])

          local indexes = findMostSimilar(similarities)

          for _, index in pairs(indexes) do

            if #count < rv.count then
              table.insert(count, set[index])
              set[index]:set_locked (true)
            end
          
    				if not Session:add_stateful_diff_command(set[index]:to_statefuldestructible()):empty() then
    					add_undo = true
    				end
          end
        else
          set[1]:set_locked (true)

          if not Session:add_stateful_diff_command(set[1]:to_statefuldestructible()):empty() then
            add_undo = true
          end
        end

        progress = progress + 1
        
      end 
    end

		od = nil
		collectgarbage ()
		
  	-- all done. now commit the combined undo operation
  	if add_undo then
  		-- the 'nil' command here means to use all collected diffs
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