function az_miner_notify(msg)
  BeginTextCommandThefeedPost("STRING")
  AddTextComponentSubstringPlayerName(tostring(msg))
  EndTextCommandThefeedPostTicker(false, false)
end

function az_miner_help(msg)
  BeginTextCommandDisplayHelp("STRING")
  AddTextComponentSubstringPlayerName(tostring(msg))
  EndTextCommandDisplayHelp(0, false, true, -1)
end

function az_miner_doAction(label, ms)
  local ped = PlayerPedId()
  FreezeEntityPosition(ped, true)
  local start = GetGameTimer()
  while GetGameTimer() - start < ms do
    Wait(0)
    DisableAllControlActions(0)
    BeginTextCommandPrint("STRING")
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandPrint(1, true)
  end
  FreezeEntityPosition(ped, false)
end

RegisterNetEvent('az_miner:notify', function(msg) az_miner_notify(msg) end)

local uiOpen = false
local nuiReady = false
local pending = nil

RegisterNUICallback('ready', function(_, cb)
  nuiReady = true
  if pending then
    SendNUIMessage(pending)
    pending = nil
  end
  cb({{ ok=true }})
end)

local function nuiSend(msg)
  if nuiReady then
    SendNUIMessage(msg)
  else
    pending = msg
    CreateThread(function()
      local t0 = GetGameTimer()
      while not nuiReady and (GetGameTimer() - t0) < 4000 do
        Wait(100)
      end
      if nuiReady and pending then
        SendNUIMessage(pending)
        pending = nil
      end
    end)
  end
end


local function uiSet(open)
  uiOpen = open
  SetNuiFocus(open, open)
  SetNuiFocusKeepInput(false)
  if open and true then
    if SetCursorLocation then SetCursorLocation(0.5, 0.5) end
  end
end

RegisterNUICallback('close', function(_, cb)
  uiSet(false)
  cb({ ok=true })
end)

RegisterNUICallback('sell', function(_, cb)
  uiSet(false)
  TriggerServerEvent('az_miner:bag:sell')
  cb({ ok=true })
end)

RegisterNetEvent('az_miner:bag:open', function(payload)
  uiSet(true)
  nuiSend({ type='bag:open', kind=payload.kind, items=payload.items or {}, canSell=payload.canSell==true })
end)

RegisterNetEvent('az_miner:bag:update', function(payload)
  nuiSend({ type='bag:update', kind=payload.kind, items=payload.items or {} })
end)

CreateThread(function()
  while true do
    Wait(0)
    if uiOpen and (IsControlJustPressed(0, 200) or IsControlJustPressed(0, 177)) then
      uiSet(false)
    end
  end
end)


RegisterCommand('minerals', function()
  TriggerServerEvent('az_miner:bag:open')
end)

local lastMine = 0

CreateThread(function()
  while true do
    Wait(0)
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)

    for _, spot in ipairs(Config.QuarrySpots) do
      local dist = #(p - spot)
      if dist < 25.0 then
        DrawMarker(2, spot.x, spot.y, spot.z+0.2, 0,0,0, 0,180,0, 0.45,0.45,0.45, 230,57,70,170, false,true,2,false,nil,nil,false)
      end
      if dist < 1.6 then
        az_miner_help("Press ~INPUT_CONTEXT~ to mine")
        if IsControlJustPressed(0, Config.InteractKey) then
          local now = GetGameTimer()
          if now - lastMine < Config.MineCooldownMs then
            az_miner_notify("You're mining too fast.")
          else
            lastMine = now
            az_miner_doAction("Mining...", Config.MineTimeMs)
            local pick = Config.Minerals[math.random(1, #Config.Minerals)]
            local amt = math.random(pick.min, pick.max)
            TriggerServerEvent('az_miner:mine:give', pick.id, amt)
            az_miner_notify(("You found %dx %s"):format(amt, pick.label))
          end
        end
      end
    end

    local sellDist = #(p - Config.SellPoint)
    if sellDist < 25.0 then
      DrawMarker(2, Config.SellPoint.x, Config.SellPoint.y, Config.SellPoint.z+0.2, 0,0,0, 0,180,0, 0.55,0.55,0.55, 230,57,70,170, false,true,2,false,nil,nil,false)
    end
    if sellDist < 1.9 then
      az_miner_help("Press ~INPUT_DETONATE~ to sell minerals")
      if IsControlJustPressed(0, Config.ActionKey) then
        TriggerServerEvent('az_miner:bag:sell')
      end
    end
  end
end)
