--!strict
-- BoardRenderer: turns a GameEngine PublicState into visible parts in the workspace.
-- Client-only, purely visual — never touches game logic or Remotes directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local GameEngine = require(ReplicatedStorage.Shared.GameEngine.GameEngine)

local CELL_SIZE = 4 -- studs per board cell
local BOARD_ORIGIN = Vector3.new(0, 5, 0) -- world position of cell (1,1)'s center

local BoardRenderer = {}

local piecesFolder: Folder? = nil

-- cellPosition: converts a (row, col) board coordinate into a world position.
local function cellPosition(row: number, col: number): Vector3
	return BOARD_ORIGIN + Vector3.new((col - 1) * CELL_SIZE, 0, (row - 1) * CELL_SIZE)
end

-- init: builds the static 8x9 board grid once. Safe to call multiple times (clears/rebuilds).
function BoardRenderer.init()
	local existingCells = Workspace:FindFirstChild("BoardCells")
	if existingCells then
		existingCells:Destroy()
	end
	local existingPieces = Workspace:FindFirstChild("BoardPieces")
	if existingPieces then
		existingPieces:Destroy()
	end

	local cells = Instance.new("Folder")
	cells.Name = "BoardCells"
	cells.Parent = Workspace

	for row = 1, 8 do
		for col = 1, 9 do
			local cell = Instance.new("Part")
			cell.Name = string.format("Cell_%d_%d", row, col)
			cell.Size = Vector3.new(CELL_SIZE - 0.2, 1, CELL_SIZE - 0.2)
			cell.Position = cellPosition(row, col)
			cell.Anchored = true
			cell.CanCollide = false
			cell.Color = if (row + col) % 2 == 0 then Color3.fromRGB(210, 210, 210) else Color3.fromRGB(160, 160, 160)
			cell.Material = Enum.Material.SmoothPlastic
			cell.Parent = cells
		end
	end

	local pieces = Instance.new("Folder")
	pieces.Name = "BoardPieces"
	pieces.Parent = Workspace
	piecesFolder = pieces
end

-- render: clears and redraws all piece visuals from a PublicState.
function BoardRenderer.render(state: GameEngine.PublicState)
	if piecesFolder == nil then
		BoardRenderer.init()
	end
	local pieces = piecesFolder :: Folder
	pieces:ClearAllChildren()

	for row = 1, 8 do
		local rowData = state.board[row]
		if rowData ~= nil then
			for col = 1, 9 do
				local piece = rowData[col]
				if piece ~= nil then
					local visual = Instance.new("Part")
					visual.Name = string.format("Piece_%d_%d", row, col)
					visual.Shape = Enum.PartType.Cylinder
					visual.Size = Vector3.new(1.5, CELL_SIZE - 1, CELL_SIZE - 1)
					visual.Orientation = Vector3.new(0, 0, 90)
					visual.Position = cellPosition(row, col) + Vector3.new(0, 1.5, 0)
					visual.Anchored = true
					visual.CanCollide = false
					visual.Color = if piece.owner == "PlayerA" then Color3.fromRGB(70, 130, 220) else Color3.fromRGB(210, 70, 70)
					visual.Material = Enum.Material.Neon

					local label = Instance.new("BillboardGui")
					label.Size = UDim2.new(4, 0, 2, 0)
					label.AlwaysOnTop = true
					label.Parent = visual

					local text = Instance.new("TextLabel")
					text.Size = UDim2.new(1, 0, 1, 0)
					text.BackgroundTransparency = 1
					text.TextScaled = true
					text.TextColor3 = Color3.new(1, 1, 1)
					text.Text = if piece.rankId ~= nil then piece.rankId else "?"
					text.Parent = label

					visual.Parent = pieces
				end
			end
		end
	end
end

return BoardRenderer