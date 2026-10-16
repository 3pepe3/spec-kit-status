#!/usr/bin/env python3
"""Read-only native Spec Kit layout and Codex-skills diagnostic."""
import argparse
import json
import os
from pathlib import Path
import re
import sys


def report(root, mode):
    errors=[]
    registry_file=root/'.specify/extensions/.registry'
    try: registry=json.loads(registry_file.read_text()).get('extensions', {})
    except (OSError,ValueError): registry={};errors.append('Missing or invalid extension registry')
    integration_file=root/'.specify/integration.json'
    try: integration=json.loads(integration_file.read_text())
    except (OSError,ValueError): integration={};errors.append('Missing or invalid native integration state')
    selector=os.environ.get('SPECIFY_FEATURE_DIRECTORY')
    pointer=root/'.specify/feature.json'
    if not selector and pointer.is_file():
        try: selector=json.loads(pointer.read_text()).get('feature_directory')
        except (OSError,ValueError): errors.append('Invalid feature pointer')
    active=None
    if selector:
        if Path(selector).is_absolute():
            try:selector=str(Path(selector).relative_to(root/'specs'))
            except ValueError:selector='../outside'
        name=str(selector).removeprefix('specs/')
        candidate=root/'specs'/name
        if not re.fullmatch(r'[0-9]{3}-[A-Za-z0-9-]+',name) or candidate.is_symlink() or candidate.resolve()!=candidate.absolute() or not candidate.is_dir():
            errors.append('Missing or unsafe active feature')
        else: active=name
    features=[]
    for folder in sorted((root/'specs').glob('[0-9][0-9][0-9]-*')):
        if folder.is_symlink() or not folder.is_dir():errors.append('Unsafe feature '+folder.name);continue
        artifacts={name:(folder/name).is_file() and not (folder/name).is_symlink() for name in ('spec.md','plan.md','tasks.md')}
        rows=[];fence=None
        if artifacts['tasks.md']:
            for line in (folder/'tasks.md').read_text().splitlines():
                marker=re.match(r'^\s*(`{3,}|~{3,})',line)
                if marker:
                    if fence is None:fence=marker[1]
                    elif marker[1][0]==fence[0] and len(marker[1])>=len(fence):fence=None
                    continue
                row=re.match(r'^\s*[-*]\s+\[([ xX])\]\s+\S',line)
                if fence is None and row:rows.append(row[1].lower()=='x')
        features.append({'feature':folder.name,'artifacts':artifacts,'tasks':len(rows),'checked':sum(rows),'acceptance':'NOT_ASSESSED'})
    if mode=='doctor':
        for relative in ('.specify/templates','.specify/memory/constitution.md','.specify/scripts/bash'):
            if not (root/relative).exists():errors.append('Missing '+relative)
        for extension in registry.values():
            for command in extension.get('registered_commands',{}).get('codex',[]):
                if not (root/'.agents/skills'/command.replace('.','-')/'SKILL.md').is_file():errors.append('Missing Codex skill '+command)
        for feature in features:
            if not all(feature['artifacts'].values()):errors.append('Incomplete feature '+feature['feature'])
    return {'mode':mode,'active_feature':active,'features':features,'feature_count':len(features),'extensions':sorted(registry),'integration':integration.get('integration'),'status':'FAIL' if errors else 'PASS','errors':errors,'acceptance':'NOT_ASSESSED'}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--json',action='store_true')
    args=parser.parse_args()
    mode=Path(__file__).stem.split('-')[0]
    result=report(Path.cwd().resolve(),mode)
    print(json.dumps(result,sort_keys=True))
    return bool(result['errors'])

if __name__=='__main__':raise SystemExit(main())
