Config = Config or {}

Config.FrameworkResource = Config.FrameworkResource or 'Az-Framework'
Config.DebugJobChecks = Config.DebugJobChecks ~= false
Config.JobName = 'miner'

-- Job Center DB mapping (used for /quitjob if no framework setter is available)
Config.DB = Config.DB or {
  table            = 'user_characters',
  identifierColumn = 'charid',
  jobColumn        = 'active_department'
}
Config.UseAzFrameworkCharacter = (Config.UseAzFrameworkCharacter ~= false)

-- Uses Az-Framework export you provided:
-- exports['Az-Framework']:getPlayerJob(source)
Config.GetPlayerJob = Config.GetPlayerJob or function(source)
    local ok, job = pcall(function()
        return exports[Config.FrameworkResource]:getPlayerJob(source)
    end)
    if ok then
        if type(job) == 'table' then
            job = job.name or job.job or job.label or job.id
        end
        if job ~= nil then
            local s = tostring(job):gsub("^%s+",""):gsub("%s+$","")
            if s ~= "" then return string.lower(s) end
        end
    end
    return 'civ'
end

Config.InteractKey = Config.InteractKey or 38 -- E
Config.ActionKey   = Config.ActionKey or 47 -- G



Config.MineCooldownMs = 2000
Config.MineTimeMs = 2500
Config.QuarrySpots = {
  vector3(2954.6, 2785.1, 41.5),
  vector3(2947.1, 2796.2, 41.3),
  vector3(2939.2, 2809.6, 41.4),
}
Config.SellPoint = vector3(2966.5, 2758.0, 43.3)

Config.Minerals = {
  { id="stone", label="Stone", min=1, max=3, sellMin=18, sellMax=32 },
  { id="iron",  label="Iron Ore", min=1, max=2, sellMin=55, sellMax=95 },
  { id="gold",  label="Gold Nugget", min=1, max=1, sellMin=140, sellMax=220 },
}
