# AI Collection One-off Task Runbook

## 현재 상태

- 기본 인프라 배포 완료
- ECR Repository 생성 완료
- S3·CloudWatch Logs·IAM·Security Group·Secret 생성 완료
- Docker 이미지 및 ECS Task Definition 준비 대기 중

## 확정된 리소스

- ECS Cluster: `zoop-dev`
- ECR: `zoop-dev-ai-collection`
- S3: `zoop-dev-ai-collection-512138915880`
- CloudWatch Logs: `/ecs/zoop-dev/ai-collection`
- Secret: `zoop-dev/ai/collection`
- Security Group: `sg-0b0c9ecf495a52ffc`

## 기본 인프라 검증

저장소 루트에서 다음 명령을 실행한다.

```powershell
powershell -ExecutionPolicy Bypass -File `
  .\scripts\verify-ai-collection-infra.ps1 `
  -Profile zoop-dev `
  -Region ap-northeast-2
```

## 후속 작성 항목

### 1. Docker 이미지 빌드 및 ECR Push
미확정

### 2. Secret 등록
예정 키:
- `DEEPSEEK_API_KEY`
- `OPENDART_API_KEY`

실제 실행 모드에 따라 최종 확정한다.

### 3. ECS Task Definition
미확정

초기 후보:
- CPU: 1024
- Memory: 2048 MiB
- Ephemeral storage: 50 GiB
- Stop timeout: 120초

### 4. 수동 RunTask 실행
Task Definition 확정 후 작성

### 5. CloudWatch 로그 확인
Task Definition 확정 후 작성

### 6. ECS Exec 점검
Task Definition 확정 후 작성

### 7. 체크포인트 저장·복원
AI 런타임 구현 후 작성

### 8. 정상 종료 확인
신규 접수 중단 → drain → 체크포인트 저장 → 종료

### 9. 장애 재실행 기준
체크포인트 계약 확정 후 작성

### 10. 비용 및 종료 확인
- 실행 중 Task 수 확인
- 종료 후 Running/Pending Task가 0인지 확인
- 불필요한 이미지와 로그 보존 상태 확인
