--!strict
local World = {}
World.SIZE = 48
export type Room = { x: number, y: number, deck: boolean }
export type Map = { cells: { [number]: number }, rooms: { Room }, floors: { number } }

function World.key(x: number, y: number): number
    return math.floor(x) + math.floor(y) * World.SIZE
end

function World.floor(map: Map, x: number, y: number): boolean
    return x >= 0 and y >= 0 and x < World.SIZE and y < World.SIZE
        and (map.cells[World.key(x, y)] or 0) > 0
end

function World.generate(seed: number): Map
    local state = seed
    local function random(n: number): number
        state = (state * 16807) % 2147483647
        return state % n
    end
    local map: Map = { cells = {}, rooms = {}, floors = {} }
    local centers = { {24, 24}, {12, 24}, {12, 12}, {24, 12}, {36, 12}, {36, 24}, {36, 36}, {24, 36}, {12, 36} }
    local function carve(x: number, y: number, tile: number)
        map.cells[World.key(x, y)] = tile
    end
    for i, center in centers do
        local cx, cy = center[1], center[2]
        local deck = i % 2 == 0
        table.insert(map.rooms, { x = cx + 0.5, y = cy + 0.5, deck = deck })
        local rx, ry = 3 + random(2), 3 + random(2)
        for y = cy - ry, cy + ry do
            for x = cx - rx, cx + rx do
                carve(x, y, if deck then 2 else 1)
            end
        end
        if i > 1 then
            local previous = centers[i - 1]
            for x = math.min(cx, previous[1]), math.max(cx, previous[1]) do
                for offset = -1, 1 do
                    carve(x, previous[2] + offset, 1)
                end
            end
            for y = math.min(cy, previous[2]), math.max(cy, previous[2]) do
                for offset = -1, 1 do
                    carve(cx + offset, y, 1)
                end
            end
        end
    end
    -- Close the route so no room is a mandatory dead end.
    for x = 12, 24 do
        for offset = -1, 1 do
            carve(x, 36 + offset, 1)
        end
    end
    for y = 24, 36 do
        for offset = -1, 1 do
            carve(24 + offset, y, 1)
        end
    end
    for y = 0, World.SIZE - 1 do
        for x = 0, World.SIZE - 1 do
            if World.floor(map, x, y) then
                table.insert(map.floors, World.key(x, y))
            end
        end
    end
    return map
end

function World.open(map: Map, x: number, y: number): boolean
    local radius = 0.2
    return World.floor(map, x - radius, y - radius)
        and World.floor(map, x + radius, y - radius)
        and World.floor(map, x - radius, y + radius)
        and World.floor(map, x + radius, y + radius)
end

function World.move(map: Map, x: number, y: number, dx: number, dy: number): (number, number)
    if World.open(map, x + dx, y) then
        x += dx
    end
    if World.open(map, x, y + dy) then
        y += dy
    end
    return x, y
end

function World.sight(map: Map, ax: number, ay: number, bx: number, by: number): boolean
    local steps = math.ceil(math.max(math.abs(bx - ax), math.abs(by - ay)) * 3)
    for i = 1, steps do
        local t = i / steps
        if not World.floor(map, ax + (bx - ax) * t, ay + (by - ay) * t) then
            return false
        end
    end
    return true
end

function World.flow(map: Map, x: number, y: number): { [number]: number }
    local start = World.key(x, y)
    local distances = { [start] = 0 }
    local queue = { start }
    local head = 1
    while head <= #queue do
        local key = queue[head]
        head += 1
        for _, offset in { -1, 1, -World.SIZE, World.SIZE } do
            local nextKey = key + offset
            if map.cells[nextKey] and distances[nextKey] == nil then
                distances[nextKey] = distances[key] + 1
                table.insert(queue, nextKey)
            end
        end
    end
    return distances
end

return World
