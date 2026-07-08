--!strict
-- GameEngine: orchestrates a full match — board, setup, turns, moves, challenges, and win detection.
-- This is the only module that mutates game state; Board/MoveValidator/ChallengeResolver/BoardSetup stay pure.

local Board = require(script.Parent.Board)
local BoardSetup = require(script.Parent.BoardSetup)
local MoveValidator = require(script.Parent.MoveValidator)
local ChallengeResolver = require(script.Parent.ChallengeResolver)
local PieceRank = require(script.Parent.Parent.Enums.PieceRank)

export type GamePhase = "Setup" | "Playing" | "GameOver"
export type WinReason = "FlagCaptured" | "FlagReachedEnd" | "Resignation"

export type PlacementInput = {
	row: number,
	col: number,
	rankId: PieceRank.RankId,
}

export type MoveResult = {
	ok: boolean,
	errorMessage: string?,
	challengeOutcome: ChallengeResolver.ChallengeOutcome?,
	gameOver: boolean,
	winner: Board.Owner?,
	winReason: WinReason?,
}

export type PublicPiece = {
	owner: Board.Owner,
	rankId: PieceRank.RankId?, -- nil when hidden (not revealed and not the requesting player's own piece)
	revealed: boolean,
}

export type PublicState = {
	board: { { PublicPiece? } },
	phase: GamePhase,
	currentTurn: Board.Owner,
	winner: Board.Owner?,
	winReason: WinReason?,
}

export type GameEngineInstance = {
	board: Board.BoardGrid,
	phase: GamePhase,
	setupComplete: { [Board.Owner]: boolean },
	currentTurn: Board.Owner,
	winner: Board.Owner?,
	winReason: WinReason?,
	submitSetup: (self: GameEngineInstance, owner: Board.Owner, placements: { PlacementInput }) -> BoardSetup.ValidationResult,
	attemptMove: (self: GameEngineInstance, owner: Board.Owner, fromRow: number, fromCol: number, toRow: number, toCol: number) -> MoveResult,
	getPublicState: (self: GameEngineInstance, forOwner: Board.Owner) -> PublicState,
}

local GameEngine = {}
GameEngine.__index = GameEngine

-- new: creates a fresh engine instance with an empty board, in the Setup phase. PlayerA always moves first.
function GameEngine.new(): GameEngineInstance
	local self = setmetatable({}, GameEngine) :: GameEngineInstance
	self.board = Board.new()
	self.phase = "Setup"
	self.setupComplete = { PlayerA = false, PlayerB = false }
	self.currentTurn = "PlayerA"
	self.winner = nil
	self.winReason = nil
	return self
end

-- opponentOf: small helper, returns the other side.
local function opponentOf(owner: Board.Owner): Board.Owner
	if owner == "PlayerA" then
		return "PlayerB"
	end
	return "PlayerA"
end

-- submitSetup: places an owner's full piece set on the board and validates it. On success, marks that
-- owner ready; once both owners are ready, the match transitions from Setup to Playing.
function GameEngine:submitSetup(owner: Board.Owner, placements: { PlacementInput }): BoardSetup.ValidationResult
	if self.phase ~= "Setup" then
		return { ok = false, errorMessage = "Cannot submit setup outside the Setup phase" }
	end

	-- Clear any previous placement for this owner first (supports re-submission before both are ready).
	for row = 1, Board.ROWS do
		for col = 1, Board.COLS do
			local cell = Board.getCell(self.board, row, col)
			if cell ~= nil and cell.owner == owner then
				Board.setCell(self.board, row, col, nil)
			end
		end
	end

	for index, placement in placements do
		Board.setCell(self.board, placement.row, placement.col, {
			id = string.format("%s_%s_%d", owner, placement.rankId, index),
			rankId = placement.rankId,
			owner = owner,
			revealed = false,
		})
	end

	local result = BoardSetup.validateSetup(self.board, owner)
	self.setupComplete[owner] = result.ok

	if self.setupComplete.PlayerA and self.setupComplete.PlayerB then
		self.phase = "Playing"
	end

	return result
end

-- checkWinConditions: called after every applied move; updates phase/winner/winReason if the game just ended.
local function checkWinConditions(self: GameEngineInstance, lastMoverOwner: Board.Owner, flagCapturedOwner: Board.Owner?)
	-- Win by capturing the opponent's Flag in a challenge.
	if flagCapturedOwner ~= nil then
		self.phase = "GameOver"
		self.winner = lastMoverOwner
		self.winReason = "FlagCaptured"
		return
	end

	-- Win by maneuvering your own Flag safely to the opposite end row.
	local targetRow = if lastMoverOwner == "PlayerA" then Board.ROWS else 1
	for col = 1, Board.COLS do
		local piece = Board.getCell(self.board, targetRow, col)
		if piece ~= nil and piece.owner == lastMoverOwner and piece.rankId == "Flag" then
			self.phase = "GameOver"
			self.winner = lastMoverOwner
			self.winReason = "FlagReachedEnd"
			return
		end
	end
end

-- attemptMove: validates and applies a move for the given owner, resolving any challenge, then checks win conditions.
function GameEngine:attemptMove(owner: Board.Owner, fromRow: number, fromCol: number, toRow: number, toCol: number): MoveResult
	if self.phase ~= "Playing" then
		return { ok = false, errorMessage = "Match is not in the Playing phase", challengeOutcome = nil, gameOver = false, winner = nil, winReason = nil }
	end

	if owner ~= self.currentTurn then
		return { ok = false, errorMessage = "Not your turn", challengeOutcome = nil, gameOver = false, winner = nil, winReason = nil }
	end

	local moveCheck = MoveValidator.validateMove(self.board, fromRow, fromCol, toRow, toCol, owner)
	if not moveCheck.ok then
		return { ok = false, errorMessage = moveCheck.errorMessage, challengeOutcome = nil, gameOver = false, winner = nil, winReason = nil }
	end

	local attackerPiece = Board.getCell(self.board, fromRow, fromCol) :: Board.Piece -- validated non-nil by MoveValidator
	local flagCapturedOwner: Board.Owner? = nil
	local challengeOutcome: ChallengeResolver.ChallengeOutcome? = nil

	if moveCheck.isChallenge then
		local defenderPiece = Board.getCell(self.board, toRow, toCol) :: Board.Piece
		challengeOutcome = ChallengeResolver.resolveChallenge(attackerPiece.rankId, defenderPiece.rankId)

		-- Both pieces are revealed once a challenge occurs, regardless of outcome (per rulebook, without an arbiter).
		attackerPiece.revealed = true
		defenderPiece.revealed = true

		if defenderPiece.rankId == "Flag" and challengeOutcome == "AttackerWins" then
			flagCapturedOwner = defenderPiece.owner
		end

		if challengeOutcome == "AttackerWins" then
			Board.setCell(self.board, toRow, toCol, attackerPiece)
			Board.setCell(self.board, fromRow, fromCol, nil)
		elseif challengeOutcome == "DefenderWins" then
			Board.setCell(self.board, fromRow, fromCol, nil) -- attacker eliminated, stays off the board; defender unchanged
		else -- BothEliminated
			Board.setCell(self.board, fromRow, fromCol, nil)
			Board.setCell(self.board, toRow, toCol, nil)
		end
	else
		-- Plain move: relocate the piece.
		Board.setCell(self.board, toRow, toCol, attackerPiece)
		Board.setCell(self.board, fromRow, fromCol, nil)
	end

	checkWinConditions(self, owner, flagCapturedOwner)

	if self.phase ~= "GameOver" then
		self.currentTurn = opponentOf(owner)
	end

	return {
		ok = true,
		errorMessage = nil,
		challengeOutcome = challengeOutcome,
		gameOver = self.phase == "GameOver",
		winner = self.winner,
		winReason = self.winReason,
	}
end

-- getPublicState: returns a fog-of-war-filtered view of the board for the requesting owner.
-- Own pieces and any revealed pieces (either side) show their true rank; unrevealed enemy pieces hide rankId.
function GameEngine:getPublicState(forOwner: Board.Owner): PublicState
	local publicBoard: { { PublicPiece? } } = {}
	for row = 1, Board.ROWS do
		publicBoard[row] = {}
		for col = 1, Board.COLS do
			local piece = Board.getCell(self.board, row, col)
			if piece == nil then
				publicBoard[row][col] = nil
			else
				local showRank = piece.owner == forOwner or piece.revealed
				publicBoard[row][col] = {
					owner = piece.owner,
					rankId = if showRank then piece.rankId else nil,
					revealed = piece.revealed,
				}
			end
		end
	end

	return {
		board = publicBoard,
		phase = self.phase,
		currentTurn = self.currentTurn,
		winner = self.winner,
		winReason = self.winReason,
	}
end

return GameEngine