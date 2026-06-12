local QBCore           = exports['qb-core']:GetCoreObject()
local ActiveSprays     = {}
local DiscoveredSprays = {}
local RadiusBlips      = {}
local ContestBlips     = {}
local AdminView        = false
local Placing          = false

local MyGang           = nil
local function GetMyGang() return MyGang or "none" end

-- Notify helper that accepts Config.Notify entries {msg, type} and printf args
local function notify(entry, ...)
    if type(entry) == "table" then
        QBCore.Functions.Notify(entry[1]:format(...), entry[2] or "primary")
    else
        QBCore.Functions.Notify(tostring(entry):format(...), "primary")
    end
end
local function notifyString(entry, ...)
    if type(entry) == "table" then return entry[1]:format(...) end
    return tostring(entry):format(...)
end

local RuntimeTxd
local RuntimeTextures = {}

local function EnsureRuntimeTextures()
    if RuntimeTxd then return end
    RuntimeTxd = CreateRuntimeTxd(Config.TextureDict)
    if not RuntimeTxd then
        print(('[spacecity_sprays] Failed to create runtime txd "%s"'):format(Config.TextureDict))
        return
    end
    local seen = {}
    for _, gangData in pairs(Config.Gangs) do
        local name = gangData.texture
        if name and not seen[name] then
            seen[name] = true
            local path = ('spray_logos/%s.png'):format(name)
            local tex  = CreateRuntimeTextureFromImage(RuntimeTxd, name, path)
            if tex then RuntimeTextures[name] = tex
            else print(('[spacecity_sprays] Failed to load %s'):format(path)) end
        end
    end
end

local ServerTimeOffset = 0

CreateThread(function()
    QBCore.Functions.TriggerCallback('spacecity_sprays:server:GetServerTime', function(serverTime)
        ServerTimeOffset = serverTime - math.floor(GetGameTimer() / 1000)
    end)
end)

local function GetUnixMs()
    return math.floor((math.floor(GetGameTimer() / 1000) + ServerTimeOffset) * 1000)
end

CreateThread(EnsureRuntimeTextures)

CreateThread(function()
    Wait(1500)
    if MyGang == nil then TriggerServerEvent('spacecity_sprays:server:RequestInit') end
end)

-----------------------------------------------------------------------
-- Geometry helpers
-----------------------------------------------------------------------
local function HeadingToNormal(heading)
    local rad = math.rad(heading or 0.0)
    return vector3(math.sin(rad), -math.cos(rad), 0.0)
end

local function GetSprayNormal(spray)
    if spray.nx and spray.ny and spray.nz then
        return vector3(spray.nx, spray.ny, spray.nz)
    end
    return HeadingToNormal(spray.heading)
end

local function BuildQuad(hit, normal, width, height, offset)
    offset = offset or 0.02
    local hx, hy = -normal.y, normal.x
    local hlen = math.sqrt(hx * hx + hy * hy)
    if hlen < 0.0001 then hx, hy, hlen = 1.0, 0.0, 1.0 end
    hx, hy = hx / hlen, hy / hlen
    local c = vector3(hit.x + normal.x * offset,
                      hit.y + normal.y * offset,
                      hit.z + normal.z * offset)
    local hw, hh = width * 0.5, height * 0.5
    local bl = vector3(c.x - hx * hw, c.y - hy * hw, c.z - hh)
    local br = vector3(c.x + hx * hw, c.y + hy * hw, c.z - hh)
    local tr = vector3(c.x + hx * hw, c.y + hy * hw, c.z + hh)
    local tl = vector3(c.x - hx * hw, c.y - hy * hw, c.z + hh)
    return bl, br, tr, tl
end

local function DrawDecalQuad(bl, br, tr, tl, r, g, b, a, txd, txn)
    DrawSpritePoly(
        tl.x, tl.y, tl.z, bl.x, bl.y, bl.z, br.x, br.y, br.z,
        r, g, b, a, txd, txn,
        0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0
    )
    DrawSpritePoly(
        tl.x, tl.y, tl.z, br.x, br.y, br.z, tr.x, tr.y, tr.z,
        r, g, b, a, txd, txn,
        0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0
    )
end

-----------------------------------------------------------------------
-- Anim / prop helpers
-----------------------------------------------------------------------
local SPRAY_DICT  = "anim@scripted@freemode@postertag@graffiti_spray@male@"
local SPRAY_CLIP  = "spray_can_var_01_male"
local CLEAN_DICT  = "timetable@floyd@clean_kitchen@base"
local CLEAN_ANIM  = "base"
local CAN_PROP    = "prop_cs_spray_can"
local SprayCanObj = nil

local function LoadAnim(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function LoadModel(model)
    local hash = type(model) == "string" and GetHashKey(model) or model
    if HasModelLoaded(hash) then return hash end
    RequestModel(hash)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(hash) and hash or nil
end

local function AttachSprayCan()
    if SprayCanObj and DoesEntityExist(SprayCanObj) then return end
    local ped = PlayerPedId()
    local hash = LoadModel(CAN_PROP)
    if not hash then return end
    local c = GetEntityCoords(ped)
    SprayCanObj = CreateObject(hash, c.x, c.y, c.z + 0.2, true, true, false)
    AttachEntityToEntity(
        SprayCanObj, ped, GetPedBoneIndex(ped, 28422),
        0.0, 0.0, 0.07, -90.0, 0.0, 0.0,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(hash)
end

local function DetachSprayCan()
    if SprayCanObj and DoesEntityExist(SprayCanObj) then
        DetachEntity(SprayCanObj, true, true)
        DeleteObject(SprayCanObj)
    end
    SprayCanObj = nil
end

local function StartSprayAnim()
    local ped = PlayerPedId()
    if not LoadAnim(SPRAY_DICT) then
        ClearPedTasks(ped)
        TaskStartScenarioInPlace(ped, "WORLD_HUMAN_GRAFFITI", 0, true)
        return
    end
    AttachSprayCan()
    TaskPlayAnim(ped, SPRAY_DICT, SPRAY_CLIP, 8.0, -8.0, -1, 49, 0.0, false, false, false)
end

local function StopSprayAnim()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    DetachSprayCan()
    Wait(0)
    if IsPedUsingAnyScenario(ped) or IsPedActiveInScenario(ped) then
        ClearPedTasksImmediately(ped)
    end
end

local function PlayBasicAnim(dict, anim, flag)
    if LoadAnim(dict) then
        TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, -1, flag or 49, 0, false, false, false)
    end
end

local function StopAnim() ClearPedTasks(PlayerPedId()) end

local function SprayParticleBurst()
    local asset = "scr_recartheft"
    if not HasNamedPtfxAssetLoaded(asset) then
        RequestNamedPtfxAsset(asset)
        local t = GetGameTimer() + 1500
        while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < t do Wait(0) end
    end
    if not HasNamedPtfxAssetLoaded(asset) then return end
    local ped = PlayerPedId()
    local fwd = GetEntityForwardVector(ped)
    local pc  = GetEntityCoords(ped)
    local p   = pc + fwd * 0.6 + vector3(0.0, 0.0, 0.4)
    UseParticleFxAssetNextCall(asset)
    SetParticleFxNonLoopedColour(1.0, 1.0, 1.0)
    SetParticleFxNonLoopedAlpha(0.6)
    StartNetworkedParticleFxNonLoopedAtCoord("scr_wheel_burnout",
        p.x, p.y, p.z, 0.0, 0.0, GetEntityHeading(ped), 0.4, 0.0, 0.0, 0.0)
end

-----------------------------------------------------------------------
-- Blips
-----------------------------------------------------------------------
local function RemoveRadiusBlipFor(id)
    if RadiusBlips[id] and DoesBlipExist(RadiusBlips[id]) then RemoveBlip(RadiusBlips[id]) end
    RadiusBlips[id] = nil
end
local function RemoveContestBlipFor(id)
    if ContestBlips[id] and DoesBlipExist(ContestBlips[id]) then RemoveBlip(ContestBlips[id]) end
    ContestBlips[id] = nil
end

local function ShouldShowRadiusBlip(spray)
    local pGang = GetMyGang()
    if AdminView then return true end
    if pGang == "none" then return false end
    if spray.gang == pGang then return true end
    if DiscoveredSprays[spray.id] then return true end
    return false
end

local function ShouldShowContestBlip(spray)
    if not spray.contested then return false end
    local pGang = GetMyGang()
    if AdminView then return true end
    if pGang == "none" then return false end
    return pGang == spray.gang or pGang == spray.contesting_gang
end

local function RefreshRadiusBlip(spray)
    local id = spray.id
    if ShouldShowRadiusBlip(spray) then
        if not (RadiusBlips[id] and DoesBlipExist(RadiusBlips[id])) then
            local gangCfg   = Config.Gangs[spray.gang] or {}
            local blipColor = gangCfg.blipColor or 1
            local blip = AddBlipForRadius(spray.coords.x, spray.coords.y, spray.coords.z, Config.BlipRadius)
            SetBlipHighDetail(blip, true)
            SetBlipColour(blip, blipColor)
            SetBlipAlpha(blip, Config.BlipAlpha)
            RadiusBlips[id] = blip
        end
    else
        RemoveRadiusBlipFor(id)
    end
end

local function RefreshContestBlip(spray)
    local id = spray.id
    if ShouldShowContestBlip(spray) then
        if not (ContestBlips[id] and DoesBlipExist(ContestBlips[id])) then
            local blip = AddBlipForCoord(spray.coords.x, spray.coords.y, spray.coords.z)
            SetBlipSprite(blip, Config.ContestBlipSprite or 310)
            SetBlipColour(blip, Config.ContestBlipColor or 1)
            SetBlipScale(blip, 0.9)
            SetBlipAsShortRange(blip, false)
            SetBlipHighDetail(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(Config.ContestBlipName or "CONTESTED Graffiti")
            EndTextCommandSetBlipName(blip)
            ContestBlips[id] = blip
        end
    else
        RemoveContestBlipFor(id)
    end
end

local function RefreshAllBlips()
    for id in pairs(RadiusBlips)  do if not ActiveSprays[id] then RemoveRadiusBlipFor(id)  end end
    for id in pairs(ContestBlips) do if not ActiveSprays[id] then RemoveContestBlipFor(id) end end
    for _, spray in pairs(ActiveSprays) do
        RefreshRadiusBlip(spray)
        RefreshContestBlip(spray)
    end
end


RegisterNetEvent('spacecity_sprays:client:PlayAlert', function()
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "playSound", sound = "gang_alert" })
end)


-----------------------------------------------------------------------
-- qb-target
-----------------------------------------------------------------------
local RegisteredZones = {}

local function GetSprayHeadingFromNormal(n)
    if not n then return 0.0 end
    return math.deg(math.atan2(-n.x, n.y))
end

local function RemoveZoneFor(id)
    if RegisteredZones[id] then
        exports['qb-target']:RemoveZone("spray_zone_" .. id)
        RegisteredZones[id] = nil
    end
end

local function InRemovalWindow(spray)
    if not spray.contesting_gang then return false end
    if spray.contested then return false end                    -- still contested = no removal
    if not spray.contest_ended_at then return false end

    local elapsed = GetUnixMs() - spray.contest_ended_at
    return elapsed >= 0 and elapsed <= (Config.RemoveWindowTime or 600000)
end

local function RegisterZoneFor(spray)
    local id = spray.id
    local zoneName = "spray_zone_" .. id
    local n   = GetSprayNormal(spray)
    local sx, sy, sz = spray.coords.x, spray.coords.y, spray.coords.z
    local w   = Config.SprayWidth  or 1.4
    local h   = Config.SprayHeight or 1.4
    local depth = 1.0
    local offIn = 0.3
    local cx = sx + n.x * offIn
    local cy = sy + n.y * offIn
    local cz = sz
    local heading = GetSprayHeadingFromNormal(n)

    exports['qb-target']:AddBoxZone(zoneName,
        vector3(cx, cy, cz),
        w, depth,
        {
            name = zoneName,
            heading = heading,
            debugPoly = false,
            minZ = cz - (h * 0.5),
            maxZ = cz + (h * 0.5),
        },
        {
            options = {
                { type = "client", icon = "fas fa-eye", label = "Discover Spray",
                  action = function() DiscoverSpray(id) end,
                  canInteract = function()
                      local pGang = GetMyGang()
                      if pGang == "none" or pGang == spray.gang then return false end
                      return not DiscoveredSprays[id]
                  end },
                { type = "client", icon = "fas fa-flag", label = "Contest Spray",
                  action = function() ContestSpray(id) end,
                  canInteract = function()
                      local pGang = GetMyGang()
                      if pGang == "none" or pGang == spray.gang then return false end
                      if not DiscoveredSprays[id] then return false end
                      if spray.contested then return false end
                      if InRemovalWindow(spray) and spray.contesting_gang == pGang then return false end
                      return true
                  end },
                { type = "client", icon = "fas fa-spray-can", label = "Remove Graffiti",
                  action = function() RemoveNearbySpray(id) end,
                  canInteract = function()
                      local pGang = GetMyGang()
                      if pGang == "none" or pGang == spray.gang then return false end
                      if spray.contesting_gang ~= pGang then return false end
                      return InRemovalWindow(spray)
                  end },
            },
            distance = Config.TargetDistance or 2.5,
        })
    RegisteredZones[id] = true
end


local function RefreshSprayTarget(spray)
    if GetMyGang() == spray.gang then
        RemoveZoneFor(spray.id)
        return
    end
    RemoveZoneFor(spray.id)
    RegisterZoneFor(spray)
end

local function RefreshAllSprayTargets()
    for id in pairs(RegisteredZones) do
        if not ActiveSprays[id] then RemoveZoneFor(id) end
    end
    for _, spray in pairs(ActiveSprays) do RefreshSprayTarget(spray) end
end

-----------------------------------------------------------------------
-- Sync events
-----------------------------------------------------------------------
RegisterNetEvent('spacecity_sprays:client:Init', function(sprays, discovered, gang)
    ActiveSprays = sprays or {}
    if gang and gang ~= "" then MyGang = gang end
    local myGang = GetMyGang()
    DiscoveredSprays = (discovered and discovered[myGang]) or {}
    RefreshAllBlips()
    RefreshAllSprayTargets()
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', function()
    DiscoveredSprays = {}
    QBCore.Functions.TriggerCallback('spacecity_sprays:server:GetMyGang', function(newGang)
        MyGang = (newGang and newGang ~= "") and newGang or "none"
        TriggerServerEvent('spacecity_sprays:server:RequestInit')
    end)
end)

CreateThread(function()
    Wait(4000)
    QBCore.Functions.TriggerCallback('spacecity_sprays:server:GetMyGang', function(gang)
        if gang and gang ~= "" and gang ~= MyGang then
            MyGang = gang
            RefreshAllBlips()
            RefreshAllSprayTargets()
        end
    end)
end)

RegisterNetEvent('spacecity_sprays:client:ToggleAdminView', function()
    AdminView = not AdminView
    notify(Config.Notify.AdminViewToggled, tostring(AdminView))
    RefreshAllBlips()
end)

RegisterNetEvent('spacecity_sprays:client:SyncNewSpray', function(sprayData)
    ActiveSprays[sprayData.id] = sprayData
    RefreshRadiusBlip(sprayData)
    RefreshContestBlip(sprayData)
    RefreshSprayTarget(sprayData)
end)

RegisterNetEvent('spacecity_sprays:client:SyncDiscovery', function(sprayId)
    DiscoveredSprays[sprayId] = true
    if ActiveSprays[sprayId] then
        RefreshRadiusBlip(ActiveSprays[sprayId])
        RefreshSprayTarget(ActiveSprays[sprayId])
    end
end)

RegisterNetEvent('spacecity_sprays:client:SyncSpray', function(sprayData)
    if not sprayData or not sprayData.id then return end
    ActiveSprays[sprayData.id] = sprayData
    RefreshRadiusBlip(sprayData)
    RefreshContestBlip(sprayData)
    RefreshSprayTarget(sprayData)
end)

RegisterNetEvent('spacecity_sprays:client:UpdateSpray', function(sprayId, state)
    local s = ActiveSprays[sprayId]
    if not s then return end
    s.contested = state and true or false
    RefreshContestBlip(s)
    RefreshSprayTarget(s)
end)

RegisterNetEvent('spacecity_sprays:client:RemoveSpray', function(sprayId)
    RemoveZoneFor(sprayId)
    RemoveRadiusBlipFor(sprayId)
    RemoveContestBlipFor(sprayId)
    ActiveSprays[sprayId]     = nil
    DiscoveredSprays[sprayId] = nil
end)

-----------------------------------------------------------------------
-- Placement
-----------------------------------------------------------------------
RegisterNetEvent('spacecity_sprays:client:StartPlacement', function(gangName)
    if Placing then return end
    local gangData = Config.Gangs[gangName]
    if not gangData then
        return notify(Config.Notify.NoGangConfigClient, tostring(gangName))
    end
    EnsureRuntimeTextures()
    if not RuntimeTextures[gangData.texture] then
        return notify(Config.Notify.MissingTexture, tostring(gangData.texture))
    end

    Placing = true
    StartSprayAnim()

    CreateThread(function()
        while Placing do
            Wait(0)
            local hit, coords, normal, entity = RayCastGamePlayCamera(Config.PlacementRayDistance or 10.0)
            local validWall = hit and normal and (math.abs(normal.z) < (Config.MaxWallTilt or 0.5))
            if validWall and entity and entity ~= 0 then
                if IsEntityAVehicle(entity) or IsEntityAPed(entity) or IsPedAPlayer(entity) then
                    validWall = false
                end
            end

            if validWall then
                local w   = Config.SprayWidth  or 1.4
                local h   = Config.SprayHeight or 1.4
                local off = Config.WallOffset  or 0.02
                local bl, br, tr, tl = BuildQuad(coords, normal, w, h, off)
                DrawDecalQuad(bl, br, tr, tl, 255, 255, 255, 200, Config.TextureDict, gangData.texture)
                QBCore.Functions.DrawText3D(coords.x, coords.y, coords.z + 0.4, notifyString(Config.Notify.PlacementHintValid))

                if IsControlJustPressed(0, 38) then
                    Placing = false
                    local heading = GetEntityHeading(PlayerPedId())
                    TaskTurnPedToFaceCoord(PlayerPedId(), coords.x, coords.y, coords.z, 600)
                    Wait(350)
                    StartSprayAnim()

                    local stopFx = false
                    CreateThread(function()
                        while not stopFx do SprayParticleBurst(); Wait(900) end
                    end)

                    QBCore.Functions.Progressbar("placing_spray", "Spraying Turf...",
                        Config.SprayingTime, false, true,
                        { disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true },
                        {}, {}, {},
                        function()
                            stopFx = true
                            StopSprayAnim()
                            TriggerServerEvent('spacecity_sprays:server:SaveSpray',
                                gangName,
                                { x = coords.x, y = coords.y, z = coords.z },
                                heading,
                                { x = normal.x, y = normal.y, z = normal.z }
                            )
                        end,
                        function()
                            stopFx = true
                            StopSprayAnim()
                            notify(Config.Notify.PlacementCancelledErr)
                        end)
                    return
                elseif IsControlJustPressed(0, 177) then
                    Placing = false; StopSprayAnim()
                    notify(Config.Notify.PlacementCancelled)
                    return
                end
            else
                local pc = GetEntityCoords(PlayerPedId())
                QBCore.Functions.DrawText3D(pc.x, pc.y, pc.z + 1.2, notifyString(Config.Notify.PlacementHintAim))
                if IsControlJustPressed(0, 177) then
                    Placing = false; StopSprayAnim()
                    notify(Config.Notify.PlacementCancelled)
                    return
                end
            end
        end
    end)
end)

-----------------------------------------------------------------------
-- Render graffiti on walls (up to Config.RenderDistance)
-----------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(0)
        if next(ActiveSprays) ~= nil then
            local pedCoords = GetEntityCoords(PlayerPedId())
            local rd = Config.RenderDistance or 300.0
            local anyDrawn = false
            for _, spray in pairs(ActiveSprays) do
                local sc = vector3(spray.coords.x, spray.coords.y, spray.coords.z)
                if #(pedCoords - sc) < rd then
                    local gangCfg = Config.Gangs[spray.gang]
                    if gangCfg then
                        anyDrawn = true
                        local n   = GetSprayNormal(spray)
                        local w   = Config.SprayWidth  or 1.4
                        local h   = Config.SprayHeight or 1.4
                        local off = Config.WallOffset  or 0.02
                        local bl, br, tr, tl = BuildQuad(sc, n, w, h, off)
                        local a   = spray.contested and 140 or 255
                        DrawDecalQuad(bl, br, tr, tl, 255, 255, 255, a, Config.TextureDict, gangCfg.texture)
                    end
                end
            end
            if not anyDrawn then Wait(250) end
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        if next(ActiveSprays) ~= nil then
            for _, s in pairs(ActiveSprays) do RefreshSprayTarget(s) end
        end
    end
end)

-----------------------------------------------------------------------
-- qb-target action handlers
-----------------------------------------------------------------------
function DiscoverSpray(id)
    LoadAnim("amb@medic@standing@kneel@base")
    QBCore.Functions.Progressbar("discover", "Inspecting...", 3000, false, true,
        { disableMovement = true, disableCombat = true },
        { animDict = "amb@medic@standing@kneel@base", anim = "base", flags = 1 },
        {}, {},
        function()
            TriggerServerEvent('spacecity_sprays:server:DiscoverSpray', id)
            StopAnim()
        end,
        function() StopAnim() end)
end

function ContestSpray(id)
    StartSprayAnim()
    QBCore.Functions.Progressbar("contest", "Contesting...", 8000, false, true,
        { disableMovement = true, disableCombat = true }, {}, {}, {},
        function()
            StopSprayAnim()
            TriggerServerEvent('spacecity_sprays:server:ContestSpray', id)
        end,
        function() StopSprayAnim() end)
end

function RemoveNearbySpray(id)
    PlayBasicAnim(CLEAN_DICT, CLEAN_ANIM, 49)
    QBCore.Functions.Progressbar("remove", "Scrubbing...", Config.RemovingTime, false, true,
        { disableMovement = true, disableCombat = true },
        { animDict = CLEAN_DICT, anim = CLEAN_ANIM, flags = 49 },
        {}, {},
        function()
            TriggerServerEvent('spacecity_sprays:server:RemoveSpray', id)
            StopAnim()
        end,
        function() StopAnim() end)
end

RegisterNetEvent('spacecity_sprays:client:UseRemover', function()
    local pedCoords = GetEntityCoords(PlayerPedId())
    local myGang = GetMyGang()
    local closest, closestDist
    for id, spray in pairs(ActiveSprays) do
        local d = #(pedCoords - vector3(spray.coords.x, spray.coords.y, spray.coords.z))
        if d < 3.0 then
            local canRemove =
                spray.contesting_gang == myGang
                and InRemovalWindow(spray)
            if canRemove and (not closestDist or d < closestDist) then
                closest, closestDist = id, d
            end
        end
    end
    if closest then
        RemoveNearbySpray(closest)
    else
        notify(Config.Notify.RemoverNoneNearby)
    end
end)

-----------------------------------------------------------------------
-- Camera raycast
-----------------------------------------------------------------------
function RotationToDirection(rotation)
    local a = vector3((math.pi / 180) * rotation.x, (math.pi / 180) * rotation.y, (math.pi / 180) * rotation.z)
    return vector3(
        -math.sin(a.z) * math.abs(math.cos(a.x)),
         math.cos(a.z) * math.abs(math.cos(a.x)),
         math.sin(a.x)
    )
end

function RayCastGamePlayCamera(distance)
    local camRot = GetGameplayCamRot(2)
    local camPos = GetGameplayCamCoord()
    local dir    = RotationToDirection(camRot)
    local dest   = vector3(camPos.x + dir.x * distance, camPos.y + dir.y * distance, camPos.z + dir.z * distance)
    local _, hit, endCoords, surfaceNormal, entity = GetShapeTestResult(
        StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, 17, PlayerPedId(), 0)
    )
    return hit == 1, endCoords, surfaceNormal, entity
end

-----------------------------------------------------------------------
-- Cleanup
-----------------------------------------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id in pairs(RadiusBlips)     do RemoveRadiusBlipFor(id)  end
    for id in pairs(ContestBlips)    do RemoveContestBlipFor(id) end
    for id in pairs(RegisteredZones) do exports['qb-target']:RemoveZone("spray_zone_" .. id) end
    if Placing then Placing = false; StopSprayAnim() end
    DetachSprayCan()
end)