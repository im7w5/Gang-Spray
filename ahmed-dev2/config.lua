Config = {}

Config.SprayingTime      = 10000       
Config.ContestTime       = 900000      
Config.RemoveWindowTime  = 600000      
Config.RemovingTime      = 90000       
Config.XP = {
    Discover = 50,
    Contest  = 150,
    Remove   = 250,
}

Config.BlipRadius = 75.0
Config.BlipAlpha  = 128

Config.ContestBlipSprite = 310   
Config.ContestBlipColor  = 1     
Config.ContestBlipName   = "CONTESTED Graffiti"

Config.AlertSound  = "gang_alert"
Config.SoundVolume = 0.5

Config.SprayItem        = "gang_spray"         
Config.SprayRemoverItem = "gang_sprayremover"

Config.SprayWidth  = 1.4
Config.SprayHeight = 1.4
Config.SprayScale  = 1.4 -- back-compat

Config.WallOffset  = 0.02

Config.PlacementRayDistance = 10.0

Config.MaxWallTilt = 0.5

Config.RenderDistance = 300.0
Config.TargetDistance = 2.5

Config.TextureDict = "spacecity_sprays_rt"

Config.Gangs = {
    ["ElMundo"]   = { texture = "elmundo",   blipColor = 39 },
    ["Trickster"] = { texture = "trickster", blipColor = 46 },
    ["Mafia"]     = { texture = "elmundo",   blipColor = 40 },
    ["Ballas"]     = { texture = "ballas",   blipColor = 83 },
    ["911"]   = { texture = "911",   blipColor = 39 },
    -- etc...
}

Config.Notify = {
    NotInOrg              = { "You aren't in an organisation.",               "error"   },
    NoGangConfig          = { "No spray config for: %s",                      "error"   }, -- %s = gang
    NoGangConfigClient    = { "No spray config for gang: %s",                 "error"   }, -- %s = gang
    MissingTexture        = { "Spray texture missing on disk: %s.png",        "error"   }, -- %s = tex
    InvalidCoords         = { "Invalid spray coordinates.",                   "error"   },
    PlacedOk              = { "Gang spray placed.",                           "success" },
    PlacementCancelled    = { "Spray cancelled.",                             "primary" },
    PlacementCancelledErr = { "Spray cancelled.",                             "error"   },
    PlacementHintValid    = "[E] Spray | [BACKSPACE] Cancel",                            
    PlacementHintAim      = "Aim at a wall  |  [BACKSPACE] Cancel",                     

    ContestStartedOwner   = { "Your gang graffiti is being contested!",       "error"   },
    ContestStartedAttacker= { "Contesting rival graffiti...",                 "primary" },
    ContestFinishedOwner  = { "Contest Timer is done, The Graffiti can be removed.", "primary" },
    ContestFinishedAttacker={ "Contest Timer is done, The Graffiti can be removed.", "success" },

    RemoveNotAllowed      = { "You can't remove this spray right now.",       "error"   },
    RemoverNoneNearby     = { "No removable spray nearby.",                   "error"   },

    AdminViewToggled      = { "Admin Spray View: %s",                         "primary" }, -- %s = true/false
}
