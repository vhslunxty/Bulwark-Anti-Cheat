local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local cfg = cfg or {}
cfg.config = {
	CHECK_INTERVAL = 0.5,
	SPEED_TOLERANCE = 1.35,
	DISTANCE_SLACK = 3,
	MAX_AIR_TIME = 4,
	HOVER_VELOCITY_Y = -5,
	STRIKES_BEFORE_KICK = 6,
	STRIKE_DECAY = 0.25,
	SPAWN_GRACE = 3,
	LOG = true,
}

local MovementMonitor = {}
MovementMonitor.Config = cfg.config
MovementMonitor.OnViolation = nil

local states = {}
local started = false

local function newState()
	return {
		lastPos = nil,
		lastTime = 0,
		lastSafe = nil,
		strikes = 0,
		airTime = 0,
		graceUntil = os.clock() + cfg.config.SPAWN_GRACE,
	}
end

function MovementMonitor.Grant(player, seconds)
	local s = states[player]
	if s then
		s.graceUntil = math.max(s.graceUntil, os.clock() + seconds)
		s.lastPos = nil
		s.airTime = 0
	end
end

local function violation(player, s, root, reason)
	s.strikes += 1
	if cfg.config.LOG then
		warn(string.format("[MovementMonitor] %s : %s (strikes %.1f)", player.Name, reason, s.strikes))
	end
	if MovementMonitor.OnViolation then
		task.spawn(MovementMonitor.OnViolation, player, reason)
	end

	if s.lastSafe then
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = root.CFrame.Rotation + s.lastSafe
	end
	s.lastPos = nil
	s.airTime = 0

	if s.strikes >= cfg.config.STRIKES_BEFORE_KICK and player.Parent == Players then
		player:Kick("Mouvement anormal détecté.")
	end
end

local function check(player, s, now)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and root) or hum.Health <= 0 then
		s.lastPos = nil
		return
	end

	if now < s.graceUntil or hum.SeatPart then
		s.lastPos, s.lastTime, s.airTime = root.Position, now, 0
		s.lastSafe = root.Position
		return
	end

	local pos = root.Position
	local dt = now - s.lastTime
	local bad = nil

	if s.lastPos and dt > 0 then
		local delta = Vector3.new(pos.X - s.lastPos.X, 0, pos.Z - s.lastPos.Z).Magnitude
		local allowed = hum.WalkSpeed * cfg.config.SPEED_TOLERANCE * dt + cfg.config.DISTANCE_SLACK
		if delta > allowed then
			bad = string.format("vitesse/téléportation (%.1f > %.1f studs)", delta, allowed)
		end
	end

	if hum.FloorMaterial == Enum.Material.Air then
		local state = hum:GetState()
		local legit = state == Enum.HumanoidStateType.Climbing
			or state == Enum.HumanoidStateType.Swimming
			or state == Enum.HumanoidStateType.Flying
		if not legit and root.AssemblyLinearVelocity.Y > cfg.config.HOVER_VELOCITY_Y then
			s.airTime += dt
		else
			s.airTime = 0
		end
		if not bad and s.airTime > cfg.config.MAX_AIR_TIME then
			bad = string.format("fly-hack (%.1fs en l'air)", s.airTime)
		end
	else
		s.airTime = 0
	end

	if bad then
		violation(player, s, root, bad)
		return
	end

	s.strikes = math.max(0, s.strikes - cfg.config.STRIKE_DECAY)
	s.lastPos, s.lastTime = pos, now
	if hum.FloorMaterial ~= Enum.Material.Air then
		s.lastSafe = pos
	end
end

local function track(player)
	states[player] = newState()
	player.CharacterAdded:Connect(function()
		local s = states[player]
		if s then
			s.lastPos, s.airTime, s.lastSafe = nil, 0, nil
			s.graceUntil = os.clock() + cfg.config.SPAWN_GRACE
		end
	end)
end

function MovementMonitor.Start()
	if started then
		return
	end
	started = true

	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < cfg.config.CHECK_INTERVAL then
			return
		end
		acc = 0
		local now = os.clock()
		for player, s in states do
			check(player, s, now)
		end
	end)
end

return MovementMonitor
