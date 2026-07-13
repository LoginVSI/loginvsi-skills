# mapper-lib.ps1
# Pure, platform-independent helpers for the Login Enterprise app mapper (desktop backend).
# Dot-source this file; it defines functions only and has no side effects.
#
# DumpHierarchy output format (discovered from engine 6.5.10):
#   Indented plain text, 2 spaces per nesting level. Each line:
#     {indent}[({handle})] {ControlType}[:{ClassName}] -- '{Name}'
#   Examples:
#     (7D035E) Win32 Window:Notepad -- 'paint.cs - Notepad'
#       (77040E) Pane:Microsoft.UI.Content.DesktopChildSiteBridge -- ''
#         Button:Button -- 'OK'
#         TitleBar -- ''
#   - Handle (hex in parens) is optional; not every line has one.
#   - ControlType is before the colon; ClassName is after (may be absent if no colon).
#   - Name is in single quotes after ' -- '.
#   - Name may span multiple lines (embedded newlines in the quoted value).

function ConvertFrom-DumpHierarchy {
    <# Parse a DumpHierarchy output file (indented plain text) into an array of control
       descriptor objects. Each object has: name, className, controlType, xpath, suggestedFinder.

       The handle (hex in parens) is recorded but not used as automationId -- it is a volatile
       window handle, not a stable AutomationId property. automationId is set to empty string
       since the dump format does not expose it. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) { return @() }

    $raw = Get-Content -Path $Path -Raw
    if (-not $raw) { return @() }

    # Join continuation lines (name spanning multiple lines ends with a closing quote)
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($rawLine in ($raw -split "`n")) {
        $line = $rawLine.TrimEnd("`r")
        if ($lines.Count -gt 0 -and $line -match "^[^']*'$" -and $lines[$lines.Count - 1] -notmatch "'\s*$") {
            # Continuation of a multi-line name
            $lines[$lines.Count - 1] += "`n$line"
        } else {
            $lines.Add($line)
        }
    }

    $controls = [System.Collections.Generic.List[object]]::new()
    # Stack of (controlType, depth) for xpath computation
    $stack = [System.Collections.Generic.List[object]]::new()

    # Pattern: optional handle, then ControlType[:ClassName], then -- 'Name'
    $pattern = "^(?<indent>\s*)(?:\([0-9A-Fa-f]+\)\s+)?(?<controlType>[^:]+?)(?::(?<className>[^\s]+(?:\s+[^\S\n]+)*?))?\s+--\s+'(?<name>.*)'$"

    foreach ($line in $lines) {
        if (-not $line.Trim()) { continue }

        if ($line -match $pattern) {
            $indent      = $Matches['indent'].Length
            $depth       = [math]::Floor($indent / 2)
            $controlType = $Matches['controlType'].Trim()
            $className   = if ($Matches['className']) { $Matches['className'].Trim() } else { '' }
            $name        = $Matches['name']

            # Handle multi-line names -- collapse newlines to spaces for the name field
            $nameCleaned = ($name -replace "`r?`n\s*", ' ').Trim()

            # Build xpath: trim stack to current depth, then push
            while ($stack.Count -gt $depth) {
                $stack.RemoveAt($stack.Count - 1)
            }
            $stack.Add(@{ controlType = $controlType; className = $className })

            # Build xpath in engine format: ControlType:ClassName/ControlType:ClassName (no leading slash)
            # IMPORTANT: Skip the root window (depth 0) since MainWindow.FindControlWithXPath searches
            # relative to MainWindow, not from the desktop root.
            $xpathStack = if ($stack.Count -gt 1) { $stack | Select-Object -Skip 1 } else { @() }
            $xpath = ($xpathStack | ForEach-Object {
                $ct = $_['controlType'] -replace '\s+', ''
                $cn = $_['className']
                if ($cn) { "$ct`:$cn" } else { $ct }
            }) -join '/'

            # Build suggestedFinder using FindAutomationElementByXPathOrInformation
            # For root window (depth 0), use MainWindow directly
            # For other controls, use FindAutomationElementByXPathOrInformation with all available parameters
            $finder = if ($depth -eq 0) {
                "MainWindow"
            } else {
                "FindAutomationElementByXPathOrInformation(xpath: `"$xpath`", automationId: `"`", className: `"$className`", name: `"$nameCleaned`", controlType: `"$controlType`")"
            }

            $controls.Add([pscustomobject]@{
                name            = $nameCleaned
                automationId    = ''
                className       = $className
                controlType     = $controlType
                xpath           = $xpath
                suggestedFinder = $finder
            })
        }
    }

    return $controls.ToArray()
}

function ConvertFrom-ProbeLog {
    <#
    .SYNOPSIS
        Parse MAPPER_STEP and MAPPER_FINDER log lines from a probe run.
    .PARAMETER LogLines
        Array of log lines from the engine stdout.
    .OUTPUTS
        Hashtable with:
          steps   = @( @{ index; label; action; success } )
          controls = @( @{ id; label; controlType; className; name; xpath; finders; preferredFinder } )
    #>
    param([string[]]$LogLines)

    $steps = @()
    $findersByStep = @{}

    foreach ($line in $LogLines) {
        if ($line -match '^MAPPER_STEP\|(\d+)\|(.+?)\|(.+)$') {
            $idx = [int]$Matches[1]
            $steps += @{
                index   = $idx
                label   = $Matches[2]
                action  = $Matches[3]
                success = $true
            }
            if (-not $findersByStep.ContainsKey($idx)) {
                $findersByStep[$idx] = @{}
            }
        }
        elseif ($line -match '^MAPPER_FINDER\|(\d+)\|(.+?)\|(OK|FAIL)\|(.*)$') {
            $idx = [int]$Matches[1]
            $method = $Matches[2]
            $status = $Matches[3]
            $paramStr = $Matches[4]

            # Parse params from "key=value;key=value" format
            $params = @{}
            foreach ($pair in ($paramStr -split ';')) {
                if ($pair -match '^(.+?)=(.*)$') {
                    $params[$Matches[1]] = $Matches[2]
                }
            }

            if (-not $findersByStep.ContainsKey($idx)) {
                $findersByStep[$idx] = @{}
            }
            $findersByStep[$idx][$method] = @{
                status = $status
                params = $params
            }
        }
        elseif ($line -match '^MAPPER_STEP_FAIL\|(\d+)\|(.+)$') {
            $idx = [int]$Matches[1]
            $existing = $steps | Where-Object { $_.index -eq $idx }
            if ($existing) { $existing.success = $false }
        }
    }

    # Build controls from steps + finders
    $controls = @()
    foreach ($step in $steps) {
        $idx = $step.index
        $finders = if ($findersByStep.ContainsKey($idx)) { $findersByStep[$idx] } else { @{} }

        # Determine preferred finder
        $preferred = $null
        foreach ($method in @('FindAutomationElementByXPathOrInformation',
                              'FindControlWithXPath', 'FindControl')) {
            if ($finders.ContainsKey($method) -and $finders[$method].status -eq 'OK') {
                if (-not $preferred) { $preferred = $method }
            }
        }

        # Extract control metadata from finders params
        $bestParams = if ($preferred) { $finders[$preferred].params } else { @{} }

        $controls += @{
            id              = ($step.label -replace '[^a-zA-Z0-9]', '-').ToLower().Trim('-')
            label           = $step.label
            controlType     = if ($bestParams.ContainsKey('controlType')) { $bestParams['controlType'] } else { '' }
            className       = if ($bestParams.ContainsKey('className')) { $bestParams['className'] } else { '' }
            name            = if ($bestParams.ContainsKey('name')) { $bestParams['name'] } else { $step.label }
            xpath           = if ($bestParams.ContainsKey('xpath')) { $bestParams['xpath'] }
                              elseif ($bestParams.ContainsKey('xPath')) { $bestParams['xPath'] }
                              else { '' }
            finders         = $finders
            preferredFinder = if ($preferred) { $preferred } else { 'none' }
        }
    }

    return @{
        steps    = $steps
        controls = $controls
    }
}

function New-AppMap {
    <#
    .SYNOPSIS
        Assemble a v2.0 app-map object from controls and metadata.
    .PARAMETER AppName
        Name of the application.
    .PARAMETER Kind
        'desktop' or 'web'.
    .PARAMETER Controls
        Array of control objects from ConvertFrom-DumpHierarchy or ConvertFrom-ProbeLog.
    .PARAMETER Workflows
        Array of workflow names captured in this map.
    .PARAMETER ExePath
        (Desktop only) Path to the application executable.
    .PARAMETER MainWindowTitle
        (Desktop only) Main window title pattern.
    .PARAMETER Url
        (Web only) URL of the application.
    .PARAMETER Confidence
        Confidence level: 'high', 'medium', or 'low'.
    .PARAMETER Notes
        Coverage notes for the consumer.
    #>
    param(
        [string]$AppName,
        [string]$Kind = 'desktop',
        [object[]]$Controls,
        [string[]]$Workflows = @(),
        [string]$ExePath = '',
        [string]$MainWindowTitle = '',
        [string]$Url = '',
        [string]$Confidence = 'high',
        [string]$Notes = 'Java apps, RDP windows, and custom-draw regions may not be visible to UIAutomation.'
    )

    $app = @{ name = $AppName; kind = $Kind }
    if ($Kind -eq 'desktop') {
        $app.exePath = $ExePath
        $app.mainWindowTitle = $MainWindowTitle
    } else {
        $app.url = $Url
    }

    return @{
        schemaVersion = '2.0'
        app           = $app
        capturedAt    = (Get-Date).ToUniversalTime().ToString('o')
        workflows     = $Workflows
        controls      = $Controls
        coverage      = @{
            method     = if ($Kind -eq 'desktop') { 'DumpHierarchy' } else { 'PlaywrightAccessibilitySnapshot' }
            confidence = $Confidence
            notes      = $Notes
        }
    }
}

function Merge-AppMap {
    <#
    .SYNOPSIS
        Union-merge new controls into an existing app-map.
    .PARAMETER Existing
        The existing app-map object (or $null for first run).
    .PARAMETER NewControls
        Array of control objects from ConvertFrom-ProbeLog.
    .PARAMETER WorkflowName
        Name of the workflow being added.
    .OUTPUTS
        Updated app-map object.
    #>
    param(
        [object]$Existing,
        [object[]]$NewControls,
        [string]$WorkflowName
    )

    if (-not $Existing) {
        # First run — just tag controls with workflow
        foreach ($c in $NewControls) {
            $c.discoveredBy = @($WorkflowName)
        }
        # Comma operator prevents PowerShell from unwrapping single-element arrays
        return ,[object[]]$NewControls
    }

    $merged = [System.Collections.ArrayList]@($Existing)

    foreach ($newCtrl in $NewControls) {
        $match = $merged | Where-Object { $_.id -eq $newCtrl.id } | Select-Object -First 1
        if ($match) {
            # Union merge finders
            foreach ($method in $newCtrl.finders.Keys) {
                if (-not $match.finders.ContainsKey($method)) {
                    $match.finders[$method] = $newCtrl.finders[$method]
                }
                elseif ($match.finders[$method].status -ne 'OK' -and $newCtrl.finders[$method].status -eq 'OK') {
                    # Upgrade from FAIL to OK
                    $match.finders[$method] = $newCtrl.finders[$method]
                }
            }
            # Update preferred if current is 'none' but new has one
            if ($match.preferredFinder -eq 'none' -and $newCtrl.preferredFinder -ne 'none') {
                $match.preferredFinder = $newCtrl.preferredFinder
            }
            # Add workflow to discoveredBy — rebuild array to avoid in-place mutation issues
            if ($match.discoveredBy -notcontains $WorkflowName) {
                $match.discoveredBy = @($match.discoveredBy) + $WorkflowName
            }
        }
        else {
            # New control
            $newCtrl.discoveredBy = @($WorkflowName)
            $merged.Add($newCtrl) | Out-Null
        }
    }

    # Comma operator prevents PowerShell from unwrapping single-element arrays
    return ,[object[]]$merged.ToArray()
}

function ConvertTo-AppMapJson {
    <# Serialize an app-map object to a JSON string. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$AppMap)

    return ($AppMap | ConvertTo-Json -Depth 10)
}
