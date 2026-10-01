import http from 'k6/http';
import { check, sleep } from 'k6';
import { baseUrl, iterationOptions, jsonHeaders, requireEnv, tenantHost } from './lib/profile.js';

const BASE_URL = baseUrl();
const TENANT_HOST = tenantHost();
const CUSTOMER_TOKEN = __ENV.CUSTOMER_TOKEN || '';
const RESERVATION_ID = __ENV.RESERVATION_ID || '';

http.setResponseCallback(http.expectedStatuses(201, 409, 422));

export const options = iterationOptions({
  vus: 10,
  iterations: 50,
  thresholds: {
    http_req_duration: ['p(95)<1000'],
    http_req_failed: ['rate<0.05'],
  },
});

export default function () {
  requireEnv(['CUSTOMER_TOKEN', 'RESERVATION_ID'], 'checkout wallet consistency');

  const res = http.post(`${BASE_URL}/api/v1/customer/checkout`, JSON.stringify({
    reservation_id: RESERVATION_ID,
    payment_method: 'wallet',
  }), {
    headers: jsonHeaders({
      Authorization: `Bearer ${CUSTOMER_TOKEN}`,
      Host: TENANT_HOST,
      'Idempotency-Key': `k6-checkout-${__VU}-${__ITER}`,
    }),
  });

  check(res, {
    'checkout returns success or consistency conflict': (response) => [201, 409, 422].includes(response.status),
  });

  sleep(0.5);
}
