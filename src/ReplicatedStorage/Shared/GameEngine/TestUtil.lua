--!strict
-- TestUtil: DEV-ONLY helpers for generating valid test data quickly.
-- Not used by real gameplay code — only for manual testing in the command bar and future automated tests.

local Board = require(script.Parent.Board)
local PieceRank = require(script.Parent.Parent.Enums.PieceRank)

local TestUtil = {}

-- generateValidSetup: fills the given owner's 3 rows with a full, correctly-counted 21-piece set.
-- 27 cells (3 rows x 9 cols) minus 21 pieces = 6 cells intentionally left empty, per the rulebook.
function TestUtil.generateValidSetup(board: Board.BoardGrid, owner: Board.Owner): ()
	local rows = if owner == "PlayerA" then { 1, 2, 3 } else { 6, 7, 8 }

	-- Build a flat list of rank IDs, repeated by their `count` (e.g. Private appears 6 times).
	local rankQueue: { PieceRank.RankId } = {}
	for rankId, def in PieceRank.Ranks do
		for _ = 1, def.count do
			table.insert(rankQueue, rankId)
		end
	end

	local index = 1
	for _, row in rows do
		for col = 1, Board.COLS do
			local rankId = rankQueue[index] -- nil once all 21 pieces are placed — leaves cell empty, as required
			if rankId ~= nil then
				Board.setCell(board, row, col, {
					id = string.format("%s_%s_%d", owner, rankId, index),
					rankId = rankId,
					owner = owner,
					revealed = false,
				})
				index += 1
			end
		end
	end
end

return TestUtil