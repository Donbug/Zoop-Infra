[CmdletBinding()]
param(
    [string]$Profile = "zoop-dev",
    [string]$Region = "ap-northeast-2",
    [string]$AccountId = "512138915880"
)

$ErrorActionPreference = "Stop"
$script:FailureCount = 0

$RepositoryName = "zoop-dev-ai-collection"
$BucketName = "zoop-dev-ai-collection-$AccountId"
$LogGroupName = "/ecs/zoop-dev/ai-collection"
$SecretName = "zoop-dev/ai/collection"
$SecurityGroupName = "zoop-dev-ai-collection-sg"
$TaskRoleName = "zoop-dev-ai-collection-task-role"
$ExecutionRoleName = "zoop-dev-ai-collection-task-execution-role"

function Invoke-AwsJson {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $rawOutput = & aws @Arguments 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw ($rawOutput -join [Environment]::NewLine)
    }

    $json = $rawOutput -join [Environment]::NewLine

    if ([string]::IsNullOrWhiteSpace($json)) {
        return $null
    }

    return $json | ConvertFrom-Json
}

function Invoke-Check {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Action
    )

    try {
        $passed = & $Action

        if ($passed) {
            Write-Host "[PASS] $Name" -ForegroundColor Green
        }
        else {
            Write-Host "[FAIL] $Name" -ForegroundColor Red
            $script:FailureCount++
        }
    }
    catch {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        Write-Host "       $($_.Exception.Message)" -ForegroundColor DarkRed
        $script:FailureCount++
    }
}

Write-Host ""
Write-Host "ZOOP AI Collection infrastructure verification" -ForegroundColor Cyan
Write-Host "Profile: $Profile"
Write-Host "Region : $Region"
Write-Host ""

Invoke-Check "AWS account identity" {
    $identity = Invoke-AwsJson -Arguments @(
        "sts", "get-caller-identity",
        "--profile", $Profile,
        "--output", "json"
    )

    $identity.Account -eq $AccountId
}

Invoke-Check "ECR repository configuration" {
    $result = Invoke-AwsJson -Arguments @(
        "ecr", "describe-repositories",
        "--repository-names", $RepositoryName,
        "--region", $Region,
        "--profile", $Profile,
        "--output", "json"
    )

    $repository = $result.repositories[0]

    ($repository.repositoryName -eq $RepositoryName) -and
    ($repository.imageTagMutability -eq "IMMUTABLE") -and
    ($repository.imageScanningConfiguration.scanOnPush -eq $true) -and
    ($repository.encryptionConfiguration.encryptionType -eq "AES256")
}

Invoke-Check "ECR lifecycle policy" {
    $result = Invoke-AwsJson -Arguments @(
        "ecr", "get-lifecycle-policy",
        "--repository-name", $RepositoryName,
        "--region", $Region,
        "--profile", $Profile,
        "--output", "json"
    )

    $policy = $result.lifecyclePolicyText | ConvertFrom-Json

    ($policy.rules.Count -eq 2) -and
    ($policy.rules[0].selection.countNumber -eq 7) -and
    ($policy.rules[1].selection.countNumber -eq 10)
}

Invoke-Check "S3 public access block" {
    $result = Invoke-AwsJson -Arguments @(
        "s3api", "get-public-access-block",
        "--bucket", $BucketName,
        "--profile", $Profile,
        "--output", "json"
    )

    $config = $result.PublicAccessBlockConfiguration

    $config.BlockPublicAcls -and
    $config.IgnorePublicAcls -and
    $config.BlockPublicPolicy -and
    $config.RestrictPublicBuckets
}

Invoke-Check "S3 AES256 encryption" {
    $result = Invoke-AwsJson -Arguments @(
        "s3api", "get-bucket-encryption",
        "--bucket", $BucketName,
        "--profile", $Profile,
        "--output", "json"
    )

    $algorithm = $result.ServerSideEncryptionConfiguration.Rules[0].
        ApplyServerSideEncryptionByDefault.SSEAlgorithm

    $algorithm -eq "AES256"
}

Invoke-Check "S3 versioning" {
    $result = Invoke-AwsJson -Arguments @(
        "s3api", "get-bucket-versioning",
        "--bucket", $BucketName,
        "--profile", $Profile,
        "--output", "json"
    )

    $result.Status -eq "Enabled"
}

Invoke-Check "CloudWatch log group retention" {
    $result = Invoke-AwsJson -Arguments @(
        "logs", "describe-log-groups",
        "--log-group-name-prefix", $LogGroupName,
        "--region", $Region,
        "--profile", $Profile,
        "--output", "json"
    )

    $logGroup = $result.logGroups |
        Where-Object { $_.logGroupName -eq $LogGroupName } |
        Select-Object -First 1

    ($null -ne $logGroup) -and ($logGroup.retentionInDays -eq 14)
}

Invoke-Check "Security group has no ingress" {
    $result = Invoke-AwsJson -Arguments @(
        "ec2", "describe-security-groups",
        "--filters", "Name=group-name,Values=$SecurityGroupName",
        "--region", $Region,
        "--profile", $Profile,
        "--output", "json"
    )

    ($result.SecurityGroups.Count -eq 1) -and
    ($result.SecurityGroups[0].IpPermissions.Count -eq 0)
}

Invoke-Check "Security group outbound access" {
    $result = Invoke-AwsJson -Arguments @(
        "ec2", "describe-security-groups",
        "--filters", "Name=group-name,Values=$SecurityGroupName",
        "--region", $Region,
        "--profile", $Profile,
        "--output", "json"
    )

    $egress = $result.SecurityGroups[0].IpPermissionsEgress

    ($egress.IpProtocol -contains "-1") -and
    ($egress.IpRanges.CidrIp -contains "0.0.0.0/0")
}

Invoke-Check "Task role inline policies" {
    $result = Invoke-AwsJson -Arguments @(
        "iam", "list-role-policies",
        "--role-name", $TaskRoleName,
        "--profile", $Profile,
        "--output", "json"
    )

    ($result.PolicyNames -contains "zoop-dev-ai-collection-s3-access") -and
    ($result.PolicyNames -contains "zoop-dev-ai-collection-ecs-exec")
}

Invoke-Check "Execution role inline secret policy" {
    $result = Invoke-AwsJson -Arguments @(
        "iam", "list-role-policies",
        "--role-name", $ExecutionRoleName,
        "--profile", $Profile,
        "--output", "json"
    )

    $result.PolicyNames -contains "zoop-dev-ai-collection-runtime-secret-access"
}

Invoke-Check "Execution role managed policy" {
    $result = Invoke-AwsJson -Arguments @(
        "iam", "list-attached-role-policies",
        "--role-name", $ExecutionRoleName,
        "--profile", $Profile,
        "--output", "json"
    )

    $result.AttachedPolicies.PolicyName -contains "AmazonECSTaskExecutionRolePolicy"
}

Invoke-Check "Secrets Manager container" {
    $result = Invoke-AwsJson -Arguments @(
        "secretsmanager", "describe-secret",
        "--secret-id", $SecretName,
        "--region", $Region,
        "--profile", $Profile,
        "--output", "json"
    )

    $result.Name -eq $SecretName
}

try {
    $imageResult = Invoke-AwsJson -Arguments @(
        "ecr", "describe-images",
        "--repository-name", $RepositoryName,
        "--region", $Region,
        "--profile", $Profile,
        "--output", "json"
    )

    $imageCount = @($imageResult.imageDetails).Count
    Write-Host "[INFO] ECR image count: $imageCount" -ForegroundColor Yellow
}
catch {
    Write-Host "[FAIL] Unable to read ECR images" -ForegroundColor Red
    Write-Host "       $($_.Exception.Message)" -ForegroundColor DarkRed
    $script:FailureCount++
}

try {
    $versionResult = Invoke-AwsJson -Arguments @(
        "secretsmanager", "list-secret-version-ids",
        "--secret-id", $SecretName,
        "--region", $Region,
        "--profile", $Profile,
        "--output", "json"
    )

    $secretVersionCount = @($versionResult.Versions).Count
    Write-Host "[INFO] Secret version count: $secretVersionCount" -ForegroundColor Yellow
}
catch {
    Write-Host "[FAIL] Unable to read Secret versions" -ForegroundColor Red
    Write-Host "       $($_.Exception.Message)" -ForegroundColor DarkRed
    $script:FailureCount++
}

Write-Host ""

if ($script:FailureCount -gt 0) {
    Write-Host "Verification failed: $script:FailureCount check(s) failed." -ForegroundColor Red
    exit 1
}

Write-Host "Verification completed successfully." -ForegroundColor Green
exit 0
