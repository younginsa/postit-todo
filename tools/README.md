# 구깃 배포 도구

App Store Connect API를 CLI에서 쓰는 스크립트. **인증 파일은 저장소에 없고** 로컬에만 둔다:

```
~/.appstoreconnect/asc_config.json          # {"keyId":"...","issuerId":"..."}  (ASC → 사용자 및 액세스 → 통합 에서 발급)
~/.appstoreconnect/private_keys/AuthKey_<keyId>.p8
```

## asc.swift — 범용 API 호출

```bash
swift tools/asc.swift GET "/v1/apps/<appId>/appStoreVersions?limit=2"
swift tools/asc.swift POST "/v1/appStoreVersions" body.json
swift tools/asc.swift PATCH "/v1/..." body.json
```

## asc_media.swift — 스크린샷/프리뷰 업로드

```bash
# <localizationId>의 스크린샷 세트에 파일들을 순서대로 업로드
swift tools/asc_media.swift screenshot <localizationId> APP_IPHONE_67 1.png 2.png ...
```

## 배포 파이프라인 (요약)

1. 버전/빌드 번호 올리기 (xcodeproj gem으로 in-place 수정 — gen_project.rb 재실행 금지, 서명 초기화됨)
2. `xcodebuild archive` → `xcodebuild -exportArchive` (수동 서명 프로파일) → `xcrun altool --upload-app`
3. asc.swift로: 버전 생성 → What's New → 빌드 첨부 → reviewSubmission 생성·제출
4. 주의: What's New와 설명엔 이모지·✓·☰ 문자 불가 (409)
