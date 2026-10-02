import copy
import importlib.metadata
import json
import platform
import sys
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator, FormatChecker
from openapi_spec_validator import OpenAPIV31SpecValidator

out = Path('/evidence')
spec = yaml.safe_load(Path('/workspace/docs/openapi.yaml').read_text())
assert spec['openapi'] == '3.1.0'


def resolve(pointer):
    assert pointer.startswith('#/'), f'External reference not permitted: {pointer}'
    value = spec
    for key in pointer[2:].split('/'):
        value = value[key.replace('~1', '/').replace('~0', '~')]
    return value


refs = []


def walk(value, path=''):
    if isinstance(value, dict):
        if '$ref' in value:
            resolve(value['$ref'])
            refs.append({'path': path, 'ref': value['$ref']})
        for key, child in value.items():
            walk(child, path + '/' + key)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            walk(child, path + '/' + str(index))


walk(spec)
print(f'YAML parsed; OpenAPI {spec["openapi"]}; resolved internal references={len(refs)}')
full_errors = list(OpenAPIV31SpecValidator(spec).iter_errors())
structural = [{'path': list(e.absolute_path), 'message': e.message} for e in full_errors]
(out / 'full-openapi-errors.json').write_text(json.dumps(structural, indent=2) + '\n')
print(f'Full OpenAPI 3.1 specification validation: {"PASS" if not structural else "FAIL"}; errors={len(structural)}')
for e in structural[:5]:
    print(json.dumps(e))

schemas = spec['components']['schemas']
selected = ['CustomerSocialLinkPhoneRequest', 'CustomerSocialLinkPhoneResponse',
            'CustomerSocialRegistrationRequiredResponse', 'CustomerAuthResponse', 'CustomerProfile']
validators = {}
for name in selected:
    # Local definitions preserve the original 2020-12 schema semantics, including unknown nullable.
    schema = {'$schema': 'https://json-schema.org/draft/2020-12/schema',
              '$ref': '#/components/schemas/' + name, 'components': {'schemas': schemas}}
    Draft202012Validator.check_schema(schemas[name])
    validators[name] = Draft202012Validator(schema, format_checker=FormatChecker())
(out / 'target-schemas.json').write_text(json.dumps({n: schemas[n] for n in selected}, indent=2) + '\n')
for path in ['/customer/auth/social/{provider}/link-phone', '/customer/auth/line/link-phone']:
    operation = spec['paths'][path]['post']
    assert operation['requestBody']['content']['application/json']['schema']['$ref'].endswith('/CustomerSocialLinkPhoneRequest')
    assert operation['responses']['200']['content']['application/json']['schema']['$ref'].endswith('/CustomerSocialLinkPhoneResponse')
assert set(schemas['CustomerSocialLinkPhoneRequest']['required']) == {'link_token', 'phone', 'otp_verification_token'}
assert schemas['CustomerSocialLinkPhoneRequest']['properties']['existing_only']['default'] is False

base = {'link_token': 'fictional-handoff', 'phone': '0812345678', 'otp_verification_token': 'fictional-register-otp'}
cases = []


def check(case, name, body, expected, metadata=None):
    errors = list(validators[name].iter_errors(body))
    result = {'case': case, 'schema': name, 'expected_valid': expected, 'valid': not errors,
              'expectation_matched': (not errors) == expected,
              'errors': [{'path': list(e.absolute_path), 'message': e.message,
                          'context': [{'path': list(c.absolute_path), 'message': c.message} for c in e.context]}
                         for e in errors]}
    if metadata:
        result.update(metadata)
    cases.append(result)
    print(f'{case}: valid={not errors}; expected={expected}; errors={len(errors)}')


check('minimal-existing-probe', 'CustomerSocialLinkPhoneRequest', base | {'existing_only': True}, True)
check('legacy-blank-member-probe', 'CustomerSocialLinkPhoneRequest', base | {
    'existing_only': True, 'first_name': '', 'last_name': '', 'password': '',
    'password_confirmation': '', 'accepted_terms': False}, True)
full = base | {'existing_only': False, 'first_name': 'Example', 'last_name': 'Member',
               'password': 'fictional-password', 'password_confirmation': 'fictional-password', 'accepted_terms': True}
check('full-new-member', 'CustomerSocialLinkPhoneRequest', full, True)
omitted = copy.deepcopy(full)
del omitted['existing_only']
del omitted['password_confirmation']
check('backend-omission-fallback', 'CustomerSocialLinkPhoneRequest', omitted, True)
for field in base:
    body = copy.deepcopy(base)
    del body[field]
    check('missing-' + field, 'CustomerSocialLinkPhoneRequest', body, False)
check('nonboolean-existing-only', 'CustomerSocialLinkPhoneRequest', base | {'existing_only': 'true'}, False)
check('top-level-registration', 'CustomerSocialLinkPhoneResponse', {'registration_required': True}, True)
check('false-registration', 'CustomerSocialLinkPhoneResponse', {'registration_required': False}, False)
check('wrapped-registration', 'CustomerSocialLinkPhoneResponse', {'resource': {'registration_required': True}}, False)
check('extra-key-registration', 'CustomerSocialRegistrationRequiredResponse', {'registration_required': True, 'token': 'fictional'}, False)
for index, example in enumerate(schemas['CustomerSocialLinkPhoneRequest'].get('examples', [])):
    check('documented-request-example-' + str(index), 'CustomerSocialLinkPhoneRequest', example, True)
records = json.loads((out / 'controller-responses.json').read_text())
for record in records:
    label = record['provider'] + '-' + record['profile'] + '-' + record['branch']
    check('controller-' + label, 'CustomerSocialLinkPhoneResponse', record['body'], True,
          {k: record[k] for k in ['provider', 'profile', 'branch', 'status']})
    if record['branch'] == 'session':
        check('profile-' + label, 'CustomerProfile', record['body']['user'], True)
populated = next(r['body'] for r in records if r['branch'] == 'session' and r['profile'] == 'populated')
for field, value in [('email', None), ('avatar_url', None), ('preferred_locale', None), ('reward_payout_bank_account', [])]:
    body = copy.deepcopy(populated)
    body['user'][field] = value
    check('isolate-valid-backend-value-' + field, 'CustomerSocialLinkPhoneResponse', body, True)
tools = {'python': platform.python_version(), **{n: importlib.metadata.version(n) for n in ['openapi-spec-validator', 'jsonschema', 'PyYAML']}}
result = {'tools': tools, 'openapi': spec['openapi'], 'resolved_refs': len(refs),
          'full_openapi_errors': structural, 'cases': cases,
          'schema_note': 'OpenAPI 3.1 / JSON Schema 2020-12. nullable is an unknown annotation, not a union with null. No normalization of the source schemas.'}
(out / 'schema-results.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(tools))
unexpected = sum(not c['expectation_matched'] for c in cases)
print(f'Payload cases={len(cases)}; unexpected results={unexpected}')
sys.exit(1 if structural or unexpected else 0)
