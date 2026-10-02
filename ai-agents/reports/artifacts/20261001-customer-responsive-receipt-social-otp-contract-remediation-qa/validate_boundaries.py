import copy
import hashlib
import json
import sys
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator, FormatChecker

out = Path('/evidence')
doc_bytes = Path('/workspace/docs/openapi.yaml').read_bytes()
doc_hash = hashlib.sha256(doc_bytes).hexdigest()
assert doc_hash == '0e99748570a37c0164e6d5e9ebb8ff1dda36bbffba2f1273fa487da2e594d3d5'
schemas = yaml.safe_load(doc_bytes)['components']['schemas']
old = json.loads((out / 'prior-target-schemas.json').read_text())
profile_schema = schemas['CustomerProfile']
props = profile_schema['properties']
invariants = {}
for field in ['email', 'avatar_url', 'preferred_locale']:
    invariants[field + '-explicit-types'] = props[field]['type'] == ['string', 'null']
    invariants[field + '-no-nullable-extension'] = 'nullable' not in props[field]
invariants['email-format-preserved'] = props['email']['format'] == 'email'
invariants['avatar-format-preserved'] = props['avatar_url']['format'] == 'uri'
invariants['bank-exact-alternatives'] = props['reward_payout_bank_account']['oneOf'] == [
    {'$ref': '#/components/schemas/CustomerBankAccount'}, {'type': 'null'}, {'type': 'array', 'maxItems': 0},
]
for name in ['CustomerSocialLinkPhoneRequest', 'CustomerSocialLinkPhoneResponse',
             'CustomerSocialRegistrationRequiredResponse', 'CustomerAuthResponse']:
    invariants[name + '-unchanged'] = schemas[name] == old[name]
changed = {'email', 'avatar_url', 'preferred_locale', 'reward_payout_bank_account'}
invariants['other-profile-properties-unchanged'] = {
    k: v for k, v in props.items() if k not in changed
} == {k: v for k, v in old['CustomerProfile']['properties'].items() if k not in changed}
invariants['profile-root-unchanged'] = {
    k: v for k, v in profile_schema.items() if k != 'properties'
} == {k: v for k, v in old['CustomerProfile'].items() if k != 'properties'}
invariants['bank-object-required-fields'] = set(schemas['CustomerBankAccount']['required']) == {
    'bank_name', 'account_name', 'account_number',
}

formats = FormatChecker()
assert 'email' in formats.checkers and 'uri' in formats.checkers
validators = {}
for name in ['CustomerProfile', 'CustomerSocialLinkPhoneResponse']:
    wrapper = {'$schema': 'https://json-schema.org/draft/2020-12/schema',
               '$ref': '#/components/schemas/' + name, 'components': {'schemas': schemas}}
    validators[name] = Draft202012Validator(wrapper, format_checker=formats)
records = json.loads((out / 'controller-responses.json').read_text())
session = next(r['body'] for r in records if r['profile'] == 'populated' and r['branch'] == 'session')
results = []


def check(label, field, value, expected):
    body = copy.deepcopy(session)
    body['user'][field] = value
    checks = []
    for name, payload in [('CustomerProfile', body['user']), ('CustomerSocialLinkPhoneResponse', body)]:
        errors = list(validators[name].iter_errors(payload))
        checks.append({'schema': name, 'valid': not errors, 'expected_valid': expected,
                       'matched': (not errors) == expected,
                       'errors': [{'path': list(e.absolute_path), 'message': e.message} for e in errors]})
    result = {'case': label, 'field': field, 'value': value, 'checks': checks,
              'passed': all(c['matched'] for c in checks)}
    results.append(result)
    print(f'{label}: expected_valid={expected}; PASS={result["passed"]}')


for field, populated in [('email', 'example@example.test'),
                         ('avatar_url', 'https://example.test/avatar.png'), ('preferred_locale', 'th-TH')]:
    for label, value, expected in [('null', None, True), ('string', populated, True),
                                  ('number', 42, False), ('boolean', False, False),
                                  ('array', [], False), ('object', {}, False)]:
        check(field + '-' + label, field, value, expected)
check('email-invalid-format', 'email', 'not-an-email', False)
check('avatar-invalid-uri-format', 'avatar_url', 'not a URI', False)
bank = {'bank_name': 'Fictional Bank', 'account_name': 'Example Member', 'account_number': '0000000000'}
field = 'reward_payout_bank_account'
check('bank-configured-object', field, bank, True)
check('bank-null-compatibility', field, None, True)
check('bank-empty-array-fallback', field, [], True)
for label, value in [('object', [bank]), ('null', [None]), ('nested-array', [[]]), ('number', [0])]:
    check('bank-nonempty-array-' + label, field, value, False)
for label, value in [('string', 'bank'), ('number', 42), ('boolean', False)]:
    check('bank-scalar-' + label, field, value, False)
check('bank-empty-object', field, {}, False)
for key in bank:
    incomplete = dict(bank)
    del incomplete[key]
    check('bank-missing-' + key, field, incomplete, False)
    invalid = dict(bank)
    invalid[key] = 42
    check('bank-wrong-type-' + key, field, invalid, False)
check('bank-optional-branch-string', field, bank | {'branch': 'Example Branch'}, True)

passed = sum(r['passed'] for r in results)
report = {'doc_sha256': doc_hash, 'fixture_provenance': 'Reused verified prior controller/profile fixtures; no fresh PHP/HTTP execution.',
          'invariants': invariants, 'cases': results, 'case_count': len(results),
          'passed': passed, 'failed': len(results) - passed, 'schema_evaluations': len(results) * 2,
          'format_checkers_available': ['email', 'uri'], 'dialect': 'JSON Schema 2020-12, no nullable extension'}
(out / 'boundary-results.json').write_text(json.dumps(report, indent=2) + '\n')
print(f'Boundary cases={len(results)}; passed={passed}; failed={len(results) - passed}; schema evaluations={len(results) * 2}')
print(f'Source/contract invariants={len(invariants)}; passed={sum(invariants.values())}')
sys.exit(0 if passed == len(results) and all(invariants.values()) else 1)
