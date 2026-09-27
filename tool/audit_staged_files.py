"""Audit the Git index before publishing. Reports paths, never secret values.

Run from the repository root with Python 3. This is a defense in addition to
human diff review, not proof that every possible secret pattern is detectable.
"""
import json
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parent.parent
paths = subprocess.check_output(
    ['git', 'diff', '--cached', '--name-only', '--diff-filter=ACMR', '-z'], cwd=root
).decode('utf-8').split('\0')
private_values = []
for config in (root / 'config').glob('*.local.json'):
    for key, value in json.loads(config.read_text(encoding='utf-8')).items():
        if key != 'API_URL' and isinstance(value, str) and len(value) >= 6:
            # A username can legitimately be part of the public server hostname.
            private_values.append((value if any(part in key for part in ('PASSWORD', 'TOKEN', 'SECRET')) else json.dumps(value)).encode('utf-8'))

patterns = [
    rb'-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----',
    rb'gh[pousr]_[A-Za-z0-9]{20,}',
    rb'github_pat_[A-Za-z0-9_]{20,}',
    rb'AKIA[0-9A-Z]{16}',
    rb'xox[baprs]-[A-Za-z0-9-]{20,}',
    rb'"--dart-define=AUTH_PREFILL_PASSWORD=[^"\r\n]{4,}"',
]
failures = []
checked = 0
for name in filter(None, paths):
    path = pathlib.PurePosixPath(name)
    if (name.endswith('.local.json') or path.name in {'.env', 'key.properties', 'local.properties'}
            or path.suffix in {'.jks', '.keystore', '.p12', '.pfx', '.pem', '.db', '.sqlite', '.apk', '.aab'}
            or set(path.parts) & {'build', '.dart_tool', '.gradle', '.idea'}):
        failures.append((name, 'private or generated path'))
        continue
    data = subprocess.check_output(['git', 'show', ':' + name], cwd=root)
    if any(re.search(pattern, data) for pattern in patterns):
        failures.append((name, 'credential pattern'))
    if any(value in data for value in private_values):
        failures.append((name, 'local credential value'))
    checked += 1
for name, reason in failures:
    print(f'REJECT {name}: {reason}')
print(f'Audited {checked} staged files; {len(failures)} findings.')
sys.exit(bool(failures))
