local Players = game:GetService("Players")

local cfg = cfg or {}
cfg.config = {
	DEFAULT_RATE_LIMIT = 10,
	DEFAULT_WINDOW = 1,
	KICK_THRESHOLD = 8,
	VIOLATION_DECAY = 60,
	LOG = true,
}

local RemoteGuard = {}
RemoteGuard.Config = cfg.config
RemoteGuard.OnViolation = nil

local V = {}

function V.string(maxLength)
	return function(v)
		return typeof(v) == "string" and #v <= maxLength
	end
end

function V.boolean()
	return function(v)
		return typeof(v) == "boolean"
	end
end

function V.number(min, max)
	return function(v)
		return typeof(v) == "number" and v == v and v >= min and v <= max
	end
end

function V.integer(min, max)
	return function(v)
		return typeof(v) == "number" and v == v and v >= min and v <= max and v % 1 == 0
	end
end

function V.oneOf(list)
	local set = {}
	for _, item in list do
		set[item] = true
	end
	return function(v)
		return set[v] == true
	end
end

function V.instance(className, ancestor)
	return function(v)
		if typeof(v) ~= "Instance" or not v:IsA(className) then
			return false
		end
		return ancestor == nil or v:IsDescendantOf(ancestor)
	end
end

function V.vector3(maxMagnitude)
	return function(v)
		if typeof(v) ~= "Vector3" then
			return false
		end
		local m = v.Magnitude
		return m == m and m <= maxMagnitude
	end
end

function V.optional(validator)
	return function(v)
		return v == nil or validator(v)
	end
end

RemoteGuard.Validators = V

local buckets = {}
local violations = {}

local function flag(player, remote, reason)
	local now = os.clock()
	local fresh = {}
	for _, t in violations[player] or {} do
		if now - t <= cfg.config.VIOLATION_DECAY then
			table.insert(fresh, t)
		end
	end
	table.insert(fresh, now)
	violations[player] = fresh

	if cfg.config.LOG then
		warn(string.format("[RemoteGuard] %s -> %s : %s", player.Name, remote.Name, reason))
	end
	if RemoteGuard.OnViolation then
		task.spawn(RemoteGuard.OnViolation, player, remote.Name, reason)
	end
	if #fresh >= cfg.config.KICK_THRESHOLD and player.Parent == Players then
		player:Kick("Activité réseau anormale détectée.")
	end
end

local function admit(player, remote, opts, ...)
	if player.Parent ~= Players then
		return false
	end

	if opts.authorize and not opts.authorize(player) then
		flag(player, remote, "appel non autorisé")
		return false
	end

	local now = os.clock()
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local bucket = perPlayer[remote]
	if not bucket then
		bucket = { count = 0, windowStart = now, lastCall = 0 }
		perPlayer[remote] = bucket
	end

	local window = opts.window or cfg.config.DEFAULT_WINDOW
	if now - bucket.windowStart >= window then
		bucket.windowStart = now
		bucket.count = 0
	end
	bucket.count += 1
	local limit = opts.rateLimit or cfg.config.DEFAULT_RATE_LIMIT
	if bucket.count > limit then
		if bucket.count == limit + 1 then
			flag(player, remote, "rate limit dépassé")
		end
		return false
	end

	if opts.cooldown and now - bucket.lastCall < opts.cooldown then
		flag(player, remote, "cooldown non respecté")
		return false
	end

	local schema = opts.schema
	if schema then
		local args = table.pack(...)
		if args.n > #schema then
			flag(player, remote, "trop d'arguments")
			return false
		end
		for i, validator in schema do
			if not validator(args[i]) then
				flag(player, remote, "argument #" .. i .. " invalide")
				return false
			end
		end
	end

	bucket.lastCall = now
	return true
end

function RemoteGuard.OnEvent(remote, opts, handler)
	assert(remote:IsA("RemoteEvent"), "RemoteGuard.OnEvent attend un RemoteEvent")
	return remote.OnServerEvent:Connect(function(player, ...)
		if admit(player, remote, opts, ...) then
			handler(player, ...)
		end
	end)
end

function RemoteGuard.OnInvoke(remote, opts, handler)
	assert(remote:IsA("RemoteFunction"), "RemoteGuard.OnInvoke attend une RemoteFunction")
	remote.OnServerInvoke = function(player, ...)
		if not admit(player, remote, opts, ...) then
			return nil
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn("[RemoteGuard] erreur dans " .. remote.Name .. " : " .. tostring(result))
			return nil
		end
		return result
	end
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
	violations[player] = nil
end)

return RemoteGuard
