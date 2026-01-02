local fw = exports[Config.FrameworkResource]

local function dbg(src, msg)
  if not Config.DebugJobChecks then return end
  print(("[az_miner][debug][%s] %s"):format(tostring(src), tostring(msg)))
end

local function getJob(src)
  local ok, j = pcall(Config.GetPlayerJob, src)
  if ok and j then return tostring(j) end
  return "civ"
end

local function ensureJob(src)
  local job = getJob(src)
  if job ~= Config.JobName then
    dbg(src, ("DENY: expected=%s got=%s"):format(Config.JobName, job))
    return false, job
  end
  return true, job
end

local function payCash(src, amount)
  amount = math.floor(tonumber(amount) or 0)
  if amount <= 0 then return end
  fw:addMoney(src, amount)
end

local function takeCash(src, amount, cb)
  amount = math.floor(tonumber(amount) or 0)
  if amount <= 0 then return cb and cb(true) end
  fw:GetPlayerMoney(src, function(err, wallet)
    if err then return cb and cb(false, "wallet_error") end
    wallet = wallet or {}
    local cash = tonumber(wallet.cash or 0) or 0
    if cash < amount then return cb and cb(false, "not_enough_cash") end
    fw:deductMoney(src, amount)
    cb(true)
  end)
end

-- /quitjob (resign) support:
-- 1) tries framework setter if available
-- 2) falls back to DB update using oxmysql or MySQL wrapper
local function getCharId(src)
  if not Config.UseAzFrameworkCharacter then return nil end
  local ok, c = pcall(function() return exports[Config.FrameworkResource]:GetPlayerCharacter(src) end)
  if ok and c then return c end
  return nil
end

local function dbUpdateJob(charId, newJob, cb)
  local t = Config.DB and Config.DB.table or 'user_characters'
  local idc = Config.DB and Config.DB.identifierColumn or 'charid'
  local jc = Config.DB and Config.DB.jobColumn or 'active_department'
  local q = ("UPDATE %s SET %s = ? WHERE %s = ?"):format(t, jc, idc)

  if exports.oxmysql and exports.oxmysql.update then
    exports.oxmysql:update(q, { newJob, charId }, function(affected)
      cb(true, affected or 0)
    end)
    return
  end

  if MySQL and MySQL.update then
    MySQL.update(q, { newJob, charId }, function(affected)
      cb(true, affected or 0)
    end)
    return
  end

  cb(false, "no_mysql")
end

local function setJob(src, newJob, cb)
  newJob = tostring(newJob or "unemployed")
  local ok, hasSetter = pcall(function()
    return type(exports[Config.FrameworkResource].setPlayerJob) == "function"
  end)
  if ok and hasSetter then
    local ok2, err = pcall(function()
      exports[Config.FrameworkResource]:setPlayerJob(src, newJob)
    end)
    if ok2 then
      cb(true, "framework")
    else
      cb(false, err or "setter_failed")
    end
    return
  end

  local charId = getCharId(src)
  if not charId then
    cb(false, "no_char")
    return
  end

  dbUpdateJob(charId, newJob, function(ok3, info)
    if ok3 then
      cb(true, "db")
      if exports[Config.FrameworkResource].sendMoneyToClient then
        pcall(function() exports[Config.FrameworkResource]:sendMoneyToClient(src) end)
      end
    else
      cb(false, info)
    end
  end)
end

_G['AZ_MINER_SV'] = _G['AZ_MINER_SV'] or {}
local SV = _G['AZ_MINER_SV']
SV.dbg = dbg
SV.getJob = getJob
SV.ensureJob = ensureJob
SV.payCash = payCash
SV.takeCash = takeCash
SV.setJob = setJob

RegisterCommand('az_minerdebug', function(source)
  local src = source
  if src == 0 then
    print("[az_miner] use this in-game")
    return
  end
  local j = getJob(src)
  dbg(src, ("job=%s"):format(j))
  TriggerClientEvent('az_miner:notify', src, ("[az_miner] job=%s (see server console)"):format(j))
end, false)

RegisterCommand('quitjob', function(source)
  local src = source
  if src == 0 then return end
  setJob(src, "unemployed", function(ok4, how)
    if ok4 then
      dbg(src, "quitjob OK via " .. tostring(how))
      TriggerClientEvent('az_miner:notify', src, "You quit your job. (unemployed)")
    else
      dbg(src, "quitjob FAIL: " .. tostring(how))
      TriggerClientEvent('az_miner:notify', src, "Could not quit job (missing setter/DB). Use Job Center.")
    end
  end)
end, false)

local function safeDiscord(src)
  local ok, d = pcall(function() return exports[Config.FrameworkResource]:getDiscordID(src) end)
  if ok and d and d ~= "" then return tostring(d) end
  return "src_" .. tostring(src)
end

local function safeChar(src)
  local ok, c = pcall(function() return exports[Config.FrameworkResource]:GetPlayerCharacter(src) end)
  if ok and c then return tostring(c) end
  return "0"
end

local function kvpKey(src, name)
  return ("az_miner:%s:%s:%s"):format(name, safeDiscord(src), safeChar(src))
end

local function kvpGet(src, name)
  local raw = GetResourceKvpString(kvpKey(src, name))
  if not raw or raw == "" then return {} end
  local ok, data = pcall(json.decode, raw)
  if ok and type(data) == "table" then return data end
  return {}
end

local function kvpSet(src, name, data)
  SetResourceKvp(kvpKey(src, name), json.encode(data or {}))
end


local function bag(src) return kvpGet(src, "bag") end
local function setBag(src, b) kvpSet(src, "bag", b) end

RegisterNetEvent('az_miner:bag:open', function()
  local src = source
  local ok = _G['AZ_MINER_SV'].ensureJob(src)
  if not ok then
    TriggerClientEvent('az_miner:notify', src, "You are not employed for Miner.")
    return
  end
  TriggerClientEvent('az_miner:bag:open', src, { kind="minerals", items=bag(src), canSell=true })
end)

RegisterNetEvent('az_miner:mine:give', function(itemId, amount)
  local src = source
  local ok = _G['AZ_MINER_SV'].ensureJob(src)
  if not ok then return end
  itemId = tostring(itemId or "")
  amount = math.floor(tonumber(amount) or 0)
  if itemId == "" or amount <= 0 then return end

  local b = bag(src)
  b[itemId] = (tonumber(b[itemId] or 0) or 0) + amount
  setBag(src, b)
  TriggerClientEvent('az_miner:bag:update', src, { kind="minerals", items=b })
end)

RegisterNetEvent('az_miner:bag:sell', function()
  local src = source
  local ok = _G['AZ_MINER_SV'].ensureJob(src)
  if not ok then
    TriggerClientEvent('az_miner:notify', src, "You are not employed for Miner.")
    return
  end

  local b = bag(src)
  local total = 0
  for _, it in ipairs(Config.Minerals) do
    local qty = tonumber(b[it.id] or 0) or 0
    if qty > 0 then
      total = total + qty * math.random(it.sellMin, it.sellMax)
      b[it.id] = 0
    end
  end
  setBag(src, b)

  if total > 0 then
    exports[Config.FrameworkResource]:addMoney(src, total)
    TriggerClientEvent('az_miner:notify', src, ("Sold minerals for ~$%d"):format(total))
  else
    TriggerClientEvent('az_miner:notify', src, "Your minerals bag is empty.")
  end

  TriggerClientEvent('az_miner:bag:update', src, { kind="minerals", items=b })
end)
