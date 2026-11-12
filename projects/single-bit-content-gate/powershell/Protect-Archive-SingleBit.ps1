#requires -Version 7.0
<#
.SYNOPSIS
  One-Boolean local archive screening / rip / replace evaluation.
.DESCRIPTION
  One UTF-8 line is one record. On HOLD=true, replaces the ENTIRE public line with
  an empty string. On HOLD=false, copies unchanged. Keeps the original archive
  untouched. Records only hold Boolean and provenance in a local JSONL audit.
  NEVER sends raw content or metadata to Datadog, GitHub, or any remote host.
  FOR EVALUATION PURPOSES. NO WARRANTY. NO COPYRIGHT CLAIM. NO TRADEMARK
  CLAIM. NO INSURANCE. ONLY BEST EFFORT SELF DIRECTED AGENCY LOGIC.
.EXAMPLE
  pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Protect-Archive-SingleBit.ps1
.EXAMPLE
  Get-Content .\safe-test.txt -Encoding utf8 | & .\Protect-Archive-SingleBit.ps1
#>
[CmdletBinding(DefaultParameterSetName = 'File')]
param(
    [Parameter(ValueFromPipeline = $true, ParameterSetName = 'Pipeline')]
    [AllowNull()][AllowEmptyString()][string]$InputObject,
    [Parameter(ParameterSetName = 'File')]
    [string]$ArchivePath = (Join-Path $PSScriptRoot 'all_threads_dump.txt'),
    [string]$OutputPath,
    [string]$AuditPath
)
begin {
    $ErrorActionPreference = 'Stop'
    $policyVersion = '3.1.0-pentagon'
    $maxBytes = 32768
    $utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)
    $utf8Output = [System.Text.UTF8Encoding]::new($false)
    $regexOptions = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor `
                    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    $rules = [ordered]@{
        age      = '\b(?:child|children|kids?|minors?|underage|preteen|teens?|teenagers?|(?:[1-9]|1[0-7])\s*(?:years?\s*old|yo))\b'
        sexual   = '\b(?:sex|sexual|sexually|sexting|sexts?|nudes?|naked|porn|pornography|explicit|intimate)\b'
        media    = '\b(?:photos?|pics?|pictures?|images?|videos?|clips?|snaps?)\b'
        request  = '\b(?:send|share|trade|swap|buy|sell|upload|download|exchange|request)\b'
        secrecy  = '\b(?:secret|secretly|privately|quietly|don.?t\s+tell)\b'
        contact  = '\b(?:dm\s+me|pm\s+me|private\s+message|add\s+me)\b'
        coercion = '\b(?:blackmail|extort|extortion|threaten|threatened|threatening)\b'
        direct   = '\b(?:csam|csae|child\s+sexual\s+abuse|child\s+sexual\s+exploitation)\b'
    }
    function Test-Hold([string]$original) {
        try {
            $text = if ($null -eq $original) { '' } else { $original }
            if ($utf8Strict.GetByteCount($text) -gt $maxBytes) { return $true }
            $normalized = $text.Normalize([System.Text.NormalizationForm]::FormKC)
            $normalized = [regex]::Replace($normalized, '[\u200B-\u200D\uFEFF]', '')
            $h = @{}
            foreach ($name in $rules.Keys) {
                $h[$name] = [regex]::IsMatch($normalized, [string]$rules[$name], $regexOptions)
            }
            # Exactly ONE final outcome Boolean. No numeric scores, no other tiers.
            return [bool](
                $h.direct -or
                ($h.age -and ($h.sexual -or $h.coercion)) -or
                ($h.age -and (($h.secrecy -and $h.contact) -or ($h.media -and $h.request))) -or
                ($h.sexual -and $h.coercion)
            )
        } catch {
            return $true  # Fail closed for processing exceptions.
        }
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
    $runId = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $prefix = if ($PSCmdlet.ParameterSetName -eq 'File') {
        [IO.Path]::GetFileNameWithoutExtension($ArchivePath)
    } else { 'piped-archive' }
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = Join-Path $PSScriptRoot "$prefix.sanitized.$stamp.$runId.txt"
    }
    if ([string]::IsNullOrWhiteSpace($AuditPath)) {
        $AuditPath = Join-Path $PSScriptRoot "$prefix.hold-audit.$stamp.$runId.jsonl"
    }
    $outFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
    $auditFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($AuditPath)
    if ($outFull -ieq $auditFull) { throw 'Output and audit paths must differ.' }
    if ($PSCmdlet.ParameterSetName -eq 'File') {
        $sourceFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ArchivePath)
        if (-not [IO.File]::Exists($sourceFull)) { throw "Archive not found: $sourceFull" }
        if ($sourceFull -ieq $outFull -or $sourceFull -ieq $auditFull) {
            throw 'Refusing to overwrite original archive.'
        }
    }
    $publicStream = [IO.File]::Open($outFull, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $auditStream = [IO.File]::Open($auditFull, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    } catch { $publicStream.Dispose(); throw }
    $publicWriter = [IO.StreamWriter]::new($publicStream, $utf8Output)
    $auditWriter = [IO.StreamWriter]::new($auditStream, $utf8Output)
    $script:processed = 0
    $script:heldCount = 0
    function Write-Record([string]$content) {
        $text = if ($null -eq $content) { '' } else { $content }
        [bool]$hold = Test-Hold $text
        $publicWriter.WriteLine($(if ($hold) { '' } else { $text }))
        $script:processed++
        if ($hold) { $script:heldCount++ }
        $auditWriter.WriteLine((ConvertTo-Json -InputObject ([ordered]@{
            record_number = $script:processed
            hold = $hold
            policy_version = $policyVersion
        }) -Compress))
    }
}
process {
    if ($PSCmdlet.ParameterSetName -eq 'Pipeline') { Write-Record $InputObject }
}
end {
    $reader = $null
    try {
        if ($PSCmdlet.ParameterSetName -eq 'File') {
            $reader = [IO.StreamReader]::new($sourceFull, $utf8Strict, $true)
            while (-not $reader.EndOfStream) { Write-Record ($reader.ReadLine()) }
        }
    } finally {
        if ($null -ne $reader) { $reader.Dispose() }
        $publicWriter.Dispose()
        $auditWriter.Dispose()
    }
    Write-Host "Processed: $script:processed | HOLD=true: $script:heldCount | Remote events: 0"
    Write-Host "Sanitized: $outFull"
    Write-Host "Boolean audit: $auditFull"
    if ($script:heldCount -gt 0) {
        Write-Warning 'HOLD flags need appropriately restricted human review. No finding of criminality is implied.'
    }
}