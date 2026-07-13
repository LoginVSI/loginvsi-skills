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

function Compare-DumpHierarchy {
    <#
    .SYNOPSIS
        Compare two parsed control arrays (before/after an action) and report changes.
    .PARAMETER Before
        Control array from ConvertFrom-DumpHierarchy before the action.
    .PARAMETER After
        Control array from ConvertFrom-DumpHierarchy after the action.
    .OUTPUTS
        Hashtable with:
          newControls     = controls in After but not Before (by xpath+name key)
          removedControls = controls in Before but not After
          unchanged       = count of controls present in both
          uiChanged       = $true if any new or removed controls detected
    #>
    param(
        [object[]]$Before,
        [object[]]$After
    )

    if (-not $Before) { $Before = @() }
    if (-not $After)  { $After = @() }

    # Build lookup keys: xpath|controlType|name — unique enough to detect meaningful changes
    function Get-ControlKey($ctrl) {
        $x = if ($ctrl.xpath) { $ctrl.xpath } else { '' }
        $t = if ($ctrl.controlType) { $ctrl.controlType } else { '' }
        $n = if ($ctrl.name) { $ctrl.name } else { '' }
        return "$x|$t|$n"
    }

    $beforeKeys = @{}
    foreach ($c in $Before) {
        $key = Get-ControlKey $c
        $beforeKeys[$key] = $c
    }

    $afterKeys = @{}
    foreach ($c in $After) {
        $key = Get-ControlKey $c
        $afterKeys[$key] = $c
    }

    $newControls = @()
    foreach ($key in $afterKeys.Keys) {
        if (-not $beforeKeys.ContainsKey($key)) {
            $newControls += $afterKeys[$key]
        }
    }

    $removedControls = @()
    foreach ($key in $beforeKeys.Keys) {
        if (-not $afterKeys.ContainsKey($key)) {
            $removedControls += $beforeKeys[$key]
        }
    }

    $unchangedCount = 0
    foreach ($key in $afterKeys.Keys) {
        if ($beforeKeys.ContainsKey($key)) { $unchangedCount++ }
    }

    return @{
        newControls     = $newControls
        removedControls = $removedControls
        unchanged       = $unchangedCount
        uiChanged       = ($newControls.Count -gt 0 -or $removedControls.Count -gt 0)
    }
}

function ConvertFrom-ProbeLog {
    <#
    .SYNOPSIS
        Parse MAPPER_STEP and MAPPER_FINDER log lines from a probe run.
    .PARAMETER LogLines
        Array of log lines from the engine stdout.
    .OUTPUTS
        Hashtable with:
          steps    = @( @{ index; label; action; success; verification } )
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
        elseif ($line -match '^MAPPER_VERIFY\|(\d+)\|new=(\d+)\|removed=(\d+)\|(.*)$') {
            $idx = [int]$Matches[1]
            $existing = $steps | Where-Object { $_.index -eq $idx }
            if ($existing) {
                $existing.verification = @{
                    newControls     = [int]$Matches[2]
                    removedControls = [int]$Matches[3]
                    summary         = $Matches[4]
                    uiChanged       = ([int]$Matches[2] -gt 0 -or [int]$Matches[3] -gt 0)
                }
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

# ---------------------------------------------------------------------------
# Catalog functions
# ---------------------------------------------------------------------------

function Get-CatalogDir {
    <# Return the catalog directory path for the given scope, creating it if needed.
       Scope 'Project' (default): <cwd>/.app-maps/
       Scope 'Global':            ~/.login-enterprise/app-maps/ #>
    [CmdletBinding()]
    param(
        [ValidateSet('Project', 'Global')]
        [string]$Scope = 'Project'
    )

    $path = if ($Scope -eq 'Global') {
        Join-Path (Join-Path $HOME '.login-enterprise') 'app-maps'
    } else {
        Join-Path (Get-Location) '.app-maps'
    }

    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Force -Path $path | Out-Null
    }
    return $path
}

function Get-CatalogIndex {
    <# Read index.json from a catalog directory. Returns an array of entry objects.
       Returns an empty array if the file doesn't exist. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$CatalogDir)

    $indexPath = Join-Path $CatalogDir 'index.json'
    if (-not (Test-Path $indexPath)) { return @() }

    $raw = Get-Content -Path $indexPath -Raw
    if (-not $raw) { return @() }

    $parsed = $raw | ConvertFrom-Json
    if ($parsed -is [array]) { return $parsed }
    return @($parsed)
}

function Add-MapToCatalog {
    <# Save an app-map to the catalog directory and update index.json.
       Filename convention: <name>-<kind>-<version>.app-map.json.
       Never overwrites — appends a timestamp suffix if the name already exists. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Map,
        [Parameter(Mandatory)][string]$CatalogDir,
        [string]$AppVersion = 'unknown'
    )

    if (-not (Test-Path $CatalogDir)) {
        New-Item -ItemType Directory -Force -Path $CatalogDir | Out-Null
    }

    $name     = $Map.app.name
    $platform = $Map.app.kind
    $baseName = "$name-$platform-$AppVersion"
    $fileName = "$baseName.app-map.json"
    $filePath = Join-Path $CatalogDir $fileName

    # Never overwrite — append timestamp if file exists
    if (Test-Path $filePath) {
        $ts = (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss')
        $fileName = "$baseName-$ts.app-map.json"
        $filePath = Join-Path $CatalogDir $fileName
    }

    # Write the map file
    $json = ConvertTo-AppMapJson -AppMap $Map
    Set-Content -Path $filePath -Value $json -Encoding UTF8

    # Update index.json
    $index = [System.Collections.Generic.List[object]]::new()
    $existingIndex = Get-CatalogIndex -CatalogDir $CatalogDir
    foreach ($entry in $existingIndex) { $index.Add($entry) }

    $capturedAt = if ($Map.capturedAt) { $Map.capturedAt } else { (Get-Date).ToUniversalTime().ToString('o') }
    $confidence = if ($Map.coverage -and $Map.coverage.confidence) { $Map.coverage.confidence } else { 'unknown' }

    $index.Add([pscustomobject][ordered]@{
        name       = $name
        platform   = $platform
        version    = $AppVersion
        capturedAt = $capturedAt
        confidence = $confidence
        path       = $fileName
    })

    $indexPath = Join-Path $CatalogDir 'index.json'
    ($index | ConvertTo-Json -Depth 5) | Set-Content -Path $indexPath -Encoding UTF8

    return $filePath
}

function Resolve-MapInCatalog {
    <# Look up a map in the catalog by app name. Returns the full path to the best
       match (most recent capturedAt), or $null if no match.

       When no -CatalogDir is provided, checks project-local scope first, then global. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AppName,
        [string]$CatalogDir,
        [string]$Platform,
        [string]$Version
    )

    # If no explicit CatalogDir, search project-local first then global
    if (-not $CatalogDir) {
        $projectDir = Get-CatalogDir -Scope 'Project'
        $result = Resolve-MapInCatalog -AppName $AppName -CatalogDir $projectDir `
            -Platform:$Platform -Version:$Version
        if ($result) { return $result }

        $globalDir = Get-CatalogDir -Scope 'Global'
        return Resolve-MapInCatalog -AppName $AppName -CatalogDir $globalDir `
            -Platform:$Platform -Version:$Version
    }

    $index = @(Get-CatalogIndex -CatalogDir $CatalogDir)
    if ($index.Count -eq 0) { return $null }

    $candidates = @($index | Where-Object { $_.name -eq $AppName })
    if ($Platform) { $candidates = @($candidates | Where-Object { $_.platform -eq $Platform }) }
    if ($Version)  { $candidates = @($candidates | Where-Object { $_.version -eq $Version }) }

    if ($candidates.Count -eq 0) { return $null }

    # Pick the most recent by capturedAt
    $best = $candidates | Sort-Object -Property capturedAt -Descending | Select-Object -First 1
    $fullPath = Join-Path $CatalogDir $best.path

    if (-not (Test-Path $fullPath)) { return $null }
    return $fullPath
}

function Export-AppMap {
    <# Copy an app-map from the project-local catalog to the global catalog. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AppName,
        [ValidateSet('Global')][string]$To = 'Global'
    )
    $srcDir = Get-CatalogDir -Scope 'Project'
    $dstDir = Get-CatalogDir -Scope $To
    $srcPath = Resolve-MapInCatalog -AppName $AppName -CatalogDir $srcDir
    if (-not $srcPath) { throw "No map found for '$AppName' in project catalog." }
    $map = Get-Content $srcPath -Raw | ConvertFrom-Json
    Add-MapToCatalog -Map $map -CatalogDir $dstDir
    Write-Host "Exported '$AppName' map to $dstDir"
}

function Import-AppMap {
    <# Copy an app-map from the global catalog into the project-local catalog. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AppName,
        [ValidateSet('Global')][string]$From = 'Global'
    )
    $srcDir = Get-CatalogDir -Scope $From
    $dstDir = Get-CatalogDir -Scope 'Project'
    $srcPath = Resolve-MapInCatalog -AppName $AppName -CatalogDir $srcDir
    if (-not $srcPath) { throw "No map found for '$AppName' in global catalog." }
    $map = Get-Content $srcPath -Raw | ConvertFrom-Json
    Add-MapToCatalog -Map $map -CatalogDir $dstDir
    Write-Host "Imported '$AppName' map to $dstDir"
}

function Import-SeedCatalog {
    <# Merge the repo's seed catalog into a user catalog directory.
       Copies maps that don't already exist; adds missing index entries. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SeedDir,
        [Parameter(Mandatory)][string]$CatalogDir
    )

    if (-not (Test-Path $SeedDir)) { return 0 }
    if (-not (Test-Path $CatalogDir)) {
        New-Item -ItemType Directory -Force -Path $CatalogDir | Out-Null
    }

    $seedIndex = Get-CatalogIndex -CatalogDir $SeedDir
    $userIndex = [System.Collections.Generic.List[object]]::new()
    $existingIndex = Get-CatalogIndex -CatalogDir $CatalogDir
    foreach ($entry in $existingIndex) { $userIndex.Add($entry) }

    $imported = 0
    foreach ($entry in $seedIndex) {
        $srcFile = Join-Path $SeedDir $entry.path
        $dstFile = Join-Path $CatalogDir $entry.path

        # Skip if already exists in user catalog
        $exists = $existingIndex | Where-Object { $_.path -eq $entry.path }
        if ($exists) { continue }

        if (Test-Path $srcFile) {
            Copy-Item -Path $srcFile -Destination $dstFile -Force
            $userIndex.Add($entry)
            $imported++
        }
    }

    if ($imported -gt 0) {
        $indexPath = Join-Path $CatalogDir 'index.json'
        ($userIndex | ConvertTo-Json -Depth 5) | Set-Content -Path $indexPath -Encoding UTF8
    }

    return $imported
}
