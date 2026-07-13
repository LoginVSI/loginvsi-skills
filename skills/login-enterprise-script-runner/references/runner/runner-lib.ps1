# runner-lib.ps1
# Pure, platform-independent helpers for running Login Enterprise .cs scripts
# on a standalone engine. No side effects, no engine invocation here.

Set-StrictMode -Version Latest

function Get-ScriptOutcome {
    <#
      Classify a standalone-engine run from its console output.

      The process EXIT CODE is NOT a reliable success signal: the deployed engine (observed on
      6.5.10) exits 0 on success, and 0 is not even a value of the ScriptResult enum. The exit
      code also varies by engine build. So we classify from the deterministic stdout markers the
      engine prints, and treat the exit code as informational only.

      Check failure markers BEFORE the "ended" marker: the engine prints "The script ended" at the
      end of every iteration, including failed ones, so it alone does not mean success.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$StdoutText,
        [int]$ExitCode = 0
    )

    if ($StdoutText -match 'could not construct the script to be executed') {
        return [pscustomobject]@{ result = 'CompilationError'; success = $false }
    }
    if ($StdoutText -match 'did not complete successfully') {
        return [pscustomobject]@{ result = 'EndedWithErrors'; success = $false }
    }
    if ($StdoutText -match 'encountered an error') {
        return [pscustomobject]@{ result = 'EndedWithErrors'; success = $false }
    }
    if ($StdoutText -match 'The script ended') {
        return [pscustomobject]@{ result = 'Ended'; success = $true }
    }
    return [pscustomobject]@{ result = 'Undefined'; success = $false }
}

function ConvertFrom-ResultsCsv {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$CsvPath)

    if (-not (Test-Path $CsvPath)) { return @() }
    $timers = New-Object System.Collections.Generic.List[object]
    # Engine writes this CSV with plain string interpolation and NO quoting, so fields never
    # contain commas. Columns: 0=Timestamp 1=EngineVersion 2=Machine 3=User 4=Application
    #                          5=MeasurementId(name) 6=Result(value)
    foreach ($line in Get-Content -Path $CsvPath) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $cols = $line.Split(',')
        if ($cols.Count -lt 7) { continue }
        $value = 0
        # Engine writes invariant '.' decimals; parse with invariant culture so comma-decimal
        # hosts (e.g. de-DE) don't corrupt values like 1200.5.
        [void][double]::TryParse($cols[6],
            [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref]$value)
        $timers.Add([pscustomobject]@{
            name      = $cols[5]
            value     = $value
            timestamp = $cols[0]
        })
    }
    return $timers.ToArray()
}

function Test-ScriptHeader {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$ScriptText)

    if ($ScriptText -match '(?m)^\s*//\s*TARGET:') {
        return [pscustomobject]@{ ok = $true; kind = 'windows'; message = $null }
    }
    if ($ScriptText -match '(?m)^\s*//\s*BROWSER:') {
        return [pscustomobject]@{ ok = $true; kind = 'web'; message = $null }
    }
    $msg = @(
        'Script is missing the required engine header comment.'
        'Windows app:  // TARGET:C:\Windows\System32\notepad.exe   (optionally // START_IN:...)'
        'Web app:      // BROWSER:EdgeChromium                      (optionally // URL:...)'
    ) -join [Environment]::NewLine
    return [pscustomobject]@{ ok = $false; kind = $null; message = $msg }
}

function Build-EngineArgs {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Settings)

    foreach ($k in 'Script','Results') {
        if (-not $Settings.ContainsKey($k) -or -not $Settings[$k]) {
            throw "Build-EngineArgs: required setting '$k' is missing or empty."
        }
    }

    $argList = New-Object System.Collections.Generic.List[string]
    $argList.Add("script=$($Settings.Script)")
    $argList.Add("results=$($Settings.Results)")

    if ($Settings.ContainsKey('Parameters') -and $Settings.Parameters) { $argList.Add("parameters=$($Settings.Parameters)") }
    if ($Settings.ContainsKey('User')       -and $Settings.User)       { $argList.Add("user=$($Settings.User)") }
    if ($Settings.ContainsKey('Password')   -and $Settings.Password)   { $argList.Add("password=$($Settings.Password)") }
    if ($Settings.ContainsKey('Repeats')    -and $Settings.Repeats)    { $argList.Add("repeats=$($Settings.Repeats)") }
    if ($Settings.ContainsKey('LeaveRunning')) { $argList.Add("leaverunning=$($Settings.LeaveRunning.ToString().ToLower())") }
    if ($Settings.ContainsKey('Debug'))        { $argList.Add("debug=$($Settings.Debug.ToString().ToLower())") }

    return $argList.ToArray()
}
