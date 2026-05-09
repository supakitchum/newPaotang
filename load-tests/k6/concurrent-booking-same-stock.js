import http from 'k6/http';
import { check, sleep } from 'k6';
import { baseUrl, iterationOptions, jsonHeaders, requireEnv, tenantHost } from './lib/profile.js';

const BASE_URL = baseUrl();
const TENANT_HOST = tenantHost();
const CUSTOMER_TOKEN = __ENV.CUSTOMER_TOKEN || '';
const GAME_ID = __ENV.GAME_ID || '';
const LOCAL_STOCK_ITEM_ID = __ENV.LOCAL_STOCK_ITEM_ID || '';

http.setResponseCallback(http.expectedStatuses(201, 409, 422));

export const options = iterationOptions({
  vus: 25,
  iterations: 100,
  thresholds: {
    http_req_duration: ['p(95)<750'],
    http_req_failed: ['rate<0.05'],
  },
});

export default function () {
  requireEnv(['CUSTOMER_TOKEN', 'GAME_ID', 'LOCAL_STOCK_ITEM_ID'], 'same-stock booking');

  const res = http.post(`${BASE_URL}/api/v1/customer/reservations`, JSON.stringify({
    game_id: GAME_ID,
    local_stock_item_ids: [LOCAL_STOCK_ITEM_ID],
  }), {
    headers: jsonHeaders({
      Authorization: `Bearer ${CUSTOMER_TOKEN}`,
      Host: TENANT_HOST,
      'Idempotency-Key': `k6-booking-${__VU}-${__ITER}`,
    }),
  });

  check(res, {
    'booking returns success or contention status': (response) => [201, 409, 422].includes(response.status),
  });

  sleep(0.2);
}
