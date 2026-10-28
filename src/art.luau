--!strict
local byt = require("@bytorio")
local Art = {}
Art.ink = byt.rgb(3, 9, 16)
Art.background = byt.rgb(7, 21, 33)
Art.line = byt.rgb(28, 69, 78)
Art.dim = byt.rgb(92, 130, 143)
Art.white = byt.rgb(219, 255, 225)
Art.mint = byt.rgb(140, 235, 208)
Art.gold = byt.rgb(217, 174, 105)
Art.pink = byt.rgb(239, 117, 148)

local glyphs = {
    A = {14,17,17,31,17,17,17}, B = {30,17,17,30,17,17,30},
    C = {14,17,16,16,16,17,14}, D = {30,17,17,17,17,17,30},
    E = {31,16,16,30,16,16,31}, F = {31,16,16,30,16,16,16},
    G = {14,17,16,23,17,17,15}, H = {17,17,17,31,17,17,17},
    I = {31,4,4,4,4,4,31}, J = {7,2,2,2,18,18,12},
    K = {17,18,20,24,20,18,17}, L = {16,16,16,16,16,16,31},
    M = {17,27,21,21,17,17,17}, N = {17,25,21,19,17,17,17},
    O = {14,17,17,17,17,17,14}, P = {30,17,17,30,16,16,16},
    Q = {14,17,17,17,21,18,13}, R = {30,17,17,30,20,18,17},
    S = {15,16,16,14,1,1,30}, T = {31,4,4,4,4,4,4},
    U = {17,17,17,17,17,17,14}, V = {17,17,17,17,17,10,4},
    W = {17,17,17,21,21,21,10}, X = {17,17,10,4,10,17,17},
    Y = {17,17,10,4,4,4,4}, Z = {31,1,2,4,8,16,31},
}

function Art.large(text: string, x: number, y: number, scale: number, color: number)
    for i = 1, #text do
        local glyph = glyphs[string.sub(text, i, i)]
        if glyph then
            for row, bits in glyph do
                for col = 0, 4 do
                    if bit32.band(bits, bit32.lshift(1, 4 - col)) ~= 0 then
                        byt.rect(x + (i - 1) * 6 * scale + col * scale, y + (row - 1) * scale, scale, scale, color)
                    end
                end
            end
        end
    end
end

function Art.panel(x: number, y: number, w: number, h: number, color: number?)
    byt.rect(x, y, w, h, color or Art.line)
    byt.rect(x + 1, y + 1, w - 2, h - 2, byt.rgb(7, 21, 33))
end

function Art.bar(x: number, y: number, w: number, value: number, color: number)
    byt.rect(x, y, w, 4, Art.line)
    byt.rect(x, y, math.floor(w * math.clamp(value, 0, 1)), 4, color)
end

function Art.lineBetween(ax: number, ay: number, bx: number, by: number, color: number)
    local steps = math.max(1, math.ceil(math.max(math.abs(bx - ax), math.abs(by - ay)) / 2))
    for i = 0, steps do
        local t = i / steps
        byt.rect(ax + (bx - ax) * t, ay + (by - ay) * t, 2, 2, color)
    end
end

return Art
