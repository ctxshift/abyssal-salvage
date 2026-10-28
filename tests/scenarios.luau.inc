-- This file is appended to a disposable copy of main.luau by validate.mjs.
-- It executes the real game logic and real SDK renderer, with controlled input.
local function scenarios()
    local realButton, realPressed = byt.button, byt.pressed
    local held: { [string]: boolean } = {}
    byt.button = function(key: byt.Button): boolean return held[key] == true end
    byt.pressed = function(key: byt.Button): boolean return held[key] == true end
    local function input(key: string?)
        held = if key then { [key] = true } else {}
    end
    for testSeed = 1, 24 do
        local testMap = World.generate(testSeed * 7919)
        local reachable = World.flow(testMap, 24.5, 24.5)
        for _, key in testMap.floors do
            assert(reachable[key] ~= nil, "Disconnected procedural floor")
        end
        for _, room in testMap.rooms do
            assert(World.open(testMap, room.x, room.y), "Room center blocked")
        end
        assert(not World.open(testMap, -1, -1), "Map boundary accepted")
        assert(not World.sight(testMap, 24.5, 24.5, 0, 0), "Light crossed rock")
    end
    reset()
    input("move_right")
    for _ = 1, 30 do update(1 / 60) end
    assert(px > 24.5 and py < 24.5, "Screen-right movement mapping")
    assert(World.open(map, px, py), "Movement escaped floor")
    input("escape")
    local before = elapsed
    update(1 / 60)
    assert(mode == "paused" and elapsed == before, "Pause advanced simulation")
    input(nil)
    for _ = 1, 10 do update(1 / 60) end
    assert(elapsed == before, "Paused timer changed")
    input("escape")
    update(1 / 60)
    assert(mode == "play", "Pause failed to resume")
    input(nil)
    reset()
    input("inventory")
    update(1 / 60)
    assert(mapVisible, "Chart key failed")
    input(nil)
    enemies = { { x = px + 1, y = py, hp = 24, maxHp = 24, kind = 1, flash = 0 } }
    for _ = 1, 15 do update(1 / 60) end
    assert(kills == 1, "Auto harpoon did not kill nearby enemy")
    assert(xp > 0 or #drops > 0, "Kill did not grant salvage")
    enemies = { { x = px + 2, y = py, hp = 24, maxHp = 24, kind = 1, flash = 0 } }
    input("action")
    update(1 / 60)
    assert(sonar > 8 and pulse > 0, "Sonar cooldown missing")
    assert(kills == 2, "Sonar damage missing")
    input(nil)
    reset()
    health = 50
    px, py = caches[1].x, caches[1].y
    update(1 / 60)
    assert(health == 70 and #caches == 7, "Cache repair or consumption failed")
    assert(mode == "upgrade" and level == 2, "Cache did not trigger upgrade")
    assert(#choices == 3 and choices[1] ~= choices[2] and choices[1] ~= choices[3] and choices[2] ~= choices[3], "Duplicate upgrade choices")
    choices, selection = {5, 1, 2}, 1
    applyUpgrade()
    assert(maxHealth == 125 and health == 115 and upgrades[5] == 1, "Suit upgrade failed")
    reset()
    enemies = { { x = px, y = py, hp = 1000, maxHp = 1000, kind = 1, flash = 0 } }
    health = 10
    update(1 / 60)
    assert(mode == "dead" and health == 0, "Death transition failed")
    input("action")
    update(1 / 60)
    assert(mode == "play" and health == 100 and elapsed == 0, "Restart did not reset run")
    input(nil)
    elapsed = 240
    update(1 / 60)
    assert(bossSpawned, "Leviathan did not arrive")
    local boss: Enemy? = nil
    for _, enemy in enemies do
        if enemy.kind == 4 then boss = enemy end
    end
    assert(boss ~= nil, "Boss flag without boss")
    if boss then damage(boss, boss.maxHp) end
    assert(bossDefeated, "Boss death not registered")
    elapsed = 299
    update(1 / 60)
    assert(mode ~= "won", "Extraction opened too early")
    elapsed, px, py = 300, 24.5, 24.5
    update(1 / 60)
    assert(mode == "won", "Extraction failed after boss death")
    reset()
    elapsed = 300
    update(1 / 60)
    assert(mode ~= "won", "Extraction ignored living boss")
    -- Render high-load and modal states through the actual SDK frame protocol.
    enemies = {}
    for i = 1, 90 do
        table.insert(enemies, { x = px + (i % 9 - 4) * 0.3, y = py + (math.floor(i / 9) - 5) * 0.3, hp = 100, maxHp = 100, kind = i % 3 + 1, flash = 0 })
    end
    mapVisible = true
    invulnerable = 1000
    byt.button, byt.pressed = realButton, realPressed
end

local originalInit = game.init
return {
    init = function()
        originalInit()
        scenarios()
    end,
    update = game.update,
    draw = game.draw,
}
