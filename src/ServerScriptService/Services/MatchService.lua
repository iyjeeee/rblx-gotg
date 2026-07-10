--!strict
-- MatchService: server-side authority owning all active GameEngine instances.
-- Maps Board.Owner ("PlayerA"/"PlayerB") labels onto real Player Instances and relays
-- client Remote calls into the pure GameEngine from Phase 1. No game rules live here --
-- this module only does lookup/relay/broadcast.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local GameEngine = require(ReplicatedStorage.Shared.GameEngine.GameEngine)
local Board = require(ReplicatedStorage.Shared.GameEngine.Board)

local Remotes = ReplicatedStorage.Remotes.Match
local SubmitSetup = Remotes.SubmitSetup :: RemoteFunction
local SubmitMove = Remotes.SubmitMove :: RemoteFunction
local StateUpdate = Remotes.StateUpdate :: RemoteEvent

export type MatchRecord = {
	engine: GameEngine.GameEngineInstance,
	players: { [Board.Owner]: Player },
}

export type PlayerLookup = {
	matchId: string,
	owner: Board.Owner,
}

local MatchService = {}

local matches: { [string]: MatchRecord } = {}
local playerToMatch: { [Player]: PlayerLookup } = {}

-- getMatchForPlayer: reverse lookup from a Player Instance to their active match + owner label.
local function getMatchForPlayer(player: Player): (MatchRecord?, Board.Owner?)
	local lookup = playerToMatch[player]
	if lookup == nil then
		return nil, nil
	end
	return matches[lookup.matchId], lookup.owner
end

-- broadcastState: sends each player in the match their own fog-of-war-filtered view.
local function broadcastState(matchRecord: MatchRecord)
	for owner, player in matchRecord.players do
		if player.Parent ~= nil then -- guard against a player who has already left
			local publicState = matchRecord.engine:getPublicState(owner)
			StateUpdate:FireClient(player, publicState)
		end
	end
end

-- isPlayerInMatch: lets other services (like MatchmakingService) check match status before queueing.
function MatchService.isPlayerInMatch(player: Player): boolean
	return playerToMatch[player] ~= nil
end

-- createMatch: registers a new match between two players, returns the new matchId.
function MatchService.createMatch(playerA: Player, playerB: Player): string
	local matchId = HttpService:GenerateGUID(false)
	local engine = GameEngine.new()

	matches[matchId] = {
		engine = engine,
		players = { PlayerA = playerA, PlayerB = playerB },
	}
	playerToMatch[playerA] = { matchId = matchId, owner = "PlayerA" }
	playerToMatch[playerB] = { matchId = matchId, owner = "PlayerB" }

	return matchId
end

-- init: wires up the Remote handlers. Call exactly once, from a server bootstrap script.
function MatchService.init()
	SubmitSetup.OnServerInvoke = function(player: Player, placements: { GameEngine.PlacementInput })
		local matchRecord, owner = getMatchForPlayer(player)
		if matchRecord == nil or owner == nil then
			return { ok = false, errorMessage = "Not currently in a match" }
		end

		local result = matchRecord.engine:submitSetup(owner, placements)
		broadcastState(matchRecord)
		return result
	end

	SubmitMove.OnServerInvoke = function(player: Player, fromRow: number, fromCol: number, toRow: number, toCol: number)
		local matchRecord, owner = getMatchForPlayer(player)
		if matchRecord == nil or owner == nil then
			return { ok = false, errorMessage = "Not currently in a match" }
		end

		local result = matchRecord.engine:attemptMove(owner, fromRow, fromCol, toRow, toCol)
		broadcastState(matchRecord)
		return result
	end

	-- Minimal cleanup: clear the reverse-lookup entry so a departed player can't be routed into future calls.
	-- Full disconnect/forfeit handling (notifying the opponent, ending the match) is Phase 3 scope.
	Players.PlayerRemoving:Connect(function(player: Player)
		playerToMatch[player] = nil
	end)
end

return MatchService