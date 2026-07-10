--!strict
-- MatchmakingService: simple FIFO matchmaking queue. No MMR yet (that's Phase 6) — first two
-- players to queue get paired together. Hands off to MatchService for actual match creation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local MatchService = require(script.Parent.MatchService)

local Remotes = ReplicatedStorage.Remotes.Matchmaking
local FindMatch = Remotes.FindMatch :: RemoteFunction
local CancelQueue = Remotes.CancelQueue :: RemoteFunction
local MatchFound = Remotes.MatchFound :: RemoteEvent

export type QueueResult = {
	ok: boolean,
	errorMessage: string?,
	paired: boolean, -- true if this call immediately paired the player; false if they're now just waiting
}

local MatchmakingService = {}

local queue: { Player } = {}
local queuedSet: { [Player]: boolean } = {}

local function isPlayerQueued(player: Player): boolean
	return queuedSet[player] == true
end

local function removeFromQueue(player: Player)
	if not isPlayerQueued(player) then
		return
	end
	queuedSet[player] = nil
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end
end

function MatchmakingService.init()
	FindMatch.OnServerInvoke = function(player: Player): QueueResult
		if MatchService.isPlayerInMatch(player) then
			return { ok = false, errorMessage = "Already in an active match", paired = false }
		end

		if isPlayerQueued(player) then
			return { ok = false, errorMessage = "Already in queue", paired = false }
		end

		if #queue > 0 then
			local opponent = table.remove(queue, 1) :: Player
			queuedSet[opponent] = nil

			local matchId = MatchService.createMatch(opponent, player)
			MatchFound:FireClient(opponent, matchId)
			MatchFound:FireClient(player, matchId)

			return { ok = true, errorMessage = nil, paired = true }
		end

		table.insert(queue, player)
		queuedSet[player] = true
		return { ok = true, errorMessage = nil, paired = false }
	end

	CancelQueue.OnServerInvoke = function(player: Player): QueueResult
		if not isPlayerQueued(player) then
			return { ok = false, errorMessage = "Not currently in queue", paired = false }
		end
		removeFromQueue(player)
		return { ok = true, errorMessage = nil, paired = false }
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		removeFromQueue(player)
	end)
end

return MatchmakingService