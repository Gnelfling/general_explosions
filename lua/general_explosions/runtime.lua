-- Shared, engine-independent math. No renderer/shader contracts live here.
GERuntime = GERuntime or {}
local R = GERuntime

function R.Finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end

function R.Number(n, fallback, lo, hi)
    n = tonumber(n)
    if not R.Finite(n) then n = fallback end
    return math.max(lo, math.min(hi, n))
end

function R.Position(p)
    return isvector(p) and R.Finite(p.x) and R.Finite(p.y) and R.Finite(p.z)
        and math.abs(p.x) <= 32768 and math.abs(p.y) <= 32768 and math.abs(p.z) <= 32768
end

function R.Smooth(t)
    t = R.Number(t, 0, 0, 1)
    return t * t * (3 - 2 * t)
end

-- Independent Park-Miller stream: deterministic, without reseeding GMod RNG.
function R.Random(seed)
    local state = math.floor(R.Number(seed, 1, 1, 2147483646))
    return function(lo, hi)
        state = (state * 16807) % 2147483647
        return lo + (hi - lo) * ((state - 1) / 2147483646)
    end
end

-- Sparse exported sequences hold the preceding sampled frame. Explicit empty
-- records hide the volume while retaining its authored timeline.
function R.Frame(manifest, elapsed, speed, looping)
    local frames = manifest.frames
    local first = manifest.first_frame or frames[1].frame
    local last = manifest.last_frame or frames[#frames].frame
    local span = math.max(last - first + 1, 1)
    local offset = math.floor(math.max(elapsed, 0) * manifest.fps * speed)
    if elapsed < 0 then return nil, true end
    if not looping and offset >= span then return nil, false end
    local desired = first + (looping and offset % span or offset)
    local lo, hi, chosen = 1, #frames, nil
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        if frames[mid].frame <= desired then
            chosen, lo = frames[mid], mid + 1
        else
            hi = mid - 1
        end
    end
    return chosen and not chosen.empty and chosen or nil, true
end
