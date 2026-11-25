# Red Dead Redemption 2 · Sikarugir for macOS

기존 Sikarugir 앱을 **Red Dead Redemption 2.app**으로 설정하는 macOS용 셸 스크립트입니다. 완성된 앱을 열면 Windows용 Steam이 게임 ID `1174180`으로 레데리 2를 실행합니다. Steam이 게임 프로세스를 추적하므로 플레이 시간이 Steam 라이브러리에 기록됩니다.

## 실행

Apple Silicon Mac, Python 3, D3DMetal이 포함된 **초기화된 Sikarugir 11 래퍼**가 필요합니다. Windows용 Steam은 래퍼 안의 기본 위치에, 게임은 해당 Steam의 기본 라이브러리에 설치하는 구성을 지원합니다. 앱 이름 변경과 기존 경로 연결은 APFS에서 테스트했습니다. 여러 게임이 들어 있는 래퍼를 지정하면 그 래퍼의 이름과 기본 실행 게임이 바뀝니다.

```bash
git clone https://github.com/KusBeoms/rdr2-sikarugir-setup.git
cd rdr2-sikarugir-setup
./setup-rdr2.sh --check
./setup-rdr2.sh
```

기본 이름인 `Steam_windows.app` 또는 `Red Dead Redemption 2.app`을 자동 탐색합니다. 다른 이름을 쓰거나 여러 앱이 발견되면 `--app` 뒤에 실제 앱 경로를 넣으세요. 터미널에 앱을 드래그해도 됩니다.

```bash
./setup-rdr2.sh --app "/Volumes/Games/Applications/My Steam.app"
```

1. **Steam 설치 전**이라면 Windows용 `SteamSetup.exe`를 다운로드 폴더에 두고 실행하세요. 스크립트가 설치 마법사를 엽니다. 설치와 로그인을 마치고 같은 명령을 다시 실행하세요. 다른 위치의 설치 파일은 `--installer "/경로/SteamSetup.exe"`로 지정할 수 있습니다. [Steam 공식 다운로드](https://store.steampowered.com/about/)
2. **게임 설치 전**이라면 스크립트가 Steam에 RDR2 설치를 요청합니다. 게임을 소유한 계정에서 설치를 진행하고 다운로드가 끝나면 같은 명령을 한 번 더 실행하세요. [RDR2 Steam 페이지](https://store.steampowered.com/app/1174180/Red_Dead_Redemption_2/)
3. **설치가 끝나면** 원래 앱과 같은 폴더에 있는 **Red Dead Redemption 2.app**을 여세요. 첫 실행에는 Rockstar 로그인이나 계정 연결이 필요할 수 있습니다. 이후 로그인 세션이 유지되면 Steam 라이브러리를 조작할 필요 없이 게임이 실행됩니다. 기존 경로에는 숨김 심볼릭 링크가 남아 이전 바로가기도 사용할 수 있습니다.

## 그래픽, 글꼴, 한국어

- 래퍼의 D3DMetal을 켭니다. 게임 설정 파일이 없는 경우 DirectX 12와 1280×720 창 모드를 기본값으로 작성합니다. 이미 게임에서 조정한 `system.xml`은 보존합니다. 기존 설정으로 그래픽 초기화가 실패하면 Rockstar 안내에 따라 API를 확인하세요. [Rockstar 그래픽 설정](https://support.rockstargames.com/articles/2MQafAtBWiOUJrPDLx5I2U/err-gfx-init-error-when-launching-red-dead-redemption-2-on-pc)
- 맥에 `Arial Unicode.ttf`가 있으면 래퍼의 Windows 글꼴 폴더에 복사하고 한·중·일 문자를 위한 대체 글꼴을 등록합니다. 이미 열린 런처에서 글자가 네모로 보이면 런처를 종료하고 다시 여세요.
- 게임을 한국어로 바꾸려면 Windows용 Steam에서 **라이브러리 → Red Dead Redemption 2 → 속성 → 언어 → 한국어**를 선택하세요. 일반 탭 안에 언어 메뉴가 표시될 수 있습니다. 메뉴와 자막이 한국어로 표시되고 음성은 영어입니다. [Rockstar 언어 설정](https://support.rockstargames.com/articles/6ZSsAaVCIBrg5m6Ovc5EDe/how-to-change-the-language-in-red-dead-redemption-2)
- 앱 아이콘은 로컬 Steam의 공식 게임 아이콘을 사용합니다. 해당 파일이 없으면 캐시된 공식 라이브러리 표지를 사용합니다. 둘 다 없다면 Steam에서 레데리 2의 라이브러리 페이지를 열어 이미지를 불러온 뒤 다시 실행하세요.

## 확인

`./setup-rdr2.sh --check`로 앱 이름, 아이콘 파일명, Steam과 게임의 설치 상태, 그래픽 설정, 실행 인수를 확인할 수 있습니다. 최종 실행 인수는 `-silent -applaunch 1174180`입니다. 게임을 실행한 뒤 Steam 폴더의 `logs/gameprocess_log.txt`에 `AppID 1174180`, `tracked process`, `RDR2.exe`가 함께 표시되면 Steam이 게임을 추적하고 있습니다.

이 도구는 개인용 비공식 설정 도구입니다. 게임, 글꼴, Steam 설치 파일, 계정 정보는 각 사용자의 컴퓨터에서 가져옵니다. [Sikarugir 프로젝트](https://github.com/Sikarugir-App/Sikarugir)
