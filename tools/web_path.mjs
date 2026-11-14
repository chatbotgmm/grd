// 웹 판(서버 저장소 chatbotgmm/server의 galmaegiman-confirmed/public/defense) 위치 찾기.
// 고도 판은 따로 된 저장소라서, 웹 판 규칙(engine.js)·그림이 있는 서버 저장소를 옆에 받아 두고 쓴다.
// 1) 환경변수 GMM_WEB_DEFENSE  2) 이 저장소 옆의 server 저장소(../server/galmaegiman-confirmed/public/defense)  3) 예전 자리(서버 저장소 안 godot 폴더)
import { existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
export function webDefenseDir() {
  const cands = [process.env.GMM_WEB_DEFENSE, resolve(here, '../../server/galmaegiman-confirmed/public/defense'), resolve(here, '../../public/defense')].filter(Boolean);
  for (const c of cands) if (existsSync(resolve(c, 'engine.js'))) return resolve(c);
  throw new Error(`웹 판 폴더(public/defense)를 찾지 못했어요. 서버 저장소를 이 저장소 옆에 받거나 GMM_WEB_DEFENSE에 경로를 넣어 주세요. 찾아본 곳: ${cands.join(', ')}`);
}
