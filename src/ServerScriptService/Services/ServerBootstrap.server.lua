--!strict
-- ServerBootstrap: initializes all server-side Services exactly once, on server start.

local MatchService = require(script.Parent.MatchService)
local MatchmakingService = require(script.Parent.MatchmakingService)

MatchService.init()
MatchmakingService.init()

print("[ServerBootstrap] All services initialized")