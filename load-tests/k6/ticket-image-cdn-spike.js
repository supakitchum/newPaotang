import http from 'k6/http';
import { check, sleep } from 'k6';
import { durationOptions, requireEnv } from './lib/profile.js';

const CDN_BASE_URL = __ENV.CDN_BASE_URL || '';
const IMAGE_PATH = __ENV.IMAGE_PATH || __ENV.TICKET_IMAGE_CDN_IMAGE_PATH || '';

export const options = durationOptions({
  vus: 100,
  thresholds: {
    http_req_duration: ['p(95)<300'],
    http_req_failed: ['rate<0.02'],
  },
});

export default function () {
  requireEnv(['CDN_BASE_URL'], 'ticket image CDN/R2 spike testing');

  if (IMAGE_PATH === '') {
    throw new Error('IMAGE_PATH or TICKET_IMAGE_CDN_IMAGE_PATH is required for ticket image CDN/R2 spike testing.');
  }

  if (!/^https?:\/\//.test(CDN_BASE_URL)) {
    throw new Error('CDN_BASE_URL must be an absolute http(s) CDN/R2 URL for ticket image CDN/R2 spike testing.');
  }

  if ((__ENV.BASE_URL || '') !== '' && CDN_BASE_URL === __ENV.BASE_URL) {
    throw new Error('CDN_BASE_URL must be explicit CDN/R2 infrastructure; BASE_URL is intentionally ignored for ticket image coverage.');
  }

  const base = CDN_BASE_URL.replace(/\/$/, '');
  const path = IMAGE_PATH.replace(/^\//, '');
  const res = http.get(`${base}/${path}`);

  check(res, {
    'ticket image served by CDN or object storage': (response) => response.status === 200,
    'cache header present': (response) => response.headers['Cache-Control'] !== undefined,
  });

  sleep(0.1);
}
