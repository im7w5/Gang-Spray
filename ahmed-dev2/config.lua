Config = {}

-- Durations (ms)
Config.SprayingTime      = 10000       -- time to place a spray
Config.ContestTime       = 900000      -- 15 minutes contest duration (skull blip lifetime)
Config.RemoveWindowTime  = 600000      -- 10 minutes after contest ends for contester to remove
Config.RemovingTime      = 90000       -- progressbar time when removing the spray

Config.XP = {
    Discover = 50,
    Contest  = 150,
    Remove   = 250,
}

-- Minimap gang color circle
Config.BlipRadius = 75.0
Config.BlipAlpha  = 128

-- Contested-spray skull blip
Config.ContestBlipSprite = 310   -- skull
Config.ContestBlipColor  = 1     -- red
Config.ContestBlipName   = "CONTESTED Graffiti"

-- Gang alert sound (InteractSound)
Config.AlertSound  = "gang_alert"
Config.SoundVolume = 0.5

-- Items
Config.SprayItem        = "gang_spray"         -- removed from inventory after a successful spray
Config.SprayRemoverItem = "gang_sprayremover"

-- Spray size on the wall (meters)
Config.SprayWidth  = 1.4
Config.SprayHeight = 1.4
Config.SprayScale  = 1.4 -- back-compat

-- How far the decal sits off the wall (meters)
Config.WallOffset  = 0.02

-- Max raycast distance when placing a spray (meters)
Config.PlacementRayDistance = 10.0

-- Max tilt for a surface to count as a wall (0 = perfectly vertical, 1 = floor)
Config.MaxWallTilt = 0.5

-- How far the painted graffiti keeps rendering on the wall
Config.RenderDistance = 300.0
-- qb-target reach distance for the options menu
Config.TargetDistance = 2.5

Config.TextureDict = "spacecity_sprays_rt"

Config.Gangs = {
    ["ElMundo"]   = { texture = "elmundo",   blipColor = 39 },
    ["Trickster"] = { texture = "trickster", blipColor = 46 },
    ["Mafia"]     = { texture = "elmundo",   blipColor = 40 },
    ["Ballas"]     = { texture = "ballas",   blipColor = 83 },
    ["911"]   = { texture = "911",   blipColor = 39 },
}

-- =====================================================================
-- All user-facing notify messages. Edit freely. { msg, type } — type is
-- one of QBCore's notify kinds: "primary" | "success" | "error"
-- =====================================================================
Config.Notify = {
    -- Placement flow
    NotInOrg              = { "You aren't in an organisation.",               "error"   },
    NoGangConfig          = { "No spray config for: %s",                      "error"   }, -- %s = gang
    NoGangConfigClient    = { "No spray config for gang: %s",                 "error"   }, -- %s = gang
    MissingTexture        = { "Spray texture missing on disk: %s.png",        "error"   }, -- %s = tex
    InvalidCoords         = { "Invalid spray coordinates.",                   "error"   },
    PlacedOk              = { "Gang spray placed.",                           "success" },
    PlacementCancelled    = { "Spray cancelled.",                             "primary" },
    PlacementCancelledErr = { "Spray cancelled.",                             "error"   },
    PlacementHintValid    = "[E] Spray | [BACKSPACE] Cancel",                            -- 3D text (no type)
    PlacementHintAim      = "Aim at a wall  |  [BACKSPACE] Cancel",                      -- 3D text

    -- Contest flow
    ContestStartedOwner   = { "Your gang graffiti is being contested!",       "error"   },
    ContestStartedAttacker= { "Contesting rival graffiti...",                 "primary" },
    ContestFinishedOwner  = { "Contest Timer is done, The Graffiti can be removed.", "primary" },
    ContestFinishedAttacker={ "Contest Timer is done, The Graffiti can be removed.", "success" },

    -- Removal flow
    RemoveNotAllowed      = { "You can't remove this spray right now.",       "error"   },
    RemoverNoneNearby     = { "No removable spray nearby.",                   "error"   },

    -- Admin
    AdminViewToggled      = { "Admin Spray View: %s",                         "primary" }, -- %s = true/false
}