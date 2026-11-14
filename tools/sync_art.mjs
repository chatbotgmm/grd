// 웹 판 그림(서버 저장소 public/game60/assets) 중 디펜스가 쓰는 것만 이 저장소 assets/art로 복사한다.
// 쓰는 것: 갈매미 앞모습(units/<id>-front) · 적(enemies/black, 웨이브·보스·외부탐사 대장 모습) · 외부탐사 지역·첫 화면 배경(village) · 메뉴 아이콘·새우(menu) · 장식·아이콘(ui)
// 사용: node tools/sync_art.mjs   (그림이 바뀌었을 때만 다시 돌리면 됨)
import { copyFileSync, mkdirSync, existsSync, statSync } from 'node:fs';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { resolve, dirname } from 'node:path';
import { webDefenseDir } from './web_path.mjs';
const here = dirname(fileURLToPath(import.meta.url));
const web = webDefenseDir(), src = resolve(web, '../game60/assets'), dst = resolve(here, '../assets/art');
const E = await import(pathToFileURL(resolve(web, 'engine.js')).href);
const files = new Set();
for (const u of E.UNITS) files.add(`units/${u.id}-front.webp`);
const looks = new Set([...E.ENEMY_LOOK.flatMap(([, b]) => b), ...E.BOSS_LOOK, ...E.REGIONS.map((r) => r.look)]);
for (const l of looks) { const [k, id] = l.split(':'); files.add(`${k === 'e' ? 'enemies' : 'black'}/${id}.webp`); }
for (const r of E.REGIONS) files.add(`village/${r.img}.webp`);
files.add('village/10-distant-bay.webp');
for (const f of ['menu/icon-draw', 'menu/icon-team', 'menu/icon-explore', 'menu/icon-shop', 'menu/icon-combine', 'menu/currency-shrimp', 'ui/icon-goldenstrike',
  'ui/decor-corner-tl', 'ui/decor-corner-tr', 'ui/decor-corner-bl', 'ui/decor-corner-br']) files.add(`${f}.webp`);
let n = 0, bytes = 0; const missing = [];
for (const f of [...files].sort()) {
  const a = resolve(src, f);
  if (!existsSync(a)) { missing.push(f); continue; }
  mkdirSync(dirname(resolve(dst, f)), { recursive: true });
  copyFileSync(a, resolve(dst, f)); n++; bytes += statSync(a).size;
}
console.log(`그림 ${n}개 복사(${(bytes / 1048576).toFixed(1)}MB) → ${dst}${missing.length ? ` · 없는 것: ${missing.join(', ')}` : ''}`);
