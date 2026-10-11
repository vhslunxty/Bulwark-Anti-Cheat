local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteGuard = require(script.Parent.RemoteGuard)
local MovementMonitor = require(script.Parent.MovementMonitor)

local function report(player, source, reason)
	print(string.format("[AntiCheat] %s (%d) | %s | %s", player.Name, player.UserId, source, reason))
end

RemoteGuard.OnViolation = function(player, remoteName, reason)
	report(player, "Remote:" .. remoteName, reason)
end

MovementMonitor.OnViolation = function(player, reason)
	report(player, "Movement", reason)
end

MovementMonitor.Start()

local honeypot = Instance.new("RemoteEvent")
honeypot.Name = "AdminGiveCash"
honeypot.Parent = ReplicatedStorage

honeypot.OnServerEvent:Connect(function(player)
	report(player, "Honeypot", "a déclenché AdminGiveCash")
	if player.Parent == Players then
		player:Kick("Comportement interdit détecté.")
	end
end)
