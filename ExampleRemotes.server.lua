local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteGuard = require(script.Parent.Parent.AntiCheat.RemoteGuard)
local V = RemoteGuard.Validators

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local function make(className, name)
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end

local ITEM_PRICES = { Sword = 100, Shield = 80, Potion = 15 }
local coins = {}

game.Players.PlayerAdded:Connect(function(p)
	coins[p] = 200
end)
game.Players.PlayerRemoving:Connect(function(p)
	coins[p] = nil
end)

RemoteGuard.OnInvoke(make("RemoteFunction", "BuyItem"), {
	rateLimit = 3,
	window = 2,
	schema = { V.oneOf({ "Sword", "Shield", "Potion" }) },
}, function(player, itemName)
	local price = ITEM_PRICES[itemName]
	if not coins[player] or coins[player] < price then
		return { ok = false, reason = "fonds insuffisants" }
	end
	coins[player] -= price
	return { ok = true, coins = coins[player] }
end)

local MAX_RANGE = 12
local DAMAGE = 10

RemoteGuard.OnEvent(make("RemoteEvent", "Attack"), {
	rateLimit = 5,
	window = 1,
	cooldown = 0.4,
	schema = { V.instance("Model", workspace) },
}, function(player, targetModel)
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local targetHum = targetModel:FindFirstChildOfClass("Humanoid")
	local targetRoot = targetModel:FindFirstChild("HumanoidRootPart")
	if not (myRoot and targetHum and targetRoot) or targetHum.Health <= 0 then
		return
	end
	if targetModel == player.Character then
		return
	end
	if (myRoot.Position - targetRoot.Position).Magnitude > MAX_RANGE then
		return
	end
	targetHum:TakeDamage(DAMAGE)
end)
