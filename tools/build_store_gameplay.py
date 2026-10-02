#!/usr/bin/env python3
"""Build clean gameplay store videos and screenshots from the actual game UI."""
from pathlib import Path
import argparse
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--locale', choices=['ru','en','tr','pt','es','de','fr'], default='ru')
args = parser.parse_args()
OUT = ROOT / ('publishing/yandex/store-refresh' if args.locale == 'ru' else f'publishing/yandex/{args.locale}')
OUT.mkdir(parents=True, exist_ok=True)
for portrait in [False, True]:
    name = 'portrait' if portrait else 'landscape'
    with tempfile.TemporaryDirectory(prefix='pair-store-') as folder:
        project = Path(folder)
        for path in ROOT.iterdir():
            if path.name not in ['project.godot','.git','tmp','export']:
                (project/path.name).symlink_to(path, target_is_directory=path.is_dir())
        config = (ROOT/'project.godot').read_text()
        config = config.replace('viewport_width=1280', f'viewport_width={720 if portrait else 1280}')
        config = config.replace('viewport_height=800', f'viewport_height={1280 if portrait else 720}')
        # Keep any incidental capture-session settings/cloud migration away from real saves.
        config = config.replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="PairUpStoreCapture"')
        (project/'project.godot').write_text(config)
        movie = project/'capture.avi'
        cmd = ['/Applications/Godot.app/Contents/MacOS/Godot','--path',str(project),'--script','tools/capture_store_gameplay.gd',
               '--fixed-fps','30','--write-movie',str(movie),'--',f'--output={OUT}',f'--locale={args.locale}']
        if portrait: cmd.append('--portrait')
        subprocess.run(cmd,check=True)
        # Remove each scene's intro/layout preparation; keep four gameplay segments.
        filters=[]
        for i in range(4):
            start=1 + i*175/30
            filters.append(f'[0:v]trim=start={start}:duration=4.2,setpts=PTS-STARTPTS[v{i}]')
        filters.append('[v0][v1][v2][v3]concat=n=4:v=1:a=0,setsar=1,fps=30,format=yuv420p[v]')
        filters.append('[1:a]atrim=duration=16.8,asetpts=PTS-STARTPTS,volume=0.5,afade=t=in:d=0.3,afade=t=out:st=15.8:d=1[a]')
        subprocess.run(['ffmpeg','-v','warning','-y','-i',str(movie),'-i',str(ROOT/'assets/audio/music/rippling_arpeggios.mp3'),
                        '-filter_complex',';'.join(filters),'-map','[v]','-map','[a]','-c:v','libx264','-crf','19','-preset','medium',
                        '-r','30','-c:a','aac','-b:a','160k','-movflags','+faststart',str(OUT/f'gameplay-{name}.mp4')],check=True)
print(OUT)
