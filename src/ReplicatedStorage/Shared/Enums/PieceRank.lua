--!strict
-- PieceRank: single source of truth for every piece rank in the game.
-- No other module should hardcode rank names/values — always require this.

export type RankId =
	"Flag" | "Private" | "Spy" | "Sergeant" | "Lieutenant2" | "Lieutenant1"
	| "Captain" | "Major" | "LtColonel" | "Colonel"
	| "General1" | "General2" | "General3" | "General4" | "General5"

export type RankDefinition = {
	id: RankId, -- matches the key in PieceRank.Ranks (used for quick lookups/serialization)
	name: string, -- human-readable display name for UI
	value: number, -- numeric rank for simple higher-value-wins comparisons
	count: number, -- how many of this piece exist in one player's 21-piece set
}

local PieceRank = {}

-- Ordered low-to-high by `value`. Spy/Private have special-case rules layered on top elsewhere (ChallengeResolver).
local Ranks: { [RankId]: RankDefinition } = {
	Flag        = { id = "Flag",        name = "Flag",             value = 0,  count = 1 },
	Private     = { id = "Private",     name = "Private",          value = 1,  count = 6 },
	Spy         = { id = "Spy",         name = "Spy",              value = 2,  count = 2 },
	Sergeant    = { id = "Sergeant",    name = "Sergeant",         value = 3,  count = 1 },
	Lieutenant2 = { id = "Lieutenant2", name = "2nd Lieutenant",   value = 4,  count = 1 },
	Lieutenant1 = { id = "Lieutenant1", name = "1st Lieutenant",   value = 5,  count = 1 },
	Captain     = { id = "Captain",     name = "Captain",          value = 6,  count = 1 },
	Major       = { id = "Major",       name = "Major",            value = 7,  count = 1 },
	LtColonel   = { id = "LtColonel",   name = "Lt. Colonel",      value = 8,  count = 1 },
	Colonel     = { id = "Colonel",     name = "Colonel",          value = 9,  count = 1 },
	General1    = { id = "General1",    name = "1-Star General",   value = 10, count = 1 },
	General2    = { id = "General2",    name = "2-Star General",   value = 11, count = 1 },
	General3    = { id = "General3",    name = "3-Star General",   value = 12, count = 1 },
	General4    = { id = "General4",    name = "4-Star General",   value = 13, count = 1 },
	General5    = { id = "General5",    name = "5-Star General",   value = 14, count = 1 },
}
PieceRank.Ranks = Ranks

-- getOrderedList: returns all rank definitions sorted by value ascending (for setup UI palettes later).
function PieceRank.getOrderedList(): { RankDefinition }
	local list: { RankDefinition } = {}
	for _, def in pairs(PieceRank.Ranks) do
		table.insert(list, def)
	end
	table.sort(list, function(a: RankDefinition, b: RankDefinition): boolean
		return a.value < b.value
	end)
	return list
end

-- getTotalPieceCount: sums every rank's count (should equal 21) — used as a sanity check in setup validation.
function PieceRank.getTotalPieceCount(): number
	local total = 0
	for _, def in pairs(PieceRank.Ranks) do
		total += def.count
	end
	return total
end

return PieceRank