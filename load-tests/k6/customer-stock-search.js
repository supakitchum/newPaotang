import http from 'k6/http';
import { check, sleep } from 'k6';
import { baseUrl, durationOptions, requireEnv, tenantHost } from './lib/profile.js';

const BASE_URL = baseUrl();
const TENANT_HOST = tenantHost();
const GAME_ID = __ENV.GAME_ID || '';
const SEARCH_NUMBER = __ENV.SEARCH_NUMBER || '123';

export const options = durationOptions({
  vus: 20,
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.05'],
  },
});

export default function () {
  requireEnv(['GAME_ID'], 'customer stock search');

  const params = {
    headers: { Host: TENANT_HOST },
  };
  const query = `game_id=${encodeURIComponent(GAME_ID)}&number=${encodeURIComponent(SEARCH_NUMBER)}`;
  const res = http.get(`${BASE_URL}/api/v1/public/stock/search?${query}`, params);

  check(res, {
    'stock search returns ok': (response) => response.status === 200,
  });

  sleep(1);
}
