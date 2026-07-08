--!strict
-- ChallengeResolver: pure function resolving combat outcome between two pieces' ranks.
-- No board mutation, no piece objects — just rankId in, outcome out. GameEngine applies the result.

local PieceRank = require(script.Parent.Parent.Enums.PieceRank)

export type ChallengeOutcome = "AttackerWins" | "DefenderWins" | "BothEliminated"

export type ChallengeResolverModule = {
	resolveChallenge: (attackerRankId: PieceRank.RankId, defenderRankId: PieceRank.RankId) -> ChallengeOutcome,
}

local ChallengeResolver = {} :: ChallengeResolverModule

-- resolveChallenge: determines who wins when an attacker moves onto a defender's square.
function ChallengeResolver.resolveChallenge(
	attackerRankId: PieceRank.RankId,
	defenderRankId: PieceRank.RankId
): ChallengeOutcome
	-- Flag vs Flag: attacker's Flag reaching the defender's Flag wins outright.
	if attackerRankId == "Flag" and defenderRankId == "Flag" then
		return "AttackerWins"
	end

	-- Any piece captures an opposing Flag (checked after the Flag-vs-Flag case above).
	if defenderRankId == "Flag" then
		return "AttackerWins"
	end

	-- A Flag loses to literally anything else it challenges (checked after Flag-vs-Flag above).
	if attackerRankId == "Flag" then
		return "DefenderWins"
	end

	-- Spy's one weakness: Private beats Spy, in either direction.
	if attackerRankId == "Spy" and defenderRankId == "Private" then
		return "DefenderWins"
	end
	if defenderRankId == "Spy" and attackerRankId == "Private" then
		return "AttackerWins"
	end

	-- Spy beats every other officer/Sergeant (Private case already excluded above).
	if attackerRankId == "Spy" then
		return "AttackerWins"
	end
	if defenderRankId == "Spy" then
		return "DefenderWins"
	end

	-- Standard case: compare numeric rank value. Equal ranks eliminate both pieces.
	local attackerValue = PieceRank.Ranks[attackerRankId].value
	local defenderValue = PieceRank.Ranks[defenderRankId].value

	if attackerValue > defenderValue then
		return "AttackerWins"
	elseif defenderValue > attackerValue then
		return "DefenderWins"
	else
		return "BothEliminated"
	end
end

return ChallengeResolver