#!/usr/bin/env python3
"""Render the Russian five-world challenge ad without changing the game's project settings."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'publishing/yandex/ads/challenge-ru-horizontal.mp4'

def build(movie, output):
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        'ffmpeg', '-y', '-v', 'warning', '-i', str(movie),
        '-i', str(ROOT / 'assets/audio/music/sunlit_mystery.mp3'),
        '-i', str(ROOT / 'assets/audio/teleport.wav'),
        '-i', str(ROOT / 'assets/audio/complete.wav'),
        '-filter_complex',
        '[0:v]scale=1920:1080:flags=lanczos,setsar=1,tpad=stop_mode=clone:stop_duration=1,trim=duration=15,format=yuv420p[v];'
        '[1:a]atrim=start=35:duration=15,asetpts=PTS-STARTPTS,volume=0.55,afade=t=in:d=0.25,afade=t=out:st=14:d=1[m];'
        '[2:a]asplit=4[s1][s2][s3][s4];[s1]adelay=2350|2350[a1];[s2]adelay=4750|4750[a2];[s3]adelay=7150|7150[a3];[s4]adelay=9550|9550[a4];'
        '[3:a]adelay=11900|11900,volume=0.7[c];'
        '[m][a1][a2][a3][a4][c]amix=inputs=6:normalize=0,alimiter=limit=0.9,apad,atrim=duration=15[a]',
        '-map', '[v]', '-map', '[a]', '-c:v', 'libx264', '-preset', 'medium', '-crf', '19',
        '-r', '30', '-c:a', 'aac', '-b:a', '192k', '-ar', '48000', '-ac', '2',
        '-movflags', '+faststart', str(output)
    ], check=True)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', default='/Applications/Godot.app/Contents/MacOS/Godot')
    parser.add_argument('--movie', type=Path, help='Use an already rendered AVI')
    parser.add_argument('--locale', choices=['ru','en','tr'], default='ru')
    args = parser.parse_args()
    if args.locale != 'ru':
        OUTPUT = ROOT / 'publishing/yandex' / args.locale / OUTPUT.name.replace('-ru-', f'-{args.locale}-')
    if args.movie:
        build(args.movie, OUTPUT)
    else:
        with tempfile.TemporaryDirectory(prefix='pair-up-ad-') as folder:
            project = Path(folder)
            for path in ROOT.iterdir():
                if path.name not in ['project.godot', '.git', 'tmp', 'export']:
                    (project / path.name).symlink_to(path, target_is_directory=path.is_dir())
            config = (ROOT / 'project.godot').read_text()
            config = config.replace('viewport_height=800', 'viewport_height=720')
            (project / 'project.godot').write_text(config)
            movie = project / 'ad.avi'
            subprocess.run([args.godot, '--path', str(project), '--script', 'tools/render_challenge_ad.gd',
                            '--fixed-fps', '30', '--write-movie', str(movie), '--', f'--locale={args.locale}'], check=True)
            build(movie, OUTPUT)
    print(OUTPUT)
