# 구깃 마케팅 템플릿

브랜드 톤 (v1.5 민트 하늘): `linear-gradient(160deg, #B9E6F8 0%, #CDF3E3 52%, #DDE7FA 100%)` + 네온그린 별가루 `#8CFFB8`
잉크 `#3A352F` · 캔버스 `#F5F2EB` · 종이 6색: `#F5DEA8 #F4D2D4 #CCDFC7 #D2E0E4 #EDC79B #E6DCEF`

## 파일

| 파일 | 용도 | 렌더 크기 |
|---|---|---|
| store_shot_ko.html | 앱스토어 스크린샷 (한국어) `?t=hero\|combo\|widget\|del\|filter&f=pretendard` | 1320×2868 |
| store_shot_en.html | 앱스토어 스크린샷 (영어) 파라미터 동일 | 1320×2868 |
| store_shot_widget.html | 위젯 소개 스크린샷 `?l=ko\|en` | 1320×2868 |
| app_icon_blue.html | 앱 아이콘 | 1024×1024 |
| homepage_card.html | 홈페이지 썸네일 (미니멀) | 1600×1200 |
| plus_feature_mock.html | 구깃 플러스 (꾸미기) 화면 시안 | 2960×2150 |
| widget_sticker_mock.html | 스티커 붙은 위젯 시안 | 1240×1240 |
| brand_tone_board.html | 블루 리브랜딩 톤 비교 보드 | 3180×1560 |

## 렌더 방법 (headless Chrome)

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless \
  --screenshot=out.png --window-size=1320,2868 --hide-scrollbars \
  --default-background-color=FFFFFFFF --virtual-time-budget=6000 \
  "file:///절대경로/store_shot_ko.html?t=hero&f=pretendard"
```

- 앱 아이콘은 알파 채널이 있으면 앱스토어에서 거부됨 → `--default-background-color=FFFFFFFF` 필수
- combo/del/filter 타입은 시뮬레이터 원본 스크린샷(`/tmp/googit_shot_{ko,en}_*.png`)을 참조함 — 없으면 앱을 시뮬레이터에서 띄워 다시 캡처 필요 (임시 SHOT_SEED 코드, git 히스토리 2026-07-15 참고)

## 에셋 제작 (Figma)

- 스티커: 240×240 프레임, 투명 배경, 그림은 가운데 ~200px, 이름 `sticker/이름`
- 속지 타일: 96×96 프레임, 투명 배경, 무늬만 (잉크톤 10~16% 투명도), 이름 `paper/이름`
- 팔레트: 팩당 6색 (hex 6개면 충분)
- 위젯에서 30pt까지 작아지므로 굵고 단순한 형태 권장
