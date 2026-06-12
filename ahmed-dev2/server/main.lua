local QBCore     = exports['qb-core']:GetCoreObject()
local Sprays     = {}
local Discovered = {}
local LastContestedAt = {}
local ContestTimers = {}
local RemoveTimers  = {}

local function fmt(entry, ...)
    if type(entry) == "table" then return entry[1]:format(...), entry[2] end
    return tostring(entry):format(...), "primary"
end

local function Notify(src, entry, ...)
    local msg, kind = fmt(entry, ...)
    TriggerClientEvent('QBCore:Notify', src, msg, kind)
end

local function GetGangLabel(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local cid = Player.PlayerData.citizenid
    local ok, data = pcall(function()
        return exports['op-crime']:getPlayerOrganisation(cid)
    end)
    if not ok or not data or not data.orgIndex then return nil end
    local orgData = data.orgData or {}
    local label = orgData.orgLabel or orgData.label or orgData.name
    if not label then
        local ok2, org = pcall(function() return exports['op-crime']:getOrganisation(data.orgIndex) end)
        if ok2 and org then label = org.orgLabel or org.label or org.name end
    end
    return label
end

local function PackCoords(coords, normal)
    return json.encode({
        x  = coords.x, y  = coords.y, z  = coords.z,
        nx = normal and normal.x or nil,
        ny = normal and normal.y or nil,
        nz = normal and normal.z or nil,
    })
end

local function UnpackRow(row)
    local data = json.decode(row.coords) or {}
    return {
        id                 = row.id,
        gang               = row.gang_name,
        coords             = { x = data.x, y = data.y, z = data.z },
        nx = data.nx, ny = data.ny, nz = data.nz,
        heading            = row.heading,
        contested          = row.is_contested == 1,
        contesting_gang    = row.contesting_gang,
        contest_started_at = row.contest_started_at,
        contest_ended_at   = row.contest_ended_at,
    }
end

local function BroadcastSpray(id)
    if Sprays[id] then
        TriggerClientEvent('spacecity_sprays:client:SyncSpray', -1, Sprays[id])
    end
end




local function AddGangXP(gangLabel, amount)
    if not gangLabel or not amount then return end
    local ok, gangData = pcall(function() return exports['op-crime']:GetOrganisationData(gangLabel) end)
    if ok and gangData and gangData.id then
        TriggerEvent('op-crime:addOrganisationEXP', gangData.id, amount)
    end
end

local function NotifyGang(gangLabel, entry, withSound)
    if not gangLabel then return end
    local msg, kind = fmt(entry)
    for _, Player in pairs(QBCore.Functions.GetQBPlayers()) do
        local src = Player.PlayerData.source
        if GetGangLabel(src) == gangLabel then
            TriggerClientEvent('QBCore:Notify', src, msg, kind)
            if withSound then
                TriggerClientEvent('spacecity_sprays:client:PlayAlert', src)
            end
        end
    end
end


local function CloseRemovalWindow(id)
    RemoveTimers[id] = nil
    local spray = Sprays[id]
    if not spray then return end
    if spray.contested then return end
    spray.contesting_gang  = nil
    spray.contest_ended_at = nil
    MySQL.Async.execute('UPDATE gang_sprays SET contesting_gang = NULL, contest_ended_at = NULL WHERE id = ?', { id })
    BroadcastSpray(id)
end

local function FinishContest(id)
    ContestTimers[id] = nil
    local spray = Sprays[id]
    if not spray or not spray.contested then return end
    spray.contested        = false
    spray.contest_ended_at = os.time() * 1000
    MySQL.Async.execute(
        'UPDATE gang_sprays SET is_contested = 0, contest_ended_at = ? WHERE id = ?',
        { spray.contest_ended_at, id }
    )
    BroadcastSpray(id)
    NotifyGang(spray.gang,            Config.Notify.ContestFinishedOwner,    true)
    NotifyGang(spray.contesting_gang, Config.Notify.ContestFinishedAttacker, true)
    RemoveTimers[id] = true
    SetTimeout(Config.RemoveWindowTime or 600000, function() CloseRemovalWindow(id) end)
end

local function StartContest(id, attackerGang)
    local spray = Sprays[id]
    if not spray then return end
    spray.contested          = true
    spray.contesting_gang    = attackerGang
    spray.contest_started_at = os.time() * 1000
    spray.contest_ended_at   = nil
    MySQL.Async.execute(
        'UPDATE gang_sprays SET is_contested = 1, contesting_gang = ?, contest_started_at = ?, contest_ended_at = NULL WHERE id = ?',
        { attackerGang, spray.contest_started_at, id }
    )
    BroadcastSpray(id)
    NotifyGang(spray.gang,   Config.Notify.ContestStartedOwner,    true)
    NotifyGang(attackerGang, Config.Notify.ContestStartedAttacker, true)
    AddGangXP(attackerGang, Config.XP.Contest)

    ContestTimers[id] = true
    SetTimeout(Config.ContestTime or 900000, function()
        if ContestTimers[id] then FinishContest(id) end
    end)
end


MySQL.ready(function()
    MySQL.Async.fetchAll('SELECT * FROM gang_sprays', {}, function(results)
        for _, v in pairs(results) do Sprays[v.id] = UnpackRow(v) end

        MySQL.Async.fetchAll('SELECT * FROM gang_discovered_sprays', {}, function(disc_results)
            for _, d in pairs(disc_results) do
                if not Discovered[d.gang_name] then Discovered[d.gang_name] = {} end
                Discovered[d.gang_name][d.spray_id] = true
            end
        end)

        local now = os.time() * 1000
        for id, s in pairs(Sprays) do
            if s.contested and s.contest_started_at then
                local remaining = (Config.ContestTime or 900000) - (now - s.contest_started_at)
                if remaining <= 0 then
                    FinishContest(id)
                else
                    ContestTimers[id] = true
                    SetTimeout(remaining, function()
                        if ContestTimers[id] then FinishContest(id) end
                    end)
                end
            elseif (not s.contested) and s.contest_ended_at then
                local remaining = (Config.RemoveWindowTime or 600000) - (now - s.contest_ended_at)
                if remaining <= 0 then
                    CloseRemovalWindow(id)
                else
                    RemoveTimers[id] = true
                    SetTimeout(remaining, function() CloseRemovalWindow(id) end)
                end
            end
        end
    end)
end)

------------------------------------------------------------------
-- Eventat!
-----------------------------------------------------------------------
RegisterNetEvent('spacecity_sprays:server:SaveSpray', function(_gangFromClient, coords, heading, normal)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gang = GetGangLabel(src)
    if not gang then
        Notify(src, Config.Notify.NotInOrg)
        return
    end
    if not Config.Gangs[gang] then
        Notify(src, Config.Notify.NoGangConfig, gang)
        return
    end
    if type(coords) ~= 'table' or not coords.x or not coords.y or not coords.z then
        Notify(src, Config.Notify.InvalidCoords)
        return
    end

    -- Must still have the item in inventory at save-time
    local sprayItemName = Config.SprayItem or "gang_spray"
    local item = Player.Functions.GetItemByName(sprayItemName)
    if not item then
        Notify(src, Config.Notify.NotInOrg) -- reuse a generic error; swap for your own key if you like
        return
    end

    MySQL.Async.insert('INSERT INTO gang_sprays (gang_name, coords, heading) VALUES (?, ?, ?)', {
        gang, PackCoords(coords, normal), heading
    }, function(id)
        Sprays[id] = {
            id = id, gang = gang,
            coords = { x = coords.x, y = coords.y, z = coords.z },
            nx = normal and normal.x or nil,
            ny = normal and normal.y or nil,
            nz = normal and normal.z or nil,
            heading = heading, contested = false,
            contesting_gang = nil, contest_started_at = nil, contest_ended_at = nil,
        }
        TriggerClientEvent('spacecity_sprays:client:SyncNewSpray', -1, Sprays[id])

        -- Remove 1x gang_spray from the player's inventory
        Player.Functions.RemoveItem(sprayItemName, 1)
        if QBCore.Shared and QBCore.Shared.Items and QBCore.Shared.Items[sprayItemName] then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[sprayItemName], "remove")
        end

        Notify(src, Config.Notify.PlacedOk)
    end)
end)

RegisterNetEvent('spacecity_sprays:server:DiscoverSpray', function(sprayId)
    local src = source
    local myGang = GetGangLabel(src)
    if not myGang then return end
    local spray = Sprays[sprayId]
    if not spray then return end
    if myGang == spray.gang then return end

    if not Discovered[myGang] then Discovered[myGang] = {} end
    if not Discovered[myGang][sprayId] then
        Discovered[myGang][sprayId] = true
        MySQL.Async.execute(
            'INSERT IGNORE INTO gang_discovered_sprays (gang_name, spray_id) VALUES (?, ?)',
            { myGang, sprayId }
        )
        AddGangXP(myGang, Config.XP.Discover)
        for _, p in pairs(QBCore.Functions.GetQBPlayers()) do
            if GetGangLabel(p.PlayerData.source) == myGang then
                TriggerClientEvent('spacecity_sprays:client:SyncDiscovery', p.PlayerData.source, sprayId)
            end
        end
    end
end)

RegisterNetEvent('spacecity_sprays:server:ContestSpray', function(sprayId)
    local src = source
    local attackerGang = GetGangLabel(src)
    if not attackerGang then return end
    local spray = Sprays[sprayId]
    if not spray then return end
    if attackerGang == spray.gang then return end
    if spray.contested then return end
    if not Discovered[attackerGang] or not Discovered[attackerGang][sprayId] then return end

    local lastTime = LastContestedAt[sprayId]
    if lastTime and (os.time() - lastTime) < 3600 then
        local mins = math.ceil((3600 - (os.time() - lastTime)) / 60)
        Notify(src, { ("This spray was recently contested. Try again in %d minute(s)."):format(mins), "error" })
        return
    end

    local utcHour = math.floor(os.time() / 3600) % 24
    local ksaHour = (utcHour + 3) % 24
    if ksaHour < 14 or ksaHour >= 24 then
        Notify(src, { "Contests are only allowed between 6PM and 12AM (KSA time).", "error" })
        return
    end

    local onlineCount = 0
    for _, Player in pairs(QBCore.Functions.GetQBPlayers()) do
        if GetGangLabel(Player.PlayerData.source) == attackerGang then
            onlineCount = onlineCount + 1
        end
    end
    if onlineCount < 1 then
        Notify(src, { ("Your gang needs at least 3 members online to contest. (%d online)"):format(onlineCount), "error" })
        return
    end

    LastContestedAt[sprayId] = os.time()
    StartContest(sprayId, attackerGang)
end)

RegisterNetEvent('spacecity_sprays:server:UpdateSprayState', function(sprayId, state)
    if state then
        local src = source
        local attackerGang = GetGangLabel(src)
        if attackerGang then StartContest(sprayId, attackerGang) end
    end
end)

RegisterNetEvent('spacecity_sprays:server:RemoveSpray', function(sprayId)
    local src = source
    local removerGang = GetGangLabel(src)
    local spray = Sprays[sprayId]
    if not spray or not removerGang then return end

    local now = os.time() * 1000
    local inRemovalWindow =
        (not spray.contested)
        and spray.contest_ended_at
        and spray.contesting_gang == removerGang
        and (now - spray.contest_ended_at) <= (Config.RemoveWindowTime or 600000)

    if not inRemovalWindow then
        Notify(src, Config.Notify.RemoveNotAllowed)
        return
    end

    AddGangXP(removerGang, Config.XP.Remove)
    ContestTimers[sprayId] = nil
    RemoveTimers[sprayId]  = nil
    Sprays[sprayId] = nil
    MySQL.Async.execute('DELETE FROM gang_sprays WHERE id = ?', { sprayId })
    MySQL.Async.execute('DELETE FROM gang_discovered_sprays WHERE spray_id = ?', { sprayId })
    for _, list in pairs(Discovered) do list[sprayId] = nil end
    TriggerClientEvent('spacecity_sprays:client:RemoveSpray', -1, sprayId)
end)


QBCore.Functions.CreateCallback('spacecity_sprays:server:GetMyGang', function(src, cb)
    cb(GetGangLabel(src))
end)

QBCore.Functions.CreateCallback('spacecity_sprays:server:GetServerTime', function(src, cb)
    cb(os.time())
end)

local function PushInit(src)
    local gang = GetGangLabel(src)
    TriggerClientEvent('spacecity_sprays:client:Init', src, Sprays, Discovered, gang)
end

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function() PushInit(source) end)
RegisterNetEvent('spacecity_sprays:server:RequestInit', function() PushInit(source) end)


QBCore.Functions.CreateUseableItem(Config.SprayItem or "gang_spray", function(source)
    local gang = GetGangLabel(source)
    if not gang then
        Notify(source, Config.Notify.NotInOrg)
        return
    end
    TriggerClientEvent('spacecity_sprays:client:StartPlacement', source, gang)
end)

QBCore.Functions.CreateUseableItem(Config.SprayRemoverItem or "gang_sprayremover", function(source)
    TriggerClientEvent('spacecity_sprays:client:UseRemover', source)
end)

QBCore.Commands.Add('viewsprays', 'View all sprays on map (Admin Only)', {}, false, function(source)
    TriggerClientEvent('spacecity_sprays:client:ToggleAdminView', source)
end, 'admin')
