import http from 'k6/http';
import { check, sleep } from 'k6';
import { baseUrl, durationOptions, requireEnv, tenantHost } from './lib/profile.js';

const BASE_URL = baseUrl();
const GAME_ID = __ENV.REWARD_GAME_ID || __ENV.GAME_ID || '';
const TENANT_HOST = tenantHost();

export const options = durationOptions({
  vus: 50,
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.05'],
  },
});

export default function () {
  requireEnv([__ENV.REWARD_GAME_ID ? 'REWARD_GAME_ID' : 'GAME_ID'], 'reward publish spike reads');

  const res = http.get(`${BASE_URL}/api/v1/public/results/${GAME_ID}`, {
    headers: { Host: TENANT_HOST },
  });

  check(res, {
    'published reward result returns ok': (response) => response.status === 200,
  });

  sleep(0.5);
}
