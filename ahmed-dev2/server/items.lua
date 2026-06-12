-- This file belongs to a separate "gang_flags" feature shipped with the
-- resource. Guarded so it cannot crash the spray system on startup.

if not Config or not Config.FlagItem or type(Config.GetGangColor) ~= 'function' then
    return
end

local QBCore = exports['qb-core']:GetCoreObject()

local function GetSourceGangServer(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return nil end
    local identifier = Player.PlayerData.citizenid
    local ok, data = pcall(function()
        return exports['op-crime']:getPlayerOrganisation(identifier)
    end)
    if not ok or not data or not data.orgIndex then return nil end
    local orgData = data.orgData or {}
    local label = orgData.orgLabel or orgData.label or orgData.name
    if not label then
        local ok2, org = pcall(function() return exports['op-crime']:getOrganisation(data.orgIndex) end)
        if ok2 and org then label = org.orgLabel or org.label or org.name end
    end
    if not label then return nil end
    return { orgId = data.orgIndex, label = label }
end

QBCore.Functions.CreateUseableItem(Config.FlagItem, function(source, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if not Player.Functions.GetItemByName(Config.FlagItem) then
        print(('[gang_flags] player %s tried to use %s but item not in inventory'):format(src, Config.FlagItem))
        return
    end

    local gang = GetSourceGangServer(src)
    if not gang then
        print(('[gang_flags] player %s has no gang (op-crime returned nil)'):format(src))
        if Config.Locale and Config.Locale.notify_no_gang then
            TriggerClientEvent('QBCore:Notify', src, Config.Locale.notify_no_gang, 'error')
        end
        return
    end

    local color = Config.GetGangColor(gang.label)
    if not color then
        print(('[gang_flags] gang "%s" not in Config.GangColors'):format(gang.label))
        if Config.Locale and Config.Locale.notify_gang_not_config then
            TriggerClientEvent('QBCore:Notify', src, Config.Locale.notify_gang_not_config, 'error')
        end
        return
    end

    TriggerClientEvent('gang_flags:client:beginPlacement', src, {
        gangId      = gang.orgId,
        gangLabel   = gang.label,
        color       = color,
        prop        = Config.GetGangProp and Config.GetGangProp(gang.label) or nil,
        propOffsetZ = Config.GetGangPropOffset and Config.GetGangPropOffset(gang.label) or 0.0,
        propScale   = Config.GetGangPropScale and Config.GetGangPropScale(gang.label) or 1.0,
    })
    print(('[gang_flags] player %s (gang=%s) entered placement mode'):format(src, gang.label))
end)