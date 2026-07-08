--!strict
-- MoveValidator: validates whether a proposed move (from one cell to an adjacent cell) is legal.
-- Pure logic only — no board mutation happens here, just yes/no + reason.

local Board = require(script.Parent.Board)

export type MoveValidationResult = {
	ok: boolean,
	errorMessage: string?, -- nil when ok == true
	isChallenge: boolean, -- true if the destination is occupied by an opponent piece (a challenge, not a plain move)
}

export type MoveValidatorModule = {
	isOrthogonalAdjacent: (fromRow: number, fromCol: number, toRow: number, toCol: number) -> boolean,
	validateMove: (
		board: Board.BoardGrid,
		fromRow: number,
		fromCol: number,
		toRow: number,
		toCol: number,
		movingOwner: Board.Owner
	) -> MoveValidationResult,
}

local MoveValidator = {} :: MoveValidatorModule

-- isOrthogonalAdjacent: true only if exactly one of row/col differs by exactly 1 (no diagonals, no jumps).
function MoveValidator.isOrthogonalAdjacent(fromRow: number, fromCol: number, toRow: number, toCol: number): boolean
	local rowDiff = math.abs(toRow - fromRow)
	local colDiff = math.abs(toCol - fromCol)
	-- Exactly one axis moves by exactly 1, the other stays at 0. (0,0) is also rejected — no "moving in place".
	return (rowDiff == 1 and colDiff == 0) or (rowDiff == 0 and colDiff == 1)
end

-- validateMove: full legality check for a single proposed move.
function MoveValidator.validateMove(
	board: Board.BoardGrid,
	fromRow: number,
	fromCol: number,
	toRow: number,
	toCol: number,
	movingOwner: Board.Owner
): MoveValidationResult
	if not Board.isValidPosition(fromRow, fromCol) or not Board.isValidPosition(toRow, toCol) then
		return { ok = false, errorMessage = "Move references an out-of-bounds position", isChallenge = false }
	end

	local movingPiece = Board.getCell(board, fromRow, fromCol)
	if movingPiece == nil then
		return { ok = false, errorMessage = "No piece at the source position", isChallenge = false }
	end

	if movingPiece.owner ~= movingOwner then
		return { ok = false, errorMessage = "Cannot move a piece you do not own", isChallenge = false }
	end

	if not MoveValidator.isOrthogonalAdjacent(fromRow, fromCol, toRow, toCol) then
		return {
			ok = false,
			errorMessage = "Move must be exactly one square, orthogonally (no diagonals, no jumps)",
			isChallenge = false,
		}
	end

	local targetPiece = Board.getCell(board, toRow, toCol)
	if targetPiece == nil then
		-- Empty destination: a plain move, not a challenge.
		return { ok = true, errorMessage = nil, isChallenge = false }
	end

	if targetPiece.owner == movingOwner then
		return { ok = false, errorMessage = "Cannot move onto your own piece", isChallenge = false }
	end

	-- Occupied by an opponent piece: legal move, but it's a challenge (resolved separately by ChallengeResolver).
	return { ok = true, errorMessage = nil, isChallenge = true }
end

return MoveValidator