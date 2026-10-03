-- wrk script: uniform random user id per request over the seeded table.
-- Path prefix is overridable so the same script serves every DB leg:
--   WRK_PATH=/api/db/hot/users/ wrk -s random_user.lua ...
local prefix = os.getenv("WRK_PATH") or "/api/db/users/"
local rows = tonumber(os.getenv("WRK_ROWS")) or 10000

request = function()
    return wrk.format("GET", prefix .. math.random(1, rows))
end
