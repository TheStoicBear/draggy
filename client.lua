-- State variables
local uiOpen = false
local mode = "race"
local benchmarkState = "idle"
local vehicle = nil
local startPosition = nil
local startTime = 0
local updateInterval = 100

local speedBenchmarks = {60, 100, 120}
local distanceBenchmarks = {0.125, 0.25, 0.5, 1}

local benchmarkData = {
  speedTimes = {},
  distanceTimes = {},
  topSpeed = 0
}

local performanceStats = nil

-- Converts
local function toMPH(speedMPS)
  return speedMPS * 2.23694
end

local function toMiles(distanceMeters)
  return distanceMeters * 0.000621371
end

-- Vehicle info
local function getVehicleInfo(veh)
  if not veh or not DoesEntityExist(veh) then return "-", "-" end
  local model = GetEntityModel(veh)
  local vehicleName = GetDisplayNameFromVehicleModel(model)
  local vehicleClass = GetVehicleClass(veh)

  local classNames = {
    [0] = "Compacts", [1] = "Sedans", [2] = "SUVs", [3] = "Coupes",
    [4] = "Muscle", [5] = "Sports Classics", [6] = "Sports",
    [7] = "Super", [8] = "Motorcycles", [9] = "Off-road", [10] = "Industrial",
    [11] = "Utility", [12] = "Vans", [13] = "Cycles", [14] = "Boats",
    [15] = "Helicopters", [16] = "Planes", [17] = "Service", [18] = "Emergency",
    [19] = "Military", [20] = "Commercial", [21] = "Trains"
  }

  return vehicleName, classNames[vehicleClass] or tostring(vehicleClass)
end

-- Power + torque
local function getVehicleWheelPowerStats(veh)
  if not veh or not DoesEntityExist(veh) then
    return {
      totalRaw = 0, averageRaw = 0, maxRaw = 0,
      totalHP = 0, averageHP = 0, maxHP = 0,
      totalTorque = 0, averageTorque = 0, maxTorque = 0
    }
  end

  local numWheels = GetVehicleNumberOfWheels(veh)
  if numWheels <= 0 then return {} end

  local totalRaw, maxRaw = 0.0, 0.0

  for i = 0, numWheels - 1 do
    local success, rawValue = pcall(function()
      return GetVehicleWheelPower(veh, i)
    end)
    if success and rawValue then
      totalRaw = totalRaw + rawValue
      if rawValue > maxRaw then maxRaw = rawValue end
    end
  end

  local avgRaw = totalRaw / numWheels
  local HP = avgRaw * 1000
  local torque = avgRaw * 1200

  return {
    totalRaw = totalRaw, averageRaw = avgRaw, maxRaw = maxRaw,
    averageHP = HP, maxHP = maxRaw * 1000,
    averageTorque = torque, maxTorque = maxRaw * 1200
  }
end

-- UI update function
local function updateUI(data)
  SendNUIMessage(data)
end

-- Reset benchmark data
local function resetBenchmarks()
  benchmarkData = {
    speedTimes = {},
    distanceTimes = {},
    topSpeed = 0
  }
  performanceStats = nil
end

-- Drag race loop
local function dragRaceLoop()
  print("[DragRace] Drag race benchmark started")
  benchmarkState = "waiting"
  startTime = GetGameTimer()
  startPosition = GetEntityCoords(vehicle)
  resetBenchmarks()

  while uiOpen and mode == "race" do
    Wait(updateInterval)

    if not vehicle or not DoesEntityExist(vehicle) then
      print("[DragRace] Vehicle no longer exists. Ending benchmark.")
      break
    end

    local speedMPS = GetEntitySpeed(vehicle)
    local speedMPH = toMPH(speedMPS)
    local currentPos = GetEntityCoords(vehicle)
    local distanceMiles = toMiles(#(currentPos - startPosition))
    local currentTime = GetGameTimer()
    local elapsedTime = (currentTime - startTime) / 1000

    if speedMPH > benchmarkData.topSpeed then
      benchmarkData.topSpeed = speedMPH
    end

    if benchmarkState == "waiting" then
      updateUI({
        action = "status",
        text = "Waiting for you to Stop",
        statusColor = "#FFA500"
      })

      if speedMPS <= 1.0 then
        benchmarkState = "ready"
        updateUI({
          action = "status",
          text = "READY!",
          statusColor = "#00FF00"
        })
        print("[DragRace] Vehicle stopped. READY!")
      end

    elseif benchmarkState == "ready" then
      if speedMPS > 1.0 then
        benchmarkState = "tracking"
        startTime = GetGameTimer()
        startPosition = GetEntityCoords(vehicle)
        print("[DragRace] Vehicle started moving. Benchmark tracking begins.")
      end

    elseif benchmarkState == "tracking" then
      -- Benchmarks for speed
      for _, target in ipairs(speedBenchmarks) do
        local label = "0-" .. target
        if not benchmarkData.speedTimes[label] and speedMPH >= target then
          benchmarkData.speedTimes[label] = elapsedTime
          print(string.format("[DragRace] Reached %s MPH in %.2fs", target, elapsedTime))
        end
      end

      local distanceLabels = {"1/8 Mile", "1/4 Mile", "1/2 Mile", "1 Mile"}
      for i, target in ipairs(distanceBenchmarks) do
        local label = distanceLabels[i]
        if not benchmarkData.distanceTimes[label] and distanceMiles >= target then
          benchmarkData.distanceTimes[label] = elapsedTime
          print(string.format("[DragRace] Reached %s in %.2fs", label, elapsedTime))
        end
      end

      -- One-time power snapshot
      if not performanceStats then
        performanceStats = getVehicleWheelPowerStats(vehicle)
      end

      local vehicleName, vehicleClass = getVehicleInfo(vehicle)

      updateUI({
        action = "update",
        speed = speedMPH,
        topSpeed = benchmarkData.topSpeed,
        elapsedTime = elapsedTime,
        speedTimes = benchmarkData.speedTimes,
        distanceTimes = benchmarkData.distanceTimes,
        vehicleName = vehicleName,
        vehicleClass = vehicleClass,
        performance = performanceStats,
        status = "Racing...",
        statusColor = "#00BFFF"
      })

      if speedMPS <= 1.0 and elapsedTime > 2 then
        benchmarkState = "completed"
        updateUI({
          action = "status",
          text = "Race Completed!",
          statusColor = "#FF1493"
        })
        print("[DragRace] Race completed.")
      end
    end
  end

  -- Final UI update with stats
  updateUI({
    action = "update",
    topSpeed = benchmarkData.topSpeed,
    performance = performanceStats or {}
  })

  print("[DragRace] Drag race benchmark loop ended")
end

-- When using a useable item from qb-inventory, the server triggers the event below.
if Config.useItem then
  RegisterNetEvent('dragRace:useItem', function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
      TriggerEvent('chat:addMessage', {
        args = {"[DragRacing] You must be in a vehicle to start drag racing!"}
      })
      return
    end

    vehicle = GetVehiclePedIsIn(ped, false)
    mode = "race"

    if uiOpen then
      uiOpen = false
      benchmarkState = "idle"
      updateUI({ action = "close" })
      print("[DragRace] Drag racing UI closed.")
    else
      uiOpen = true

      local vehicleName, vehicleClass = getVehicleInfo(vehicle)
      updateUI({
        action = "open",
        vehicleName = vehicleName,
        vehicleClass = vehicleClass,
        performance = getVehicleWheelPowerStats(vehicle),
        status = "Waiting for you to Stop",
        position = { x = 50, y = 10 },
        scale = 1
      })
      print("[DragRace] Drag racing UI opened. Waiting for vehicle to stop.")
      Citizen.CreateThread(dragRaceLoop)
    end
  end)
else
  -- Standalone / command mode: use the asynchronous item check via ox or qb inventory.
  local function canUseDragFeature(source, cb)
    if not Config.useItem then
      print("[DragRace] Config.useItem is false — items will NOT be used; enabling drag race via command")
      cb(true)
      return
    end

    if Config.inventory == "ox" then
      print("[DragRace] Checking item via ox_inventory")
      local items = exports.ox_inventory:Items()
      if items[Config.itemName] then
        print("[DragRace] Found item " .. Config.itemName .. " in ox_inventory")
        cb(true)
      else
        print("[DragRace] Item " .. Config.itemName .. " not found in ox_inventory")
        cb(false)
      end
    elseif Config.inventory == "qb" then
      print("[DragRace] Using Usable Item via qb-inventory (server callback)")
    else
      print("[DragRace] Invalid inventory configuration.")
      cb(false)
    end
  end

  -- Command to start the drag race using the asynchronous item check.
  RegisterCommand("draggy", function(source)
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
      TriggerEvent('chat:addMessage', {
        args = {"[DragRacing] You must be in a vehicle to start drag racing!"}
      })
      return
    end

    canUseDragFeature(source, function(allowed)
      if not allowed then
        TriggerEvent('chat:addMessage', {
          args = {"[DragRacing] You don't have the required item: " .. Config.itemName}
        })
        return
      end

      vehicle = GetVehiclePedIsIn(ped, false)
      mode = "race"

      if uiOpen then
        uiOpen = false
        benchmarkState = "idle"
        updateUI({ action = "close" })
        print("[DragRace] Drag racing UI closed.")
      else
        uiOpen = true

        local vehicleName, vehicleClass = getVehicleInfo(vehicle)
        updateUI({
          action = "open",
          vehicleName = vehicleName,
          vehicleClass = vehicleClass,
          performance = getVehicleWheelPowerStats(vehicle),
          status = "Waiting for you to Stop",
          position = { x = 50, y = 10 },
          scale = 1
        })
        print("[DragRace] Drag racing UI opened. Waiting for vehicle to stop.")
        Citizen.CreateThread(dragRaceLoop)
      end
    end)
  end, false)
end

-- Backspace key listener to close the UI.
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(0)
    if uiOpen and IsControlJustPressed(0, 177) then -- 177 = Backspace
      uiOpen = false
      benchmarkState = "idle"
      updateUI({ action = "close" })
      print("[DragRace] Drag racing UI closed via backspace.")
    end
  end
end)
