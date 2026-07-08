--!strict
-- BoardSetup: validates a player's piece placement during the setup phase, before a match begins.
-- Rules: pieces must be placed only within the player's own 3 rows, and must exactly match the
-- standard 21-piece set defined in PieceRank (correct rank, correct count, no more, no less).

local Board = require(script.Parent.Board)
local PieceRank = require(script.Parent.Parent.Enums.PieceRank)

export type ValidationResult = {
	ok: boolean,
	errorMessage: string?, -- nil when ok == true
}

export type BoardSetupModule = {
	SETUP_ROWS: { [Board.Owner]: { number } },
	getSetupRows: (owner: Board.Owner) -> { number },
	validateSetup: (board: Board.BoardGrid, owner: Board.Owner) -> ValidationResult,
}

local BoardSetup = {} :: BoardSetupModule

-- Row assignment: PlayerA sets up in rows 1-3, PlayerB in rows 6-8. Rows 4-5 are always neutral/empty at setup.
BoardSetup.SETUP_ROWS = {
	PlayerA = { 1, 2, 3 },
	PlayerB = { 6, 7, 8 },
}

-- getSetupRows: returns which rows a given owner is allowed to place pieces in.
function BoardSetup.getSetupRows(owner: Board.Owner): { number }
	return BoardSetup.SETUP_ROWS[owner]
end

-- validateSetup: checks a fully-placed board section for one owner against all setup rules.
function BoardSetup.validateSetup(board: Board.BoardGrid, owner: Board.Owner): ValidationResult
	local allowedRows = BoardSetup.getSetupRows(owner)
	local allowedRowSet: { [number]: boolean } = {}
	for _, row in allowedRows do
		allowedRowSet[row] = true
	end

	-- Tally how many of each rank this owner has actually placed on the board.
	local placedCounts: { [PieceRank.RankId]: number } = {}
	local totalPlaced = 0

	for row = 1, Board.ROWS do
		for col = 1, Board.COLS do
			local piece = Board.getCell(board, row, col)
			if piece ~= nil and piece.owner == owner then
				-- Reject any owner piece sitting outside their allowed setup rows.
				if not allowedRowSet[row] then
					return {
						ok = false,
						errorMessage = string.format(
							"%s has a piece outside allowed setup rows at (%d, %d)",
							owner, row, col
						),
					}
				end
				placedCounts[piece.rankId] = (placedCounts[piece.rankId] or 0) + 1
				totalPlaced += 1
			end
		end
	end

	-- Reject if total piece count doesn't match the standard 21-piece set.
	local expectedTotal = PieceRank.getTotalPieceCount()
	if totalPlaced ~= expectedTotal then
		return {
			ok = false,
			errorMessage = string.format(
				"%s placed %d pieces, expected %d",
				owner, totalPlaced, expectedTotal
			),
		}
	end

	-- Reject if any individual rank's count doesn't match exactly (e.g. 5 Privates instead of 6).
	for rankId, def in PieceRank.Ranks do
		local placed = placedCounts[rankId] or 0
		if placed ~= def.count then
			return {
				ok = false,
				errorMessage = string.format(
					"%s placed %d of rank %s, expected %d",
					owner, placed, rankId, def.count
				),
			}
		end
	end

	return { ok = true, errorMessage = nil }
end

return BoardSetup