--!strict
-- MatchController: client bootstrap. Builds the initial board and listens for StateUpdate to re-render it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.Remotes.Match
local BoardRenderer = require(script.Parent.BoardRenderer)

BoardRenderer.init()

Remotes.StateUpdate.OnClientEvent:Connect(function(state)
	BoardRenderer.render(state)
end)

print("[MatchController] Ready — listening for StateUpdate")