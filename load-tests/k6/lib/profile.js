const PROFILE = __ENV.K6_PROFILE || 'smoke';

const PROFILES = {
  smoke: {
    duration: '10s',
    vus: 2,
    iterations: 6,
    thresholds: {
      http_req_duration: ['p(95)<1500'],
    },
  },
  baseline: {
    duration: '1m',
    vus: 20,
    iterations: 50,
    thresholds: {
      http_req_duration: ['p(95)<1000'],
    },
  },
  'release-candidate': {
    duration: '5m',
    vus: 75,
    iterations: 250,
    thresholds: {
      http_req_duration: ['p(95)<750'],
    },
  },
};

function selectedProfile() {
  return PROFILES[PROFILE] || PROFILES.smoke;
}

function intEnv(name, fallback) {
  return Number(__ENV[name] || fallback);
}

export function durationOptions(config = {}) {
  const profile = selectedProfile();
  const useScenarioDefaults = PROFILE === 'baseline';

  return {
    vus: intEnv('VUS', useScenarioDefaults ? (config.vus || profile.vus) : profile.vus),
    duration: __ENV.DURATION || (useScenarioDefaults ? (config.duration || profile.duration) : profile.duration),
    thresholds: Object.assign({}, profile.thresholds, config.thresholds || {}),
  };
}

export function iterationOptions(config = {}) {
  const profile = selectedProfile();
  const useScenarioDefaults = PROFILE === 'baseline';

  return {
    vus: intEnv('VUS', useScenarioDefaults ? (config.vus || profile.vus) : profile.vus),
    iterations: intEnv('ITERATIONS', useScenarioDefaults ? (config.iterations || profile.iterations) : profile.iterations),
    thresholds: Object.assign({}, profile.thresholds, config.thresholds || {}),
  };
}

export function requireEnv(names, scenario) {
  const missing = names.filter((name) => (__ENV[name] || '') === '');

  if (missing.length > 0) {
    throw new Error(`Set ${missing.join(', ')} for ${scenario}.`);
  }
}

export function baseUrl() {
  return __ENV.BASE_URL || 'http://host.docker.internal:8000';
}

export function tenantHost() {
  return __ENV.TENANT_HOST || 'alpha.newpaotang.test';
}

export function jsonHeaders(extra = {}) {
  return Object.assign({ 'Content-Type': 'application/json' }, extra);
}
