import { writeFileSync } from 'node:fs';

// Original 16-pixel artwork. Palette zero is an opaque abyss; dots are transparent.
const palette = ['#030910', '#071521', '#0b2431', '#123b47', '#1c5660', '#2c7b79', '#48bca4', '#8cebd0', '#dbffe1', '#d9ae69', '#896347', '#483e39', '#8b4564', '#ef7594', '#71a6ce', '#355477'];
const sprites = [];
let pixels;
function sprite(paint) {
  pixels = Array.from({ length: 16 }, () => Array(16).fill('.'));
  paint();
  sprites.push(pixels.map(row => row.join('')));
}
function dot(x, y, c) {
  if (x >= 0 && x < 16 && y >= 0 && y < 16) pixels[y][x] = c;
}
function box(x, y, w, h, c) {
  for (let j = y; j < y + h; j++) for (let i = x; i < x + w; i++) dot(i, j, c);
}
function ellipse(x, y, rx, ry, c) {
  for (let j = 0; j < 16; j++) for (let i = 0; i < 16; i++) {
    if (((i - x) / rx) ** 2 + ((j - y) / ry) ** 2 <= 1) dot(i, j, c);
  }
}
// 0..5: trench and ship deck, with three discrete light levels each.
for (const deck of [false, true]) for (let light = 0; light < 3; light++) sprite(() => {
  for (let y = 0; y < 16; y++) for (let x = 0; x < 16; x++) {
    if (Math.abs(x - 7.5) + Math.abs(y - 7.5) <= 8) {
      const seam = deck ? (x + y) % 4 === 0 : (x * 7 + y * 11) % 19 === 0;
      dot(x, y, deck ? [['1', '2'], ['2', 'b'], ['b', 'a']][light][+seam] : [['1', '2'], ['2', '3'], ['3', '4']][light][+seam]);
    }
  }
});
// 6..8: basalt walls, 9 diver, 10 jellyfish, 11 eel, 12 armored crab.
for (let light = 0; light < 3; light++) sprite(() => {
  ellipse(7, 9, 7, 6, ['1', '2', '3'][light]);
  box(3, 6, 9, 7, ['1', '2', '3'][light]);
  ellipse(7, 5, 7, 4, ['2', '3', '4'][light]);
  box(4, 3, 3, 2, ['3', '4', '5'][light]);
  box(10, 7, 2, 5, ['0', '1', '2'][light]);
  dot(3, 8, '5');
});
sprite(() => {
  box(3, 13, 4, 2, 'a'); box(9, 13, 4, 2, 'a');
  box(4, 8, 8, 5, 'a'); box(5, 8, 6, 4, '9');
  box(2, 8, 2, 4, '9'); box(12, 9, 2, 4, 'a');
  ellipse(7.5, 5, 5.5, 5, 'b'); ellipse(7.5, 4, 4.5, 4, '9');
  ellipse(8, 4, 3, 3, '3'); box(7, 2, 3, 2, '7'); dot(10, 4, '8');
  box(5, 9, 2, 2, '7'); box(11, 7, 4, 2, '8');
});
sprite(() => {
  for (const x of [3, 6, 9, 12]) { box(x, 8, 1, 5, '5'); dot(x + 1, 13, '7'); }
  ellipse(7.5, 6, 6.5, 5, '4'); ellipse(7.5, 5, 5.5, 4, '6');
  box(4, 5, 8, 2, '7'); dot(5, 3, '8'); box(5, 7, 2, 2, '1'); box(10, 7, 2, 2, '1');
});
sprite(() => {
  box(1, 8, 4, 2, 'c'); box(3, 6, 5, 3, 'c'); box(6, 4, 7, 4, 'd');
  box(10, 6, 5, 3, 'c'); box(8, 4, 4, 1, '8'); dot(12, 6, '8');
  dot(3, 10, 'd'); dot(1, 11, 'c'); box(13, 8, 2, 1, '8');
});
sprite(() => {
  for (const y of [8, 11, 13]) { box(1, y, 14, 1, 'a'); }
  ellipse(8, 9, 5, 4, 'a'); ellipse(8, 7, 4, 3, '9');
  box(1, 5, 3, 3, 'c'); box(12, 5, 3, 3, 'c');
  box(4, 6, 2, 2, 'd'); box(10, 6, 2, 2, 'd'); dot(5, 6, '8'); dot(10, 6, '8');
});
// 13 salvage, 14 cache, 15 coral, 16 submarine, 17 leviathan, 18 mast.
sprite(() => { ellipse(8, 9, 5, 4, '2'); box(6, 5, 4, 6, '6'); box(5, 7, 6, 2, '7'); dot(7, 5, '8'); });
sprite(() => { box(2, 6, 12, 8, 'b'); box(3, 5, 10, 7, 'a'); box(3, 6, 10, 2, '9'); box(5, 5, 1, 8, '9'); box(10, 5, 1, 8, '9'); box(7, 8, 2, 2, '7'); });
sprite(() => { box(7, 6, 2, 9, '4'); box(3, 7, 8, 2, '5'); box(3, 3, 1, 5, '6'); box(11, 4, 1, 7, '6'); box(6, 1, 1, 7, '5'); dot(3, 2, '7'); dot(11, 3, '7'); dot(6, 0, '7'); });
sprite(() => { box(5, 3, 5, 4, 'a'); box(7, 1, 1, 3, '9'); box(7, 1, 3, 1, '9'); ellipse(8, 9, 7, 4, 'a'); ellipse(8, 8, 6, 3, '9'); box(0, 7, 2, 6, 'b'); for (const x of [5, 9, 12]) { box(x, 7, 2, 2, '3'); dot(x, 7, '7'); } box(4, 12, 8, 1, 'b'); });
sprite(() => { ellipse(8, 7, 7, 6, 'c'); ellipse(8, 6, 6, 5, 'd'); box(3, 8, 10, 3, '1'); for (const x of [3, 6, 9, 12]) { box(x, 8, 1, 2, '8'); box(x, 12, 2, 3, 'c'); } box(4, 4, 2, 2, '8'); box(10, 4, 2, 2, '8'); });
sprite(() => { box(7, 0, 2, 16, 'a'); box(2, 3, 12, 1, '9'); for (let y = 4; y < 11; y++) box(3 + Math.floor((y - 4) / 3), y, 8 - Math.floor((y - 4) / 2), 1, 'b'); box(8, 0, 1, 16, '9'); });
const glyphs = {
  A:[14,17,17,31,17,17,17], B:[30,17,17,30,17,17,30], C:[14,17,16,16,16,17,14],
  D:[30,17,17,17,17,17,30], E:[31,16,16,30,16,16,31], F:[31,16,16,30,16,16,16],
  G:[14,17,16,23,17,17,15], H:[17,17,17,31,17,17,17], I:[31,4,4,4,4,4,31],
  J:[7,2,2,2,18,18,12], K:[17,18,20,24,20,18,17], L:[16,16,16,16,16,16,31],
  M:[17,27,21,21,17,17,17], N:[17,25,21,19,17,17,17], O:[14,17,17,17,17,17,14],
  P:[30,17,17,30,16,16,16], Q:[14,17,17,17,21,18,13], R:[30,17,17,30,20,18,17],
  S:[15,16,16,14,1,1,30], T:[31,4,4,4,4,4,4], U:[17,17,17,17,17,17,14],
  V:[17,17,17,17,17,10,4], W:[17,17,17,21,21,21,10], X:[17,17,10,4,10,17,17],
  Y:[17,17,10,4,4,4,4], Z:[31,1,2,4,8,16,31],
  '0':[14,17,19,21,25,17,14], '1':[4,12,4,4,4,4,14], '2':[14,17,1,2,4,8,31],
  '3':[30,1,1,14,1,1,30], '4':[2,6,10,18,31,2,2], '5':[31,16,16,30,1,1,30],
  '6':[14,16,16,30,17,17,14], '7':[31,1,2,4,8,8,8], '8':[14,17,17,14,17,17,14],
  '9':[14,17,17,15,1,1,14], ' ':[0,0,0,0,0,0,0], ':':[0,4,4,0,4,4,0],
  '.':[0,0,0,0,0,4,4], ',':[0,0,0,0,4,4,8], '/':[1,2,2,4,8,8,16],
  '+':[0,4,4,31,4,4,0], '-':[0,0,0,31,0,0,0], '[':[14,8,8,8,8,8,14],
  ']':[14,2,2,2,2,2,14], '<':[2,4,8,16,8,4,2], '>':[8,4,2,1,2,4,8],
  '!':[4,4,4,4,4,0,4], '%':[17,2,4,8,16,17,0],
};
const font = Object.fromEntries(Object.entries(glyphs).map(([letter, rows]) => [letter, rows.map(row => row.toString(2).padStart(5, '0'))]));
writeFileSync(new URL('../assets.json', import.meta.url), JSON.stringify({ palette, sprites, font }, null, 2) + '\n');
console.log(`Generated ${sprites.length} original sprites.`);
