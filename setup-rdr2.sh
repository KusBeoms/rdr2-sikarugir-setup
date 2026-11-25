#!/bin/bash
# Configure an existing Sikarugir Steam wrapper for Red Dead Redemption 2.
set -euo pipefail

usage() {
  cat <<'USAGE'
사용법: ./setup-rdr2.sh [--app "/경로/Steam_windows.app"] [--installer "/경로/SteamSetup.exe"] [--check]
  --app        기존 Sikarugir 앱. 생략하면 Applications와 외장 볼륨에서 자동 탐색합니다.
  --installer  Windows Steam 설치 파일. 기본 위치는 ~/Downloads/SteamSetup.exe 입니다.
  --check      설치 상태와 설정을 읽기만 합니다.
  --help       사용법을 표시합니다.
USAGE
}
fail() { printf '오류: %s\n' "$*" >&2; exit 1; }
app=
installer="$HOME/Downloads/SteamSetup.exe"
check=0
while (($#)); do
  case "$1" in
    --app|--installer)
      (($# >= 2)) || fail "$1 뒤에 경로를 입력하세요."
      case "$1" in --app) app=$2 ;; --installer) installer=$2 ;; esac
      shift 2 ;;
    --check) check=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; fail "알 수 없는 옵션: $1" ;;
  esac
done
[[ $(uname -s) == Darwin ]] || fail 'macOS에서 실행하세요.'
if [[ -z $app ]]; then
  for dir in /Applications "$HOME/Applications" "$HOME/Applications/Sikarugir" /Volumes/*/Applications; do
    for name in 'Red Dead Redemption 2.app' Steam_windows.app; do
      candidate="$dir/$name"
      [[ -x "$candidate/Contents/MacOS/Sikarugir" ]] || continue
      if [[ -n $app && ! "$candidate" -ef "$app" ]]; then fail '앱이 여러 개입니다. --app으로 선택하세요.'; fi
      app=$candidate
    done
  done
fi
[[ -n $app && -d $app ]] || fail '기존 Sikarugir 앱을 찾지 못했습니다. --app으로 지정하세요.'
app=$(cd -P -- "$app" && pwd -P)
name='Red Dead Redemption 2'
target="$(dirname "$app")/$name.app"
contents="$app/Contents"
launcher="$contents/MacOS/launcher"
plist="$contents/Info.plist"
cdrive="$contents/SharedSupport/prefix/drive_c"
steamdir="$cdrive/Program Files (x86)/Steam"
steam="$steamdir/steam.exe"
gameid=1174180
manifest="$steamdir/steamapps/appmanifest_${gameid}.acf"
game="$steamdir/steamapps/common/$name/RDR2.exe"
[[ -x "$contents/MacOS/Sikarugir" && -x $launcher && -f $plist && -d $cdrive/windows ]] || fail '초기화된 Sikarugir 래퍼가 필요합니다.'
game_ready() {
  [[ -s $game && -f $manifest ]] &&
    awk -F'"' '$2=="StateFlags" { if (int($4/4)%2) installed=1 } END { exit !installed }' "$manifest"
}
read_setting() { /usr/bin/plutil -extract "$1" raw "$plist" 2>/dev/null || true; }
status() {
  printf '앱: %s\n앱 이름: %s\n아이콘: %s\n실행 대상: %s %s\nD3DMetal: %s\n' \
    "$app" "$(read_setting CFBundleDisplayName)" "$(read_setting CFBundleIconFile)" \
    "$(read_setting 'Program Name and Path')" "$(read_setting 'Program Flags')" "$(read_setting D3DMETAL)"
  if [[ -s $steam ]]; then echo 'Windows Steam: 설치됨'; else echo 'Windows Steam: 설치 필요'; fi
  if game_ready; then echo 'RDR2: 설치됨'; else echo 'RDR2: 설치 대기 또는 다운로드 중'; fi
}
if ((check)); then status; exit 0; fi
if [[ ! $app -ef $target && ( -e $target || -L $target ) ]]; then fail "대상 이름이 이미 사용 중입니다: $target"; fi
[[ $(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null) == 1 ]] || fail 'D3DMetal을 지원하는 Apple Silicon Mac이 필요합니다.'
[[ -f "$contents/SharedSupport/renderer/d3dmetal/wine/x86_64-windows/d3d12.dll" ]] || fail '래퍼에 D3DMetal이 없습니다.'
command -v python3 >/dev/null || fail 'Python 3가 필요합니다.'
python3 -c 'import plistlib, pathlib' || fail '사용 가능한 Python 3가 필요합니다.'
if [[ ! -s $steam ]]; then
  [[ -f $installer ]] || fail "Windows Steam 설치 파일을 --installer로 지정하세요: $installer"
  installer="$(cd -P -- "$(dirname "$installer")" && pwd -P)/$(basename "$installer")"
  echo 'Steam 설치 마법사를 엽니다. 설치와 로그인을 마친 뒤 같은 명령을 다시 실행하세요.'
  "$launcher" WSS-installer "$installer" </dev/null >/dev/null 2>&1 &
  exit 0
fi

# Use the wrapper to import fonts into the live registry (editing .reg databases on disk would race Wine).
tmp=$(mktemp -d "${TMPDIR:-/tmp}/rdr2-setup.XXXXXXXX")
job=
cleanup() {
  [[ -z $job ]] || /bin/rm -rf -- "$job"
  /bin/rm -rf -- "$tmp"
}
trap cleanup EXIT
font='/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
if [[ -r $font ]]; then
  fonts="$cdrive/windows/Fonts"
  [[ -d $fonts ]] || mkdir -p "$fonts"
  if [[ ! -e "$fonts/Arial Unicode.ttf" ]]; then
    cp -n "$font" "$fonts/Arial Unicode.ttf"
  fi
  job=$(mktemp -d "$cdrive/rdr2-fonts.XXXXXXXX")
  # Update only absent fallback mappings. Use reg.exe so an active wineserver sees the change.
  python3 - "$contents" "$job" "$(read_setting WINEMSYNC)" <<'PY'
import os, subprocess, sys
from pathlib import Path
contents, job = map(Path, sys.argv[1:3])
engine = contents / 'SharedSupport/wine'
wine = engine / 'bin/wine'
libraries = [engine/'lib', engine/'lib64', contents/'Frameworks',
             contents/'Frameworks/GStreamer.framework/Libraries']
env = dict(os.environ, WINEPREFIX=str(contents/'SharedSupport/prefix'), CX_ROOT=str(engine),
           SikarugirAppWine11='1', WINEMSYNC=sys.argv[3], WINEDEBUG='-all',
           DYLD_FALLBACK_LIBRARY_PATH=':'.join(map(str, libraries)) + ':/usr/lib:/usr/libexec:/usr/lib/system')
def reg(*args):
    result = subprocess.run([wine, 'reg.exe', *args], env=env, stdout=subprocess.PIPE,
                            timeout=75, check=True)
    return result.stdout.decode('ascii', 'replace')

base = r'Software\Microsoft\Windows NT\CurrentVersion'
keys = ('Fonts', 'FontSubstitutes', r'FontLink\SystemLink')
existing = {}
for key in keys:
    output = reg('query', 'HKLM\\' + base + '\\' + key)
    existing[key] = {line.split('    REG_', 1)[0].strip().casefold()
                     for line in output.splitlines() if '    REG_' in line}
lines = ['Windows Registry Editor Version 5.00']
def section(key):
    lines.extend(['', '[HKEY_LOCAL_MACHINE\\' + base + '\\' + key + ']'])
family = 'Arial Unicode MS'
section(keys[0])
lines.append('"Arial Unicode MS (TrueType)"="Arial Unicode.ttf"')
section(keys[1])
for face in ('Malgun Gothic', 'Gulim', 'Dotum', 'Meiryo', 'MS UI Gothic', 'Yu Gothic UI',
             'Microsoft YaHei', 'Microsoft YaHei UI', 'Microsoft JhengHei', 'Microsoft JhengHei UI',
             'SimSun', 'PMingLiU'):
    if face.casefold() not in existing[keys[1]] and (face+' (TrueType)').casefold() not in existing[keys[0]]:
        lines.append(f'"{face}"="{family}"')
section(keys[2])
multi = ('Arial Unicode.ttf,' + family + '\0\0').encode('utf-16le')
for face in ('Arial', 'Segoe UI', 'Segoe UI Bold', 'Segoe UI Semibold', 'Verdana', 'Helvetica', 'Liberation Sans'):
    if face.casefold() not in existing[keys[2]]:
        lines.append(f'"{face}"=hex(7):' + ','.join(f'{b:02x}' for b in multi))
(job/'fonts.reg').write_bytes(('\r\n'.join(lines)+'\r\n').encode('utf-16'))
reg('import', 'C:\\' + job.name + r'\fonts.reg')
if 'Arial Unicode.ttf' not in reg('query', 'HKLM\\'+base+r'\Fonts', '/v', family+' (TrueType)'):
    sys.exit('Wine 글꼴 등록 결과를 확인하지 못했습니다.')
PY
  /bin/rm -rf -- "$job"; job=
else
  echo 'Arial Unicode.ttf를 찾지 못해 한·중·일 대체 글꼴 단계는 건너뜁니다.' >&2
fi

# Sikarugir normally maps the active Wine user's Documents folder to macOS Documents.
wineuser=$(id -un)
docs="$cdrive/users/$wineuser/Documents"
if [[ ! -d $docs ]]; then docs="$cdrive/users/Sikarugir/Documents"; fi
[[ -d $docs ]] || fail '래퍼의 Windows 사용자 Documents 폴더를 찾지 못했습니다.'
settings="$docs/Rockstar Games/$name/Settings/system.xml"
mkdir -p "$(dirname "$settings")"
if [[ ! -e $settings ]]; then
  (set -C; cat > "$settings" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<rage__fwuiSystemSettingsCollection>
  <version value="37"/>
  <configSource>kSettingsConfig_Manual</configSource>
  <graphics>
    <textureQuality>kSettingLevel_Medium</textureQuality>
    <shadowQuality>kSettingLevel_Low</shadowQuality>
    <reflectionQuality>kSettingLevel_Low</reflectionQuality>
    <volumetricsQuality>kSettingLevel_Low</volumetricsQuality>
    <waterQuality>kSettingLevel_Medium</waterQuality>
    <lightingQuality>kSettingLevel_Medium</lightingQuality>
    <taa>kSettingLevel_Medium</taa><msaa value="0"/>
  </graphics>
  <advancedGraphics><API>kSettingAPI_DX12</API></advancedGraphics>
  <video>
    <screenWidth value="1280"/><screenHeight value="720"/>
    <screenWidthWindowed value="1280"/><screenHeightWindowed value="720"/>
    <windowed value="1"/><vSync value="1"/>
  </video>
</rage__fwuiSystemSettingsCollection>
XML
  )
fi

if ! game_ready; then
  /usr/bin/plutil -replace D3DMETAL -integer 1 "$plist"
  echo 'Steam에서 RDR2 설치 화면을 엽니다. 다운로드가 끝나면 같은 명령을 다시 실행하세요.'
  /usr/bin/plutil -replace 'Program Name and Path' -string '/Program Files (x86)/Steam/steam.exe' "$plist"
  /usr/bin/plutil -replace 'Program Flags' -string "steam://install/$gameid" "$plist"
  "$launcher" </dev/null >/dev/null 2>&1 &
  exit 0
fi

cache="$steamdir/appcache/librarycache/$gameid"
ico="$steamdir/steam/games/5bf6edd7efb1110b457da905e7ac696c6c619ed1.ico"
iconfile=RedDeadRedemption2.icns
icon="$contents/Resources/$iconfile"
if [[ ! -s $icon ]]; then
  # Extract the largest embedded PNG from the official game icon already installed by Steam.
  if ! python3 - "$ico" "$tmp/art.png" <<'PY'
import struct, sys
from pathlib import Path
src, dest = map(Path, sys.argv[1:])
if not src.is_file():
    sys.exit(1)
data = src.read_bytes()
if data[:4] != b'\x00\x00\x01\x00' or len(data) < 6:
    sys.exit(1)
images = []
for entry in range(int.from_bytes(data[4:6], 'little')):
    offset = 6 + 16 * entry
    if offset + 16 > len(data):
        break
    w, h, _, _, _, depth, size, start = struct.unpack_from('<BBBBHHII', data, offset)
    blob = data[start:start + size]
    if blob.startswith(b'\x89PNG\r\n\x1a\n') and len(blob) == size:
        images.append(((w or 256) * (h or 256), depth, size, blob))
if not images:
    sys.exit(1)
dest.write_bytes(max(images)[-1])
PY
  then
    cover="$cache/library_600x900.jpg"
    [[ -f $cover ]] || fail 'Steam 공식 아이콘과 표지를 찾지 못했습니다. 라이브러리에서 게임 페이지를 연 뒤 다시 실행하세요.'
    /usr/bin/sips -s format png "$cover" --out "$tmp/cover.png" >/dev/null
    height=$(/usr/bin/sips -g pixelHeight "$tmp/cover.png" | awk '/pixelHeight:/ {print $2}')
    /usr/bin/sips -p "$height" "$height" --padColor 171717 "$tmp/cover.png" --out "$tmp/art.png" >/dev/null
  fi
  iconset="$tmp/Game.iconset"; mkdir "$iconset"
  for n in 16 32 128 256 512; do
    /usr/bin/sips -z "$n" "$n" "$tmp/art.png" --out "$iconset/icon_${n}x${n}.png" >/dev/null
    /usr/bin/sips -z "$((2*n))" "$((2*n))" "$tmp/art.png" --out "$iconset/icon_${n}x${n}@2x.png" >/dev/null
  done
  /usr/bin/iconutil -c icns "$iconset" -o "$tmp/$iconfile"
  cp "$tmp/$iconfile" "$icon"
fi

# One plist replacement; rename atomically so a running Wine prefix keeps its old path.
python3 - "$app" "$target" "$iconfile" <<'PY'
import ctypes, os, plistlib, stat, sys, tempfile
from pathlib import Path
app, target = map(Path, sys.argv[1:3])
plist = app / 'Contents/Info.plist'
data = plist.read_bytes()
config = plistlib.loads(data)
desired = {'CFBundleName': target.stem, 'CFBundleDisplayName': target.stem,
           'CFBundleIconFile': sys.argv[3], 'D3DMETAL': 1,
           'Program Name and Path': '/Program Files (x86)/Steam/steam.exe',
           'Program Flags': '-silent -applaunch 1174180'}
if any(config.get(k) != v for k, v in desired.items()):
    config.update(desired)
    with tempfile.NamedTemporaryFile(dir=plist.parent, delete=False) as out:
        temp = Path(out.name)
        try:
            os.fchmod(out.fileno(), stat.S_IMODE(plist.stat().st_mode))
            fmt = plistlib.FMT_BINARY if data.startswith(b'bplist') else plistlib.FMT_XML
            plistlib.dump(config, out, fmt=fmt, sort_keys=False)
            out.flush()
            os.replace(temp, plist)
        finally:
            if temp.exists():
                temp.unlink()
if app != target:
    swap = ctypes.CDLL('/usr/lib/libSystem.B.dylib', use_errno=True).renamex_np
    swap.argtypes = (ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint)
    target.symlink_to(target.name)
    try:
        os.lchflags(target, stat.UF_HIDDEN)
        if swap(os.fsencode(app), os.fsencode(target), 2):  # RENAME_SWAP on APFS
            code = ctypes.get_errno()
            raise OSError(code, os.strerror(code))
    finally:
        if target.is_symlink() and os.readlink(target) == target.name:
            target.unlink()
os.utime(target, None)
PY
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
if [[ -x $lsregister ]]; then "$lsregister" -f "$target" || echo 'Finder 등록은 앱을 처음 열 때 갱신됩니다.' >&2; fi
printf '준비 완료: %s\n이 앱을 열면 Steam을 통해 RDR2를 실행합니다.\n' "$target"
echo '게임 한국어: Steam 라이브러리 → Red Dead Redemption 2 → 속성 → 언어 → 한국어.'
