#!/usr/bin/env python3
"""Identity of app + native config + resolved dependencies, independent of reports."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def identity():
 h=hashlib.sha256(); names=[]
 for folder in ['lib','assets','ios','android','web']:
  for p in (ROOT/folder).rglob('*'):
   if not p.is_file() or any(x in p.parts for x in ['Pods','.symlinks','build','ephemeral','.gradle']): continue
   if p.name in ['Generated.xcconfig','flutter_export_environment.sh','local.properties','GeneratedPluginRegistrant.h','GeneratedPluginRegistrant.m','GeneratedPluginRegistrant.java']: continue
   names.append(p.relative_to(ROOT).as_posix())
 names+=['pubspec.yaml','pubspec.lock']
 for name in sorted(names): h.update(name.encode()+b'\0'+(ROOT/name).read_bytes()+b'\0')
 return {'version':'1.0.0+1','source_sha256':h.hexdigest(),'files':len(names),'flutter':'3.47.6'}
if __name__=='__main__': print(json.dumps(identity(),indent=2))
