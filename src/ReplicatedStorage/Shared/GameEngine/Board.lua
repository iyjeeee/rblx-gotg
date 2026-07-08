--!strict
-- Board: represents the 8x9 game grid as plain data. No Roblox Instances — pure Lua/Luau tables only.
-- Rows: 1-8 (8 rows total). Columns: 1-9 (9 columns total). Matches the rulebook's 9x8 layout.

local PieceRank = require(script.Parent.Parent.Enums.PieceRank)

export type Owner = "PlayerA" | "PlayerB" -- side label; mapped to real Player Instances in MatchService (Phase 2)

export type Piece = {
	id: string, -- unique per piece instance, e.g. "PlayerA_Private_3"
	rankId: PieceRank.RankId,
	owner: Owner,
	revealed: boolean, -- true once this piece has been shown to the opponent via a challenge
}

export type Cell = Piece? -- a cell is either nil (empty) or a Piece
export type BoardGrid = { { Cell } } -- BoardGrid[row][col]

export type BoardModule = {
	ROWS: number,
	COLS: number,
	new: () -> BoardGrid,
	isValidPosition: (row: number, col: number) -> boolean,
	getCell: (board: BoardGrid, row: number, col: number) -> Cell,
	setCell: (board: BoardGrid, row: number, col: number, piece: Cell) -> (),
	isEmpty: (board: BoardGrid, row: number, col: number) -> boolean,
}

local Board = {} :: BoardModule

Board.ROWS = 8
Board.COLS = 9

-- new: builds a fresh, fully-empty board grid.
function Board.new(): BoardGrid
	local grid: BoardGrid = {}
	for row = 1, Board.ROWS do
		grid[row] = {}
		for col = 1, Board.COLS do
			grid[row][col] = nil
		end
	end
	return grid
end

-- isValidPosition: bounds check, used before every board read/write.
function Board.isValidPosition(row: number, col: number): boolean
	return row >= 1 and row <= Board.ROWS and col >= 1 and col <= Board.COLS
end

-- getCell: safe read; returns nil for empty cells AND for out-of-bounds positions.
function Board.getCell(board: BoardGrid, row: number, col: number): Cell
	if not Board.isValidPosition(row, col) then
		return nil
	end
	return board[row][col]
end

-- setCell: safe write; errors loudly on an out-of-bounds position instead of silently failing.
function Board.setCell(board: BoardGrid, row: number, col: number, piece: Cell): ()
	if not Board.isValidPosition(row, col) then
		error(string.format("Board.setCell: invalid position (%d, %d)", row, col))
	end
	board[row][col] = piece
end

-- isEmpty: convenience check, used constantly by movement/setup validation.
function Board.isEmpty(board: BoardGrid, row: number, col: number): boolean
	return Board.getCell(board, row, col) == nil
end

return Board