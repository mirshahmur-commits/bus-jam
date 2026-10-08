#!/usr/bin/env python3
"""Identity of app + native config + resolved dependencies, independent of reports."""
import hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def identity():
 h=hashlib.sha256(); names=[]
 # Hash the committed candidate, not local generated/ignored build files.
 tracked=subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().split('\0')
 names=[name for name in tracked if name and (name.split('/')[0] in ['lib','assets','ios','android','web'] or name in ['pubspec.yaml','pubspec.lock'])]
 for name in sorted(names): h.update(name.encode()+b'\0'+(ROOT/name).read_bytes()+b'\0')
 return {'version':'1.1.0+2','source_sha256':h.hexdigest(),'files':len(names),'flutter':'3.47.6'}
if __name__=='__main__': print(json.dumps(identity(),indent=2))
