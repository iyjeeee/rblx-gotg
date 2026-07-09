--!strict
-- TEMPORARY test scaffolding for Phase 2 only: auto-pairs the first 2 players who join a session into
-- a match, so we can test MatchService/GameEngine networking with 2 real Studio test clients.
-- DELETE this file once Phase 3's real MatchmakingService (Find Match queue) is built.

print("[TempAutoPair] Script has started running") -- TEMP debug line, confirms the script executes at all

local Players = game:GetService("Players")
local MatchService = require(script.Parent.MatchService)

MatchService.init()

local waitingPlayer: Player? = nil

Players.PlayerAdded:Connect(function(player: Player)
	if waitingPlayer == nil then
		waitingPlayer = player
		print(string.format("[TempAutoPair] %s is waiting for an opponent...", player.Name))
	else
		local matchId = MatchService.createMatch(waitingPlayer :: Player, player)
		print(string.format("[TempAutoPair] Match %s created: %s vs %s", matchId, (waitingPlayer :: Player).Name, player.Name))
		waitingPlayer = nil
	end
end)