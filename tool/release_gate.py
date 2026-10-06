#!/usr/bin/env python3
import json,sys
from pathlib import Path
from source_identity import identity
root=Path(__file__).resolve().parents[1]
r=json.loads((root/'release-readiness.json').read_text())
required=['automated','business','ios_uat','ios_build','storekit_sandbox','admob_test_device','privacy_store_metadata']
failed=[k for k in required if r.get('checks',{}).get(k,{}).get('status')!='Passed']
if r.get('source_sha256')!=identity()['source_sha256']: failed.append('source identity mismatch')
for key in required:
 check=r.get('checks',{}).get(key,{})
 if check.get('status')=='Passed' and (not check.get('evidence') or not (root/check['evidence']).is_file()): failed.append(key+' missing evidence')
if failed:
 print('Release BLOCKED: '+', '.join(failed));sys.exit(1)
print('Release checks passed for '+r['source_sha256'])
