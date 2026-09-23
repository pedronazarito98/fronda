#!/usr/bin/env python3
from pathlib import Path
import shutil
import sys
root = Path(__file__).resolve().parent.parent
output = Path(sys.argv[1]) / 'Contents/Resources/ThirdPartyNotices'
output.mkdir(parents=True, exist_ok=True)
for source in (root / 'Vendor/CTreeSitter').rglob('*'):
    if source.is_file() and (source.name.lower().startswith('license') or source.name == 'manifest.json'):
        relative = source.relative_to(root / 'Vendor/CTreeSitter')
        target = output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
