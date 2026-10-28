--!strict
local byt = require("@bytorio")
local World = require("./world")
local Art = require("./art")

type Enemy = { x: number, y: number, hp: number, maxHp: number, kind: number, flash: number }
type Shot = { x: number, y: number, vx: number, vy: number, life: number }
type Drop = { x: number, y: number, value: number }
type Object = { x: number, y: number, sprite: number, size: number, kind: number, index: number }

local DIVE_SECONDS = 300
local map = World.generate(1)
local flow: { [number]: number } = {}
local enemies: { Enemy } = {}
local shots: { Shot } = {}
local drops: { Drop } = {}
local caches: { Drop } = {}
local choices: { number } = {}
local samples: { byt.Sample } = {}
local upgrades = { 0, 0, 0, 0, 0, 0 }
local names = { "TEMPERED HARPOON", "RAPID WINCH", "PRESSURE HALO", "SALVAGE MAGNET", "REINFORCED SUIT", "SONAR CAPACITOR" }
local descriptions = { "+12 HARPOON DAMAGE", "20% FASTER AUTO-FIRE", "HURTS NEARBY HORRORS", "WIDER PICKUP / +SPEED", "+25 HULL AND REPAIR", "FASTER, STRONGER SONAR" }
local mode = "title"
local px, py = 24.5, 24.5
local aimX, aimY = 0.707, -0.707
local health, maxHealth = 100, 100
local elapsed, clock, fireClock, spawnClock, flowClock = 0, 0, 0, 0, 0
local invulnerable, sonar, pulse, haloClock = 0, 0, 0, 0
local level, xp, needed, kills, salvage = 1, 0, 8, 0, 0
local selection, runCount = 1, 0
local bossSpawned, bossDefeated = false, false
local banner, bannerTime = "", 0
local voiceIndex = 1
local mapVisible = false

local function random(n: number): number
    return byt.random_u32() % n + 1
end

local function distance(ax: number, ay: number, bx: number, by: number): number
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

local function project(x: number, y: number): (number, number)
    return 320 + ((x - px) - (y - py)) * 20, 186 + ((x - px) + (y - py)) * 10
end

local function cue(index: number, gain: number?)
    if samples[index] then
        byt.audio.play_sample(byt.audio.voice(voiceIndex), samples[index], { gain = gain or 0.3 })
        voiceIndex = voiceIndex % 7 + 1
    end
end

local function announce(text: string)
    banner, bannerTime = text, 4
end

local function reset()
    runCount += 1
    local seed = 271027 + runCount * 7919
    byt.seed(seed)
    map = World.generate(seed)
    px, py = 24.5, 24.5
    health, maxHealth = 100, 100
    elapsed, fireClock, spawnClock, flowClock = 0, 0, 1.5, 0
    invulnerable, sonar, pulse, haloClock = 0, 0, 0, 0
    level, xp, needed, kills, salvage = 1, 0, 8, 0, 0
    enemies, shots, drops, caches = {}, {}, {}, {}
    upgrades = { 0, 0, 0, 0, 0, 0 }
    bossSpawned, bossDefeated, mapVisible = false, false, false
    flow = World.flow(map, px, py)
    for i, room in map.rooms do
        if i > 1 then
            table.insert(caches, { x = room.x, y = room.y, value = 8 })
        end
    end
    mode = "play"
    announce("SALVAGE THE WRECKS. RETURN WHEN THE TIDE TURNS.")
end

local function init()
    byt.display(640, 360)
    for index = 1, 5 do
        local frames = if index == 3 then 16000 else 6000
        local pcm = byt.data.pcm(frames, 1)
        for frame = 0, frames - 1 do
            local t = frame / 48000
            local frequency = ({ 180, 740, 110, 65, 520 })[index]
            local envelope = (1 - frame / frames) ^ 2
            local value = math.sin(t * frequency * 6.28318 * (1 + t * (if index == 3 then -1 else 2))) * envelope * 0.45
            buffer.writef32(pcm.samples, frame * 4, value)
        end
        samples[index] = byt.audio.sample({ frames = frames, channels = 1, rate = 48000 }, pcm)
    end
    reset()
    mode = "title"
end

local function damage(enemy: Enemy, amount: number)
    if enemy.hp <= 0 then return end
    enemy.hp -= amount
    enemy.flash = 0.12
    if enemy.hp <= 0 then
        kills += 1
        local value = if enemy.kind == 4 then 35 elseif enemy.kind == 3 then 3 else 1
        if #drops < 160 then
            table.insert(drops, { x = enemy.x, y = enemy.y, value = value })
        else
            drops[1].value += value
        end
        if enemy.kind == 4 then
            bossDefeated = true
            announce("THE LEVIATHAN IS SILENT. HOLD UNTIL 05:00.")
        end
    end
end

local function chooseUpgrade()
    mode, selection, choices = "upgrade", 1, {}
    while #choices < 3 do
        local id = random(#names)
        if not table.find(choices, id) then table.insert(choices, id) end
    end
    cue(5)
end

local function applyUpgrade()
    local id = choices[selection]
    upgrades[id] += 1
    if id == 5 then
        maxHealth += 25
        health = math.min(maxHealth, health + 45)
    end
    mode = "play"
end

local function spawn(kind: number): boolean
    if #enemies >= 90 then return false end
    for _ = 1, 70 do
        local key = map.floors[random(#map.floors)]
        local x, y = key % World.SIZE + 0.5, math.floor(key / World.SIZE) + 0.5
        local d = distance(x, y, px, py)
        if d >= 7 and d < 13 then
            local hp = ({ 24, 18, 62, 1100 })[kind] * (1 + elapsed / 500)
            table.insert(enemies, { x = x, y = y, hp = hp, maxHp = hp, kind = kind, flash = 0 })
            return true
        end
    end
    return false
end

local function update(dt: number)
    clock += dt
    if mode == "title" then
        if byt.pressed("action") then
            mode = "play"
            cue(3)
        end
        return
    end
    if mode == "dead" or mode == "won" then
        if byt.pressed("action") then reset() end
        return
    end
    if mode == "upgrade" then
        if byt.pressed("left") then selection = (selection + 1) % 3 + 1 end
        if byt.pressed("right") then selection = selection % 3 + 1 end
        for i, button in { "potion_1", "potion_2", "potion_3" } do
            if byt.pressed(button :: byt.Button) then
                selection = i
                applyUpgrade()
                return
            end
        end
        if byt.pressed("action") then applyUpgrade() end
        return
    end
    if byt.pressed("escape") then
        mode = if mode == "paused" then "play" else "paused"
    end
    if mode == "paused" then return end
    if byt.pressed("map") or byt.pressed("inventory") then mapVisible = not mapVisible end
    elapsed += dt
    bannerTime = math.max(0, bannerTime - dt)
    invulnerable = math.max(0, invulnerable - dt)
    sonar = math.max(0, sonar - dt)
    pulse = math.max(0, pulse - dt)
    local sx, sy = 0, 0
    if byt.button("left") or byt.button("move_left") then sx -= 1 end
    if byt.button("right") or byt.button("move_right") then sx += 1 end
    if byt.button("up") or byt.button("move_up") then sy -= 1 end
    if byt.button("down") or byt.button("move_down") then sy += 1 end
    if sx ~= 0 or sy ~= 0 then
        local dx, dy = sx + sy, sy - sx
        local length = math.sqrt(dx * dx + dy * dy)
        dx, dy = dx / length, dy / length
        local speed = 2.8 + math.min(1.2, upgrades[4] * 0.16)
        px, py = World.move(map, px, py, dx * speed * dt, dy * speed * dt)
        aimX, aimY = dx, dy
    end
    local hovering, mx, my = byt.pointer_position()
    if hovering and distance(mx, my, 320, 174) > 8 then
        local dx = (mx - 320) / 40 + (my - 174) / 20
        local dy = (my - 174) / 20 - (mx - 320) / 40
        local length = math.sqrt(dx * dx + dy * dy)
        aimX, aimY = dx / length, dy / length
    end
    byt.debug_position(px, py)
    if byt.pressed("action") and sonar == 0 then
        sonar = math.max(3, 9 - upgrades[6] * 1.2)
        pulse = 0.7
        cue(3, 0.5)
        for _, enemy in enemies do
            local d = distance(px, py, enemy.x, enemy.y)
            if d < 5 then
                damage(enemy, 35 + upgrades[6] * 18)
                if d > 0 then
                    enemy.x, enemy.y = World.move(map, enemy.x, enemy.y, (enemy.x - px) / d * 0.7, (enemy.y - py) / d * 0.7)
                end
            end
        end
    end
    spawnClock -= dt
    if spawnClock <= 0 then
        spawnClock = math.max(0.25, 1.7 - elapsed / 220)
        local roll = random(10)
        spawn(if elapsed > 80 and roll > 7 then 3 elseif elapsed > 25 and roll > 5 then 2 else 1)
    end
    if elapsed >= 240 and not bossSpawned then
        bossSpawned = spawn(4)
        if bossSpawned then announce("CONTACT: LEVIATHAN. BREAK ITS SHELL.") end
    end
    if elapsed >= DIVE_SECONDS and elapsed - dt < DIVE_SECONDS then
        announce(if bossDefeated then "EXTRACTION OPEN. RETURN TO THE SUBMARINE!" else "EXTRACTION READY. DEFEAT THE LEVIATHAN!")
    end
    flowClock -= dt
    if flowClock <= 0 then
        flowClock = 0.4
        flow = World.flow(map, px, py)
    end
    for _, enemy in enemies do
        if enemy.hp <= 0 then continue end
        enemy.flash = math.max(0, enemy.flash - dt)
        local tx, ty = px, py
        if not World.sight(map, enemy.x, enemy.y, px, py) then
            local key = World.key(enemy.x, enemy.y)
            local best = flow[key] or 9999
            for _, offset in { -1, 1, -World.SIZE, World.SIZE } do
                local candidate = key + offset
                if flow[candidate] and flow[candidate] < best then
                    best = flow[candidate]
                    tx, ty = candidate % World.SIZE + 0.5, math.floor(candidate / World.SIZE) + 0.5
                end
            end
        end
        local d = distance(enemy.x, enemy.y, tx, ty)
        if d > 0.05 then
            local speed = ({ 0.9, 1.75, 0.65, 0.8 })[enemy.kind] * (1 + elapsed / 900)
            enemy.x, enemy.y = World.move(map, enemy.x, enemy.y, (tx - enemy.x) / d * speed * dt, (ty - enemy.y) / d * speed * dt)
        end
        if distance(enemy.x, enemy.y, px, py) < (if enemy.kind == 4 then 1.1 else 0.6) and invulnerable == 0 then
            health -= if enemy.kind == 4 then 25 else 12
            invulnerable = 0.85
            cue(4)
        end
    end
    fireClock -= dt
    if fireClock <= 0 then
        local target: Enemy? = nil
        local nearest = 8
        for _, enemy in enemies do
            local d = distance(px, py, enemy.x, enemy.y)
            if enemy.hp > 0 and d < nearest and World.sight(map, px, py, enemy.x, enemy.y) then
                nearest, target = d, enemy
            end
        end
        if target then
            local length = math.max(0.01, nearest)
            table.insert(shots, { x = px, y = py, vx = (target.x - px) / length * 15, vy = (target.y - py) / length * 15, life = 0.7 })
            fireClock = math.max(0.12, 0.7 * 0.8 ^ upgrades[2])
            cue(1, 0.13)
        end
    end
    for i = #shots, 1, -1 do
        local shot = shots[i]
        shot.x += shot.vx * dt
        shot.y += shot.vy * dt
        shot.life -= dt
        if not World.floor(map, shot.x, shot.y) then shot.life = 0 end
        for _, enemy in enemies do
            if enemy.hp > 0 and shot.life > 0 and distance(shot.x, shot.y, enemy.x, enemy.y) < (if enemy.kind == 4 then 1.2 else 0.55) then
                damage(enemy, 24 + upgrades[1] * 12)
                shot.life = 0
            end
        end
        if shot.life <= 0 then table.remove(shots, i) end
    end
    haloClock -= dt
    if upgrades[3] > 0 and haloClock <= 0 then
        haloClock = 0.7
        for _, enemy in enemies do
            if distance(px, py, enemy.x, enemy.y) < 1.8 + upgrades[3] * 0.15 then
                damage(enemy, 7 + upgrades[3] * 6)
            end
        end
    end
    for i = #enemies, 1, -1 do
        if enemies[i].hp <= 0 then table.remove(enemies, i) end
    end
    for i = #drops, 1, -1 do
        local drop = drops[i]
        local d = distance(px, py, drop.x, drop.y)
        if d < 1.4 + upgrades[4] * 0.65 and d > 0.3 then
            drop.x += (px - drop.x) / d * 7 * dt
            drop.y += (py - drop.y) / d * 7 * dt
        end
        if d < 0.4 then
            xp += drop.value
            salvage += drop.value
            table.remove(drops, i)
            cue(2, 0.12)
        end
    end
    for i = #caches, 1, -1 do
        local cache = caches[i]
        if distance(px, py, cache.x, cache.y) < 0.8 then
            xp += cache.value
            salvage += cache.value
            health = math.min(maxHealth, health + 20)
            table.remove(caches, i)
            announce("WRECK CACHE: +8 SALVAGE / +20 HULL")
            cue(5)
        end
    end
    if health <= 0 then
        health, mode = 0, "dead"
    elseif elapsed >= DIVE_SECONDS and bossDefeated and distance(px, py, 24.5, 24.5) < 1.5 then
        mode = "won"
        cue(5)
    elseif xp >= needed then
        xp -= needed
        level += 1
        needed = math.floor(needed * 1.25 + 3)
        chooseUpgrade()
    end
end

local function lightAt(x: number, y: number): number
    local d = distance(px, py, x, y)
    if pulse > 0 and d < (0.7 - pulse) * 18 then return 2 end
    if d < 2 then return 2 end
    if d > 9 then return 0 end
    local dot = ((x - px) * aimX + (y - py) * aimY) / math.max(d, 0.01)
    if dot > 0.78 and World.sight(map, px, py, x, y) then
        return if d < 6 then 2 else 1
    end
    return if d < 4 then 1 else 0
end

local function ring(radius: number, color: number)
    for i = 0, 35 do
        local angle = i / 36 * math.pi * 2
        local x, y = project(px + math.cos(angle) * radius, py + math.sin(angle) * radius)
        byt.rect(x, y, 2, 2, color)
    end
end

local function drawWorld()
    byt.clear(Art.ink)
    local objects: { Object } = {}
    for y = math.max(0, math.floor(py) - 15), math.min(47, math.floor(py) + 15) do
        for x = math.max(0, math.floor(px) - 15), math.min(47, math.floor(px) + 15) do
            local sx, sy = project(x + 0.5, y + 0.5)
            if sx < -45 or sx > 685 or sy < -30 or sy > 400 then continue end
            local tile = map.cells[World.key(x, y)]
            local light = lightAt(x + 0.5, y + 0.5)
            if tile then
                byt.sprite_size((tile - 1) * 3 + light, sx - 20, sy - 10, 40, 20)
                if (x * 17 + y * 31) % 43 == 0 and distance(x, y, 24, 24) > 3 then
                    table.insert(objects, { x = x + 0.5, y = y + 0.5, sprite = if tile == 2 then 18 else 15, size = 28, kind = 0, index = 0 })
                end
            elseif World.floor(map, x - 1, y) or World.floor(map, x + 1, y) or World.floor(map, x, y - 1) or World.floor(map, x, y + 1) then
                local size = if x + y > px + py then 22 else 40
                table.insert(objects, { x = x + 0.5, y = y + 0.5, sprite = 6 + light, size = size, kind = 0, index = 0 })
            end
        end
    end
    for _, drop in drops do
        local x, y = project(drop.x, drop.y)
        if x > -16 and x < 656 and y > -16 and y < 376 then byt.sprite(13, x - 8, y - 12) end
    end
    table.insert(objects, { x = 23.5, y = 23.5, sprite = 16, size = 64, kind = 0, index = 0 })
    for _, cache in caches do
        table.insert(objects, { x = cache.x, y = cache.y, sprite = 14, size = 24, kind = 0, index = 0 })
    end
    for i, enemy in enemies do
        table.insert(objects, { x = enemy.x, y = enemy.y, sprite = if enemy.kind == 4 then 17 else 9 + enemy.kind, size = if enemy.kind == 4 then 70 else 28, kind = 1, index = i })
    end
    table.insert(objects, { x = px, y = py, sprite = 9, size = 32, kind = 2, index = 0 })
    table.sort(objects, function(a: Object, b: Object): boolean
        return a.x + a.y < b.x + b.y
    end)
    for _, object in objects do
        local x, y = project(object.x, object.y)
        if x < -80 or x > 720 or y < -40 or y > 440 then continue end
        if object.kind == 2 and invulnerable > 0 and math.floor(clock * 16) % 2 == 0 then continue end
        if object.kind == 1 then
            local enemy = enemies[object.index]
            if lightAt(enemy.x, enemy.y) == 0 then
                byt.rect(x - 4, y - 14, 2, 2, if enemy.kind == 2 then Art.pink else Art.mint)
                byt.rect(x + 3, y - 14, 2, 2, if enemy.kind == 2 then Art.pink else Art.mint)
                continue
            end
            if enemy.flash > 0 then byt.rect(x - 8, y - object.size, 16, 2, Art.white) end
            if enemy.kind == 4 then Art.bar(x - 30, y - 72, 60, enemy.hp / enemy.maxHp, Art.pink) end
        end
        byt.sprite_size(object.sprite, x - object.size / 2, y - object.size + 6, object.size, object.size)
    end
    for _, shot in shots do
        local x, y = project(shot.x, shot.y)
        local tx, ty = project(shot.x - shot.vx * 0.045, shot.y - shot.vy * 0.045)
        Art.lineBetween(tx, ty - 10, x, y - 10, Art.mint)
        byt.rect(x - 1, y - 11, 3, 3, Art.white)
    end
    if pulse > 0 then ring((0.7 - pulse) * 14, Art.mint) end
    if upgrades[3] > 0 then ring(1.8 + upgrades[3] * 0.15, Art.dim) end
    for i = 1, 48 do
        local x = (i * 137 + math.sin(clock * 0.2 + i) * 10) % 640
        local y = (i * 71 - clock * (2 + i % 3)) % 360
        byt.rect(x, y, 1, 1, if i % 5 == 0 then Art.dim else Art.line)
    end
    byt.rect(0, 0, 640, 4, Art.ink)
    byt.rect(0, 356, 640, 4, Art.ink)
    byt.rect(0, 0, 4, 360, Art.ink)
    byt.rect(636, 0, 4, 360, Art.ink)
end

local function drawMap()
    Art.panel(490, 63, 138, 142)
    byt.text("SONAR CHART", 500, 72, Art.mint)
    for _, key in map.floors do
        local x, y = key % World.SIZE, math.floor(key / World.SIZE)
        byt.rect(491 + x * 2.7, 78 + y * 2.7, 2, 2, Art.line)
    end
    for _, cache in caches do byt.rect(491 + cache.x * 2.7, 78 + cache.y * 2.7, 3, 3, Art.gold) end
    byt.rect(491 + 24.5 * 2.7, 78 + 24.5 * 2.7, 4, 4, Art.mint)
    byt.rect(491 + px * 2.7, 78 + py * 2.7, 3, 3, Art.white)
end

local function drawHud()
    Art.panel(12, 12, 164, 40)
    byt.text("HULL", 22, 21, Art.dim)
    byt.text(tostring(math.ceil(health)) .. "/" .. tostring(maxHealth), 109, 21, Art.white)
    Art.bar(22, 38, 144, health / maxHealth, if health < 30 then Art.pink else Art.mint)
    Art.panel(236, 12, 168, 40)
    local seconds = math.floor(elapsed)
    byt.text(string.format("%02d:%02d / 05:00", math.floor(seconds / 60), seconds % 60), 275, 22, Art.white)
    byt.text(if elapsed < 240 then "DEPTH 2,840 M" elseif not bossDefeated then "LEVIATHAN CONTACT" else "RETURN TO SUB", 269, 38, Art.dim)
    Art.panel(464, 12, 164, 40)
    byt.text("SALVAGE " .. tostring(salvage), 474, 22, Art.gold)
    byt.text("LV " .. tostring(level), 586, 22, Art.white)
    Art.bar(474, 38, 144, xp / needed, Art.gold)
    Art.panel(12, 322, 616, 26)
    byt.text("WASD MOVE", 22, 332, Art.dim)
    byt.text(if sonar == 0 then "SPACE: SONAR READY" else "SONAR " .. tostring(math.ceil(sonar)) .. "S", 113, 332, if sonar == 0 then Art.mint else Art.dim)
    byt.text("I CHART", 257, 332, Art.dim)
    byt.text("ESC PAUSE", 338, 332, Art.dim)
    byt.text("AUTO HARPOON", 496, 332, Art.gold)
    if bannerTime > 0 then
        local width = #banner * 6 + 20
        Art.panel(320 - width / 2, 284, width, 23)
        byt.text(banner, 330 - width / 2, 292, Art.mint)
    end
    if elapsed >= DIVE_SECONDS then
        local dx, dy = project(24.5, 24.5)
        byt.text("< SUB >", math.clamp(dx, 40, 590) - 20, math.clamp(dy, 110, 280) - 40, Art.gold)
    end
    if mapVisible then drawMap() end
end

local function draw()
    drawWorld()
    if mode == "title" then
        Art.panel(55, 46, 530, 268)
        byt.text("BATHYSPHERE SALVAGE DIVISION   /   DIVE 07", 100, 65, Art.dim)
        Art.large("ABYSSAL", 110, 86, 5, Art.mint)
        Art.large("SALVAGE", 110, 130, 5, Art.gold)
        byt.sprite_size(9, 474, 95, 64, 64)
        byt.text("THE DEEP KEEPS WHAT IT TAKES.", 111, 178, Art.white)
        byt.text("SURVIVE 5 MINUTES. SLAY THE LEVIATHAN. REACH THE SUB.", 111, 199, Art.dim)
        byt.text("WASD / ARROWS   WALK       MOUSE   AIM HELMET BEAM", 111, 222, Art.white)
        byt.text("SPACE   SONAR BURST        I       CHART", 111, 237, Art.white)
        byt.text("HARPOONS FIRE AUTOMATICALLY. COLLECT GLOWING SALVAGE.", 111, 253, Art.dim)
        byt.rect(110, 277, 420, 22, Art.line)
        byt.text("[ SPACE ]  DESCEND INTO THE DARK", 224, 284, Art.mint)
        return
    end
    drawHud()
    if mode == "upgrade" then
        Art.panel(28, 90, 584, 184)
        Art.large("REFIT", 260, 105, 3, Art.gold)
        byt.text("SALVAGE CONVERTED. CHOOSE ONE UPGRADE.", 210, 137, Art.dim)
        for i, id in choices do
            local x = 41 + (i - 1) * 188
            Art.panel(x, 158, 182, 74, if i == selection then Art.mint else Art.line)
            byt.text(tostring(i) .. " / " .. names[id], x + 8, 172, Art.gold)
            byt.text(descriptions[id], x + 8, 191, Art.white)
            byt.text("RANK " .. tostring(upgrades[id] + 1), x + 8, 214, Art.dim)
        end
        byt.text("1 / 2 / 3 TO PICK   OR   ARROWS + SPACE", 208, 249, Art.mint)
    elseif mode == "paused" then
        Art.panel(190, 126, 260, 98)
        Art.large("PAUSED", 214, 143, 4, Art.mint)
        byt.text("ESC TO RESUME THE DIVE", 258, 199, Art.dim)
    elseif mode == "dead" or mode == "won" then
        Art.panel(111, 97, 418, 166)
        Art.large(if mode == "won" then "RECOVERED" else "LOST BELOW", 140, 117, 4, if mode == "won" then Art.mint else Art.pink)
        byt.text(if mode == "won" then "THE SUB RETURNS. THIS TIME, SO DO YOU." else "ANOTHER LIGHT GOES OUT IN THE TRENCH.", 181, 160, Art.dim)
        byt.text("SALVAGE " .. tostring(salvage) .. "   KILLS " .. tostring(kills) .. "   LEVEL " .. tostring(level), 190, 186, Art.gold)
        byt.text("[ SPACE ]  NEW DIVE / NEW SEABED", 211, 231, Art.mint)
    end
end

local game: byt.Game = { init = init, update = update, draw = draw }
return game
