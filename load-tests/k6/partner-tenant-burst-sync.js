import http from 'k6/http';
import { check, sleep } from 'k6';
import { baseUrl, durationOptions, jsonHeaders, requireEnv } from './lib/profile.js';

const BASE_URL = baseUrl();
const PARTNER_SYNC_PATH = __ENV.PARTNER_SYNC_PATH || '';
const PARTNER_TOKEN = __ENV.PARTNER_TOKEN || '';
const PARTNER_ID = __ENV.PARTNER_ID || '';
const TENANT_ID = __ENV.TENANT_ID || '';

export const options = durationOptions({
  vus: 20,
  thresholds: {
    http_req_duration: ['p(95)<1000'],
    http_req_failed: ['rate<0.05'],
  },
});

export default function () {
  requireEnv(['PARTNER_SYNC_PATH', 'PARTNER_TOKEN', 'PARTNER_ID', 'TENANT_ID'], 'partner burst sync');

  const eventId = `k6-sync-${__VU}-${__ITER}`;

  const res = http.post(`${BASE_URL}${PARTNER_SYNC_PATH}`, JSON.stringify({
    events: [{
      event_id: eventId,
      event_type: 'stock.sync_completed.v1',
      event_version: 1,
      occurred_at: new Date().toISOString(),
      producer: 'partner_store',
      tenant_id: TENANT_ID,
      partner_id: PARTNER_ID,
      game_id: __ENV.GAME_ID || null,
      idempotency_key: eventId,
      correlation_id: eventId,
      payload: { cursor: `k6-cursor-${__ITER}`, item_count: 1 },
    }],
  }), {
    headers: jsonHeaders({
      Authorization: `Bearer ${PARTNER_TOKEN}`,
      'X-Partner-Id': PARTNER_ID,
      'X-Tenant-Id': TENANT_ID,
      'Idempotency-Key': eventId,
    }),
  });

  check(res, {
    'partner sync batch accepted': (response) => response.status === 202,
  });

  sleep(0.2);
}
