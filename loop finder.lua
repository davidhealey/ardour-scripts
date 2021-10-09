ardour {
	["type"]    = "EditorAction",
	name        = "Loop Finder",
	license     = "MIT",
	author      = "David Healey",
	description = [[Implementation of LoopAuditioneer's Auto Looper.]]
}

function factory ()
  return function ()

    local sr = Session:nominal_sample_rate ()
    local sel = Editor:get_selection ()
    local rl = sel.regions:regionlist ()
  	local bufferSize = sr / 20
    local cmem = ARDOUR.DSP.DspShm (bufferSize)
    local pdialog -- progress dialog
    local progress = 0

    -- customisable
    local m_startPercentage = 20
    local m_endPercentage = 70
    local m_derivativeThreshold = 0.03
    local m_maxCandidates = 60000
    local m_minLoopDuration = 4.0
    local m_qualityFactor = 6
    local m_distanceBetweenLoops = 0.3
    local m_loopsToReturn = 1

    -- FUNCTIONS --
    function sortByPosition(a, b)
      return a:position() < b:position()
    end

    function sortLoopsByQuality(a, b)
      return a[3] > b[3]
    end

    function round(n)
      return n + 0.5 - (n + 0.5) % 1
    end

    function getAmplitudes(r)

  		local rd = r:to_readable ()
  		local n_samples = rd:readable_length ()
  		local amplitudes = {}

			local pos = 0
			repeat

				-- read at most 8K samples of channel 'c' starting at 'pos'
				local s = rd:read (cmem:to_float (0), pos, bufferSize, 0)

				local d = cmem:to_float (0):array()

				for i = 1, s do
				  table.insert(amplitudes, d[i])
				end

  			if pdialog:progress (pos / n_samples, "Region: " .. progress .. "/" .. rl:size() .. " Analyzing Amplitude") then break end -- Update progress

  			pos = pos + s

			until s < bufferSize

      return amplitudes
    end

    function getMax(t)
      local key, max = 1, t[1]
      for k, v in ipairs(t) do
        if t[k] > max then
            key, max = k, v
        end
      end
      return max
    end

    function findSustainStart(r)

      local result = nil
  		local rd = r:to_readable ()
  		local n_samples = rd:readable_length ()
  		local maxAmplitude = 0

			local pos = round(n_samples / 100 * 5)
			repeat

				local s = rd:read (cmem:to_float (0), pos, bufferSize, 0)

				local d = cmem:to_float (0):array()

        local maxWindowValue = 0

				for i = 1, s do
					if d[i] > maxWindowValue then
					  maxWindowValue = d[i]
					end
				end

				if maxWindowValue > maxAmplitude then
				  maxAmplitude = maxWindowValue
				else
				  result = pos + sr / 4
        end

        if pdialog:progress (pos / n_samples, "Region: " .. progress .. "/" .. rl:size() .. " Finding sustain start") then break end -- Update progress

				pos = pos + s

			until s < bufferSize or result ~= nil

      return result

    end

    function findSustainEnd(r, maxValue)

      local result = nil
      local rd = r:to_readable ()
  		local n_samples = rd:readable_length ()
			local maxAmplitude = 0

      local pos = n_samples
			repeat

				local s = rd:read (cmem:to_float (0), pos-bufferSize, bufferSize, 0)

				local d = cmem:to_float (0):array()

        local maxWindowValue = 0

				for i = s, 1, -1 do
				  if d[i] > maxWindowValue then
					  maxWindowValue = d[i]
					end
				end

        if maxWindowValue < maxValue / 4 then
          maxAmplitude = maxWindowValue;
          goto next
        end

        if maxWindowValue > maxAmplitude then
          maxAmplitude = maxWindowValue;
        else
          result = pos
        end

				::next::

				if pdialog:progress ((n_samples-pos) / n_samples, "Region: " .. progress .. "/" .. rl:size() .. " Finding sustain end") then break end -- Update progress

				pos = pos - s

			until pos <= 0 or result ~= nil

			return result

    end

    function findStrongestDerivative(amplitudes, sustainStart, sustainEnd)

      local maxDerivative = 0

      local total = sustainEnd - sustainStart;
      local increment = total / 100
      local count = 0
      for i=sustainStart+1, sustainEnd-1, 1 do

				local currentDerivative = math.abs(amplitudes[i+1] - amplitudes[i])

        if currentDerivative > maxDerivative then
          maxDerivative = currentDerivative
        end

        if count > increment then
          if pdialog:progress (i / sustainEnd, "Region: " .. progress .. "/" .. rl:size() .. " Finding max derivative") then break end -- Update progress
          count = 0
        end
        count = count + 1
      end

      return maxDerivative

    end

    function getAllCandidates(amplitudes, sustainStart, sustainEnd, maxDerivative)

      local result = {}
      local derivativeThreshold = maxDerivative * m_derivativeThreshold;

      local total = sustainEnd - sustainStart;
      local increment = total / 100
      local count = 0
      for i=sustainStart+1, sustainEnd-1, 1 do
        local currentDerivative = math.abs(amplitudes[i+1] - amplitudes[i])

        if currentDerivative < derivativeThreshold then
          maxDerivative = currentDerivative
          table.insert(result, i)
        end

        if count > increment then
          if pdialog:progress (i / sustainEnd, "Region: " .. progress .. "/" .. rl:size() .. " Finding candidates") then break end -- Update progress
          count = 0
        end
        count = count + 1
      end

      return result

    end

    function limitAndDistributeCandidates(allCandidates)

      if #allCandidates > m_maxCandidates then
        local result = {}
        local totalAmountOfCandidates = #allCandidates
        local increment = totalAmountOfCandidates / m_maxCandidates

        for i = 0, m_maxCandidates, 1 do
          local index = i * increment
          if index < totalAmountOfCandidates-1 then
            table.insert(result, allCandidates[index])
          end

          if pdialog:progress (i / m_maxCandidates, "Region: " .. progress .. "/" .. rl:size() .. " Filter candidates") then break end -- Update progress

        end

        return result;
      else -- just return allCandidates
        return allCandidates
      end

    end

    function crossCorrelate(amplitudes, candidates)

      local result = {}

      local loop = {}
      local increment = #candidates / 100
      local count = increment + 1
      for i = 1, #candidates, 1 do

        -- find start point
        local loopStartIndex = candidates[i] - 1
        local compareStartIndex = loopStartIndex - 2

        -- if loop start point is too close to last loop then continue
        if #result > 0 then
          if loopStartIndex - result[#result][1] < sr * m_distanceBetweenLoops then
            goto continue
          end
        end

        -- Update progress
        if count > increment then
          if pdialog:progress (i / #candidates, "Region: " .. progress .. "/" .. rl:size() .. " Cross correlating (might take a while) ") then
            goto exit
          end
          count = 0
        end
        count = count + 1

        loop = {} -- clear loop

        -- compare to end point candidates
        for j = i + 1, #candidates, 1 do

          local loopEndIndex = candidates[j] - 1
          local compareEndIndex = loopEndIndex - 2

          -- check if end is too close to start
          if loopEndIndex - loopStartIndex < sr * m_minLoopDuration then
            goto next
          end

          -- cross correlate
          local sum = 0
          local correlationValue = 0

          for k = 0, 5, 1 do
            sum = sum + (amplitudes[compareStartIndex + k] - amplitudes[compareEndIndex + k]) ^ 2
            correlationValue = math.sqrt(sum / 5)
          end

          --[[if the quality of the correlation is above quality threshold add the loop
          but remove one sample from end index for a better loop match]]
          if correlationValue < m_qualityFactor / 32767 then
            loop[1] = loopStartIndex
            loop[2] = loopEndIndex
            loop[3] = correlationValue
            table.insert(result, loop)
            break
          end

          ::next::

        end

        -- stop after finding 21 loops, these will be further filtered to get the best quality
        if #result > 20 then
          break
        end

        ::continue::
      end

      ::exit::

      return result
    end

    function removeMarksBetween(start, _end)
      local locs = ARDOUR.LocationList ()
      local marks = Session:locations():find_all_between(start+1, _end-1, locs, ARDOUR.LocationFlags.IsMark)

      for m in locs:iter() do
        Session:locations():remove(m)
      end

    end

    -- MAIN --

    -- setup dialog
  	local dialog_options = {
  	  {type = "checkbox", key = "autosearch", title = "Autosearch Sustain", default = false},
  		{type = "slider", key = "startpercent", title = "Sustain start at (%)", min = 1, max = 100, default = 10},
  		{type = "slider", key = "endpercent", title = "Sustain end at (%)", min = 1, max = 100, default = 70},
  		{type = "slider", key = "quality", title = "Quality Factor (lower = better)", min = 1, max = 100, default = 30},
      {type = "number", key = "duration", title = "Min loop length (s)", min = 0.5, max = 5, digits = 1, default = 3},
      {type = "number", key = "distance", title = "Min Distance between loops (s)", min = 0.1, max = 5, digits = 1, default = 0.5},
      {type = "number", key = "loopstofind", title = "Loops to return", min = 1, max = 3, default = 1},
      {type = "checkbox", key = "removeold", title = "Remove Existing Location Markers", default = true}
  	}

   	local od = LuaDialog.Dialog ("Loop Finder", dialog_options)
    local rv = od:run ()

  	if (rv) then

      pdialog = LuaDialog.ProgressWindow ("Loop Finder", true)

      m_startPercentage = rv.startpercent
      m_endPercentage = rv.endpercent
      m_minLoopDuration = rv.duration
      m_qualityFactor = rv.quality
      m_distanceBetweenLoops = rv.distance
      m_loopsToReturn = rv.loopstofind

      local notFound = {}

      -- sort regions by position
      local regions = {};
			for key, r in pairs(rl:table()) do
				table.insert(regions, r)
			end
			table.sort(regions, sortByPosition)

      -- process regions
      for i, r in ipairs (regions) do

        progress = i

        -- remove old marks
        if rv.removeold == true then
          removeMarksBetween(r:position(), r:position() + r:length())
        end

        -- get all amplitudes
        local amplitudes = getAmplitudes(r)

        -- Update progress

        -- get maximum amplitude
        local maxAmplitude = getMax(amplitudes)

        local sustainStart, sustainEnd
        if rv.autosearch == false and m_startPercentage < m_endPercentage then -- manual sustain are specified
          sustainStart = round(r:length() / 100 * m_startPercentage)
          sustainEnd = round(r:length() / 100 * m_endPercentage)
        else -- auto search for sustain area
          sustainStart = findSustainStart(r)
          sustainEnd = findSustainEnd(r, maxAmplitude)
        end

        if sustainStart ~= nil and sustainEnd ~= nil and sustainStart < sustainEnd then

          local maxDerivative = findStrongestDerivative(amplitudes, sustainStart, sustainEnd) -- get max derivative

          local allCandidates
          if maxDerivative ~= nil then
            allCandidates = getAllCandidates(amplitudes, sustainStart, sustainEnd, maxDerivative) -- get all candidates
          end

          local candidates
          if #allCandidates > 0 then
            candidates = limitAndDistributeCandidates(allCandidates); -- filter candidates
          end

          if #candidates > 0 then
            local loops = crossCorrelate(amplitudes, candidates) -- cross correlate candidates

            if loops == nil then
              table.insert(notFound, r:name())
            else

              -- get the highest quality loops
              table.sort(loops, sortLoopsByQuality)

              local loop
              for i = 1, m_loopsToReturn, 1 do

                loop = loops[i]

                if loop ~= nil then
                  -- add markers to session
                  Editor:add_location_mark(r:position()+loop[1])
                  Editor:add_location_mark(r:position()+loop[2])

                  local marks = {}

                  marks[1] = Session:locations():mark_at(r:position()+loop[1], sr / 100)
                  marks[2] = Session:locations():mark_at(r:position()+loop[2], sr / 100)

                  marks[1]:set_name (i .. " LOOP START-" .. round(loop[1]))
                  marks[2]:set_name (i .. " LOOP END-" .. round(loop[2]))

                  marks[1]:lock ()
                  marks[2]:lock ()
                end
              end
            end
          end
        end
      end

      -- report if loops were not found
      if #notFound > 0 then
        local msg = "Could not find loops for the following regions:\r"
        for i = 1, #notFound, 1 do
          msg = msg .. notFound[i] .. "\r"
        end

        local d = LuaDialog.Message ("Loop Finder", msg, LuaDialog.MessageType.Info, LuaDialog.ButtonType.OK)
        d:run()
      end
    end

    od = nil
  	collectgarbage ()

  	-- hide modal progress dialog and destroy it
  	if pdialog ~= nil then
      pdialog:done ()
  	end

  end
end
