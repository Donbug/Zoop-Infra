# ZOOP Dev 환경 배포 및 롤백 Runbook

## 1. 문서 정보

| 항목 | 내용 |
|---|---|
| 문서 목적 | ZOOP Dev 인프라 및 애플리케이션의 안전한 배포·검증·롤백 절차 정의 |
| 담당자 | 안재현 |
| 대상 환경 | AWS Dev |
| AWS 리전 | `ap-northeast-2` |
| 관련 WBS | WBS 6.11.2, WBS 6.11.8 |
| 관련 이슈 | Zoop-Infra #40, Zoop-Infra #41 |
| 최종 수정일 | 2026-10-16 |

---

## 2. 현재 진행 상태

| 작업 | 상태 | 비고 |
|---|---|---|
| Terraform CI | 완료 | `bootstrap`, `dev`의 `fmt → init -backend=false → validate` 자동화 |
| Dev 인프라 사전 구성 | 완료 | RDS, Valkey, Neo4j, ECS 비용·보안 검토 |
| GitHub OIDC 및 배포 역할 | 완료 | 장기 AWS Access Key 없이 GitHub Actions에서 AWS 역할 사용 |
| 로컬 PostgreSQL 검증 | 완료 | PostgreSQL 16.13-alpine Health Check 정상 |
| Company 통합 테스트 | 완료 | `companyIntegrationTest` 성공 |
| Auth 통합 테스트 | 완료 | `authIntegrationTest` 성공 |
| Dev Terraform Plan | 완료 | 신규 Dev Backend 연결 및 빈 State 확인 |
| 실제 Dev 인프라 배포 | 보류 | 프론트엔드·백엔드 작업 완료 후 진행 |
| API Docker/ECR/ECS 배포 | 보류 | 애플리케이션과 배포 워크플로 확정 후 진행 |

> 현재는 실제 AWS 리소스를 배포하지 않는다.
> 프론트엔드·백엔드·AI 애플리케이션의 배포 준비가 완료되고 팀 승인을 받은 뒤 본 Runbook에 따라 배포한다.

---

## 3. 배포 대상

### 3.1 Terraform 구성

- `bootstrap`
  - Terraform State 저장소
  - State Lock 구성
  - GitHub Actions OIDC Provider
  - GitHub Actions 배포 역할 및 최소 권한 정책

- `dev`
  - VPC 및 Subnet
  - Security Group
  - Amazon RDS for PostgreSQL 및 pgvector
  - Amazon ElastiCache for Valkey
  - Neo4j EC2 및 EBS gp3
  - Amazon ECR
  - Amazon ECS Fargate
  - Application Load Balancer
  - CloudWatch Logs
  - Secrets Manager

### 3.2 애플리케이션 구성

- API: Spring Boot
- AI: FastAPI 또는 확정된 AI 서비스
- Container Registry: Amazon ECR
- Container Runtime: Amazon ECS Fargate
- Database: PostgreSQL 및 pgvector
- Cache: Valkey
- Graph Database: Neo4j

---

## 4. 배포 원칙

1. 모든 변경은 Pull Request 리뷰와 CI 통과 후 `main`에 반영한다.
2. Terraform Plan 결과를 확인하지 않고 Apply하지 않는다.
3. 실제 비밀번호, API Key, Token은 Git 또는 문서에 기록하지 않는다.
4. Secrets Manager의 Secret 값은 터미널이나 GitHub Actions 로그에 출력하지 않는다.
5. 운영 중인 AWS 리소스에 `terraform destroy`를 실행하지 않는다.
6. DB 마이그레이션은 애플리케이션 버전과 호환성을 확인한 후 진행한다.
7. 장애 발생 시 원인 파악보다 서비스 복구를 우선하고, 이후 로그와 증적을 보존한다.

---

## 5. 사전 준비 사항

### 5.1 필수 도구

배포 작업 PC 또는 GitHub Actions에 다음 도구가 준비되어 있어야 한다.

- Git
- Terraform
- AWS CLI
- Docker
- Java 21
- Gradle Wrapper

버전을 확인한다.

```powershell
git --version
terraform version
aws --version
docker version
java -version
```

### 5.2 저장소 최신화

```powershell
cd C:\Zoop\Infra\Zoop-Infra
git switch main
git pull --ff-only origin main
git status -sb
```

예상 상태:

```text
## main...origin/main
```

로컬 변경 사항이 있다면 임의로 삭제하거나 덮어쓰지 말고 변경 내용을 먼저 확인한다.

### 5.3 AWS 인증 확인

```powershell
aws sts get-caller-identity
aws configure get region
```

확인 사항:

- 올바른 AWS Account인지 확인
- 사용 리전이 `ap-northeast-2`인지 확인
- 배포에 사용할 IAM Role인지 확인
- 개인 Access Key가 저장소 또는 로그에 노출되지 않았는지 확인

GitHub Actions 배포 시에는 OIDC를 통해 배포 역할을 Assume하는지 확인한다.

### 5.4 애플리케이션 준비 확인

다음 조건이 모두 충족되기 전에는 실제 배포를 진행하지 않는다.

- [ ] 백엔드 배포 대상 Commit 확정
- [ ] AI 서비스 배포 대상 Commit 확정
- [ ] API Dockerfile 리뷰 및 Merge 완료
- [ ] AI Dockerfile 리뷰 및 Merge 완료
- [ ] ECR/ECS 배포 Workflow 리뷰 및 Merge 완료
- [ ] 필수 환경변수 목록 확정
- [ ] Secrets Manager Secret 등록 계획 확정
- [ ] Health Check 경로 확정
- [ ] API Container Port 확정
- [ ] DB 마이그레이션 방식 확정
- [ ] 팀 배포 승인 완료

---

## 6. 로컬 사전 검증

2026-10-16 기준 다음 검증을 완료했다.

### 6.1 PostgreSQL 상태 확인

```powershell
docker compose --env-file api/.env.example -f api/compose.local.yaml ps
```

검증 결과:

- PostgreSQL 이미지: `postgres:16.13-alpine`
- 포트: `127.0.0.1:5432`
- 상태: `healthy`

### 6.2 Company 통합 테스트

전용 임시 DB `zoop_company_test_19`를 사용해 다음 테스트를 수행했다.

```powershell
.\api\gradlew.bat -p api companyIntegrationTest
```

결과:

```text
BUILD SUCCESSFUL
```

검증 범위:

- 애플리케이션 Context 실행
- Flyway 마이그레이션
- JPA 스키마 검증
- Company 관련 PostgreSQL 스키마 및 인덱스
- PostgreSQL 확장 기능

### 6.3 Auth 통합 테스트

```powershell
.\api\gradlew.bat -p api authIntegrationTest
```

결과:

```text
BUILD SUCCESSFUL
```

---

## 7. Terraform 정적 검증

### 7.1 Bootstrap 검증

```powershell
terraform -chdir=bootstrap fmt -check -recursive
terraform -chdir=bootstrap init -backend=false
terraform -chdir=bootstrap validate
```

### 7.2 Dev 검증

```powershell
terraform -chdir=dev fmt -check -recursive
terraform -chdir=dev init -backend=false
terraform -chdir=dev validate
```

모든 명령이 성공해야 다음 단계로 진행할 수 있다.

---

## 8. Terraform Backend 연결

> Backend 주소와 State Key는 저장소의 Terraform 설정을 기준으로 확인한다.

```powershell
terraform -chdir=dev init -reconfigure
```

확인 사항:

- [ ] 올바른 S3 Backend에 연결
- [ ] 올바른 Dev State Key 사용
- [ ] State Lock 구성 정상
- [ ] 다른 환경의 State를 참조하지 않음
- [ ] 예상하지 않은 기존 리소스가 State에 존재하지 않음

State 목록을 확인한다.

```powershell
terraform -chdir=dev state list
```

신규 환경이라면 비어 있거나 사전에 합의된 리소스만 표시되어야 한다.

---

## 9. Terraform Plan

Terraform 변수 파일 이름은 저장소의 실제 구성을 사용한다.

```powershell
terraform -chdir=dev plan -var-file="<DEV_TFVARS_FILE>" -out="dev.tfplan"
```

별도의 변수 파일을 사용하지 않는 구조라면 다음과 같이 실행한다.

```powershell
terraform -chdir=dev plan -out="dev.tfplan"
```

Plan 내용을 다시 확인한다.

```powershell
terraform -chdir=dev show dev.tfplan
```

### 9.1 Plan 검토 항목

- [ ] 배포 대상이 Dev 환경인지 확인
- [ ] AWS 리전이 `ap-northeast-2`인지 확인
- [ ] 예상한 리소스만 생성되는지 확인
- [ ] 예상하지 않은 `destroy` 또는 `replace`가 없는지 확인
- [ ] RDS가 Public Access로 설정되지 않았는지 확인
- [ ] Valkey가 Private Subnet에 위치하는지 확인
- [ ] Neo4j EC2에 Public IP가 없는지 확인
- [ ] Security Group의 `0.0.0.0/0` 인바운드가 불필요하게 열리지 않았는지 확인
- [ ] Secrets가 Terraform 출력이나 Plan에 평문으로 노출되지 않는지 확인
- [ ] ECS Task의 CPU와 Memory가 계획과 일치하는지 확인
- [ ] NAT Gateway, RDS, ECS, ALB 등 비용 발생 리소스 확인
- [ ] Resource Tag가 정상 적용되는지 확인

Plan 검토 결과는 관련 GitHub Issue 또는 Pull Request에 기록한다.

---

## 10. 실제 인프라 배포

> 반드시 팀 승인과 Plan 검토가 완료된 후 실행한다.

저장된 Plan을 사용해 Apply한다.

```powershell
terraform -chdir=dev apply "dev.tfplan"
```

Apply 완료 후 Terraform Output을 확인한다.

```powershell
terraform -chdir=dev output
```

주의 사항:

- Plan 생성 이후 코드나 변수 값이 변경되었다면 기존 Plan을 사용하지 않는다.
- 새로운 Plan을 생성하고 다시 리뷰한다.
- Apply 중 오류가 발생해도 곧바로 다시 실행하지 말고 생성된 리소스와 State를 확인한다.
- 문제 해결을 위해 State 파일을 직접 편집하지 않는다.

---

## 11. 인프라 배포 후 확인

### 11.1 ECS 확인

```powershell
aws ecs list-clusters --region ap-northeast-2
aws ecs list-services --cluster <ECS_CLUSTER_NAME> --region ap-northeast-2
aws ecs list-tasks --cluster <ECS_CLUSTER_NAME> --region ap-northeast-2
```

확인 사항:

- [ ] ECS Cluster 생성
- [ ] ECS Service 생성
- [ ] Desired Task 수와 Running Task 수 일치
- [ ] Task가 반복적으로 재시작되지 않음
- [ ] Task Definition의 CPU·Memory·Port 설정 정상

### 11.2 Load Balancer 확인

```powershell
aws elbv2 describe-target-health `
  --target-group-arn <TARGET_GROUP_ARN> `
  --region ap-northeast-2
```

확인 사항:

- [ ] API Task가 Target Group에 등록됨
- [ ] Target 상태가 `healthy`
- [ ] Health Check 경로가 `/health` 또는 확정된 경로와 일치
- [ ] API Container Port와 Target Group Port가 일치

### 11.3 RDS 확인

```powershell
aws rds describe-db-instances --region ap-northeast-2
```

확인 사항:

- [ ] RDS 상태가 `available`
- [ ] Public Access 비활성화
- [ ] Private DB Subnet 배치
- [ ] 예상한 PostgreSQL 버전 사용
- [ ] Security Group 접근 범위 정상
- [ ] 자동 백업 및 보존 기간 설정 확인

### 11.4 Valkey 확인

```powershell
aws elasticache describe-replication-groups --region ap-northeast-2
```

확인 사항:

- [ ] Cluster 상태 정상
- [ ] Private Subnet 배치
- [ ] ECS API에서만 접근 가능
- [ ] 외부 인터넷 접근 차단

### 11.5 Neo4j 확인

확인 사항:

- [ ] EC2 Instance 상태 정상
- [ ] Public IP 없음
- [ ] SSM 접속 가능
- [ ] EBS gp3 연결 정상
- [ ] Neo4j Container 정상 실행
- [ ] 비밀번호가 Secrets Manager를 통해 주입됨
- [ ] Security Group 접근 범위 정상

### 11.6 Secrets Manager 확인

Secret 값을 출력하지 않고 Secret 존재 여부와 메타데이터만 확인한다.

```powershell
aws secretsmanager describe-secret `
  --secret-id <SECRET_NAME> `
  --region ap-northeast-2
```

확인 대상:

- [ ] RDS 접속 정보
- [ ] Neo4j 접속 정보
- [ ] 외부 API Key
- [ ] OAuth 관련 Secret
- [ ] 애플리케이션 서명 또는 인증 Secret

---

## 12. 애플리케이션 배포

> 현재 API Dockerfile 및 ECR/ECS 배포 Workflow가 확정되지 않았으므로 본 단계는 보류한다.

### 12.1 배포 전 기록

| 항목 | 값 |
|---|---|
| 배포 일시 | `<YYYY-MM-DD HH:MM>` |
| 배포 담당자 | 안재현 |
| Git Commit SHA | `<COMMIT_SHA>` |
| Docker Image Tag | `<IMAGE_TAG>` |
| ECS Task Definition Revision | `<REVISION>` |
| 관련 PR | `<PR_URL>` |
| 관련 Issue | `<ISSUE_URL>` |

Docker Image Tag는 추적 가능한 Commit SHA 사용을 권장한다.

예시:

```text
api:<COMMIT_SHA>
ai:<COMMIT_SHA>
```

`latest` 태그만 단독으로 사용하지 않는다.

### 12.2 ECR 이미지 확인

```powershell
aws ecr describe-images `
  --repository-name <API_ECR_REPOSITORY> `
  --region ap-northeast-2
```

확인 사항:

- [ ] 배포 대상 Commit SHA의 이미지 존재
- [ ] 이미지 빌드 성공
- [ ] 이미지 취약점 검사 결과 확인
- [ ] API와 AI 이미지 태그 구분
- [ ] 이미지에 환경변수나 Secret이 포함되지 않음

### 12.3 ECS 배포 확인

GitHub Actions Workflow를 실행한 후 다음을 확인한다.

- [ ] GitHub OIDC 인증 성공
- [ ] ECR 로그인 성공
- [ ] Docker Build 성공
- [ ] ECR Push 성공
- [ ] 새로운 Task Definition 등록 성공
- [ ] ECS Service 업데이트 성공
- [ ] ECS Deployment 안정화 성공
- [ ] 이전 정상 Task가 너무 일찍 종료되지 않음

---

## 13. 배포 후 검증

### 13.1 ECS 안정화 대기

```powershell
aws ecs wait services-stable `
  --cluster <ECS_CLUSTER_NAME> `
  --services <API_SERVICE_NAME> `
  --region ap-northeast-2
```

### 13.2 Health Check

```powershell
Invoke-WebRequest -Uri "https://<DEV_DOMAIN>/health"
```

예상 결과:

- HTTP Status: `200`
- 애플리케이션 상태: `UP` 또는 프로젝트에서 정의한 정상 응답

### 13.3 API Smoke Test

인증이 필요 없는 API부터 확인한다.

```powershell
Invoke-RestMethod -Method Get -Uri "https://<DEV_DOMAIN>/<PUBLIC_API_PATH>"
```

확인 항목:

- [ ] Health Check 성공
- [ ] 인증 API 정상
- [ ] 기업 목록 또는 기업 검색 API 정상
- [ ] PostgreSQL 연결 정상
- [ ] Valkey 연결 정상
- [ ] Neo4j 연결 정상
- [ ] 외부 API 연동 정상
- [ ] 오류 응답에 Secret 또는 내부 연결 정보가 노출되지 않음

### 13.4 Flyway 확인

애플리케이션 로그에서 다음 내용을 확인한다.

- [ ] Flyway 실행 성공
- [ ] Migration Validation 성공
- [ ] Migration 실패 없음
- [ ] JPA Schema Validation 성공
- [ ] 애플리케이션 정상 시작

DB에 직접 접속할 수 있는 승인된 환경에서는 다음 테이블을 확인한다.

```sql
SELECT
    installed_rank,
    version,
    description,
    installed_on,
    success
FROM flyway_schema_history
ORDER BY installed_rank;
```

`success`가 모두 `true`인지 확인한다.

---

## 14. CloudWatch 로그 확인

```powershell
aws logs describe-log-groups --region ap-northeast-2
```

확인 사항:

- [ ] API Log Group 생성
- [ ] AI Log Group 생성
- [ ] ECS Task 로그 수집
- [ ] 애플리케이션 시작 오류 없음
- [ ] DB 연결 오류 없음
- [ ] Health Check 실패 없음
- [ ] Secret 값이 로그에 노출되지 않음
- [ ] Log Retention 기간 설정

장애 분석에 필요한 정보:

- 발생 시간
- ECS Service 이름
- Task ID
- Task Definition Revision
- Docker Image Tag
- 주요 오류 메시지
- 배포 전후 변경 사항

---

## 15. 롤백 기준

다음 상황에서는 신규 배포를 중단하고 이전 정상 버전으로 롤백한다.

- ECS Task가 반복적으로 종료됨
- ALB Target이 `unhealthy` 상태를 유지함
- Health Check가 지속적으로 실패함
- DB 연결 실패
- Flyway Migration 실패
- 인증 또는 주요 API 오류
- 응답 시간이나 오류율 급증
- Secret 또는 민감 정보 노출
- 보안 설정 오류 발견

---

## 16. 애플리케이션 롤백

### 16.1 이전 Task Definition 확인

```powershell
aws ecs list-task-definitions `
  --family-prefix <TASK_DEFINITION_FAMILY> `
  --sort DESC `
  --region ap-northeast-2
```

### 16.2 이전 정상 버전으로 복구

```powershell
aws ecs update-service `
  --cluster <ECS_CLUSTER_NAME> `
  --service <API_SERVICE_NAME> `
  --task-definition <PREVIOUS_TASK_DEFINITION_ARN> `
  --force-new-deployment `
  --region ap-northeast-2
```

### 16.3 롤백 후 안정화 확인

```powershell
aws ecs wait services-stable `
  --cluster <ECS_CLUSTER_NAME> `
  --services <API_SERVICE_NAME> `
  --region ap-northeast-2
```

롤백 후 다음을 다시 확인한다.

- [ ] ECS Running Task 수 정상
- [ ] ALB Target `healthy`
- [ ] Health Check HTTP 200
- [ ] 주요 API Smoke Test 성공
- [ ] CloudWatch 로그 오류 없음

---

## 17. DB 마이그레이션 장애 대응

DB Migration 실패 시 다음 원칙을 따른다.

1. 실패한 애플리케이션의 추가 배포를 중단한다.
2. Flyway 오류 로그와 `flyway_schema_history` 상태를 확인한다.
3. 운영 중인 Migration 파일을 임의로 수정하거나 삭제하지 않는다.
4. 적용 완료된 Migration을 단순히 되돌리지 않는다.
5. 데이터 손실 위험이 있으면 팀원과 검토 후 Forward Fix Migration을 작성한다.
6. 백업 복구가 필요하면 대상 DB와 복구 시점을 먼저 확인한다.
7. DB 변경과 애플리케이션 롤백의 호환성을 확인한다.

> DB 마이그레이션은 애플리케이션 롤백만으로 복구되지 않을 수 있다.
> 데이터 삭제 또는 스키마 강제 변경은 별도의 팀 승인 없이 수행하지 않는다.

---

## 18. Terraform 장애 대응

Terraform Apply가 실패한 경우 다음 순서로 확인한다.

```powershell
terraform -chdir=dev state list
terraform -chdir=dev plan
```

확인 사항:

- [ ] State에 기록된 리소스
- [ ] AWS에 실제 생성된 리소스
- [ ] Apply 재실행 시 생성·변경·삭제 대상
- [ ] IAM 권한 오류
- [ ] 리소스 이름 중복
- [ ] Service Quota 초과
- [ ] Subnet 또는 Security Group 참조 오류

주의 사항:

- State 파일을 직접 편집하지 않는다.
- 문제 해결을 위해 무조건 `terraform destroy`를 실행하지 않는다.
- AWS Console에서 리소스를 수동 삭제하기 전에 Terraform State와 영향 범위를 확인한다.
- Import 또는 State 조작이 필요하면 명령과 대상을 팀 리뷰 후 실행한다.

---

## 19. 배포 증적

배포 완료 후 다음 자료를 관련 Issue에 기록한다.

- [ ] 배포 일시
- [ ] 배포 담당자
- [ ] Terraform Plan 요약
- [ ] Terraform Apply 결과
- [ ] Git Commit SHA
- [ ] Docker Image Tag
- [ ] ECS Task Definition Revision
- [ ] ECS Service 안정화 결과
- [ ] ALB Target Health 결과
- [ ] Health Check 결과
- [ ] Flyway Migration 결과
- [ ] API Smoke Test 결과
- [ ] CloudWatch 로그 확인 결과
- [ ] 발견된 문제와 조치 내용
- [ ] 롤백 여부

Secret, 비밀번호, Token 및 전체 DB 접속 문자열은 증적에 포함하지 않는다.

---

## 20. 배포 결과 기록 양식

```text
## Dev 배포 결과

- 배포 일시:
- 담당자: 안재현
- 관련 WBS:
- 관련 Issue/PR:
- Git Commit SHA:
- Docker Image Tag:
- Terraform Plan:
- Terraform Apply:
- ECS 안정화:
- ALB Target Health:
- Health Check:
- DB/Flyway:
- 주요 API Smoke Test:
- CloudWatch 로그:
- 롤백 여부:
- 특이사항:

### 최종 결과
- [ ] 성공
- [ ] 부분 성공
- [ ] 실패 및 롤백
```

---

## 21. 배포 종료 체크리스트

### 성공한 경우

- [ ] Terraform Apply 성공
- [ ] ECS Service 안정화
- [ ] ALB Target `healthy`
- [ ] Health Check HTTP 200
- [ ] Flyway Migration 성공
- [ ] 주요 API Smoke Test 성공
- [ ] CloudWatch 오류 없음
- [ ] GitHub Issue에 증적 기록
- [ ] 팀에 배포 결과 공유

### 실패한 경우

- [ ] 추가 배포 중단
- [ ] 이전 정상 버전으로 롤백
- [ ] Health Check 재확인
- [ ] 로그와 오류 증적 보존
- [ ] GitHub Issue에 실패 원인 기록
- [ ] 후속 조치 담당자 지정

---

## 22. 비용 관리 및 작업 종료

개발 작업 종료 후 불필요한 비용 발생 여부를 확인한다.

확인 대상:

- ECS Task 수
- NAT Gateway
- ALB
- RDS
- Valkey
- Neo4j EC2
- EBS Volume
- CloudWatch Logs
- 사용하지 않는 ECR Image

비용 절감을 위해 리소스를 중지하거나 제거할 때는 다음을 확인한다.

- Terraform 관리 리소스인지 확인
- 데이터 보존 필요 여부 확인
- 다른 팀원이 사용 중인지 확인
- 재생성 가능 여부 확인
- 팀 승인 여부 확인

데이터가 포함된 RDS, Neo4j EBS 및 Terraform State 관련 리소스는 임의로 삭제하지 않는다.