import http from 'k6/http';
import { check, sleep } from 'k6';
import { baseUrl, iterationOptions, requireEnv } from './lib/profile.js';

const BASE_URL = baseUrl();
const ADMIN_TOKEN = __ENV.ADMIN_TOKEN || '';
const REWARD_RESULT_ID = __ENV.REWARD_RESULT_ID || '';

export const options = iterationOptions({
  vus: 5,
  iterations: 25,
  thresholds: {
    http_req_duration: ['p(95)<1500'],
    http_req_failed: ['rate<0.05'],
  },
});

export default function () {
  requireEnv(['ADMIN_TOKEN', 'REWARD_RESULT_ID'], 'reward checking queue/chunk path');

  const res = http.get(`${BASE_URL}/api/v1/admin/central/rewards/${REWARD_RESULT_ID}/check-batches`, {
    headers: {
      Authorization: `Bearer ${ADMIN_TOKEN}`,
      'X-Admin-Scope': 'central',
    },
  });

  check(res, {
    'reward check batch read is available to central admin': (response) => response.status === 200,
  });

  sleep(1);
}
