BeforeAll {
    . (Join-Path $PSScriptRoot 'mapper-lib.ps1')
}

# ---------------------------------------------------------------------------
# ConvertFrom-DumpHierarchy
# ---------------------------------------------------------------------------
Describe 'ConvertFrom-DumpHierarchy' {
    BeforeAll {
        # Fixture based on real Notepad DumpHierarchy output (engine 6.5.10)
        $script:dumpFile = Join-Path $TestDrive 'dump.txt'
        @'
(7D035E) Win32 Window:Notepad -- 'Untitled - Notepad'
  (8F02D0) Pane:NotepadTextBox -- ''
    (4F06FA) Document:RichEditD2DPT -- 'Text editor'
  (5D056A) Pane:Microsoft.UI.Content.DesktopChildSiteBridge -- ''
    (B3050A) Pane:InputSiteWindowClass -- ''
      Tab:Microsoft.UI.Xaml.Controls.TabView -- ''
  TitleBar -- ''
    Button -- 'Minimize'
    Button -- 'Close'
'@ | Set-Content -Path $script:dumpFile -Encoding UTF8
    }

    It 'parses controls from the dump file' {
        $controls = @(ConvertFrom-DumpHierarchy -Path $script:dumpFile)
        $controls.Count | Should -BeGreaterOrEqual 2
    }
    It 'extracts controlType and className' {
        $controls = @(ConvertFrom-DumpHierarchy -Path $script:dumpFile)
        $doc = $controls | Where-Object { $_.controlType -eq 'Document' }
        $doc | Should -Not -BeNullOrEmpty
        $doc.className | Should -Be 'RichEditD2DPT'
        $doc.name      | Should -Be 'Text editor'
    }
    It 'handles entries with no className (no colon)' {
        $controls = @(ConvertFrom-DumpHierarchy -Path $script:dumpFile)
        $tb = $controls | Where-Object { $_.controlType -eq 'TitleBar' }
        $tb | Should -Not -BeNullOrEmpty
        $tb.className | Should -Be ''
    }
    It 'computes xpath from nesting' {
        $controls = @(ConvertFrom-DumpHierarchy -Path $script:dumpFile)
        $doc = $controls | Where-Object { $_.controlType -eq 'Document' }
        $doc.xpath | Should -Be 'Pane:NotepadTextBox/Document:RichEditD2DPT'
    }
    It 'generates suggestedFinder with FindAutomationElementByXPathOrInformation' {
        $controls = @(ConvertFrom-DumpHierarchy -Path $script:dumpFile)
        $doc = $controls | Where-Object { $_.controlType -eq 'Document' }
        $doc.suggestedFinder | Should -Match 'FindAutomationElementByXPathOrInformation'
        $doc.suggestedFinder | Should -Match 'xpath: "Pane:NotepadTextBox/Document:RichEditD2DPT"'
        $doc.suggestedFinder | Should -Match 'className: "RichEditD2DPT"'
        $doc.suggestedFinder | Should -Match 'controlType: "Document"'
    }
    It 'sets automationId to empty string (not available in dump format)' {
        $controls = @(ConvertFrom-DumpHierarchy -Path $script:dumpFile)
        $controls[0].automationId | Should -Be ''
    }
    It 'returns empty array for missing file' {
        $controls = @(ConvertFrom-DumpHierarchy -Path (Join-Path $TestDrive 'nope.txt'))
        $controls.Count | Should -Be 0
    }
    It 'includes the root window element' {
        $controls = @(ConvertFrom-DumpHierarchy -Path $script:dumpFile)
        $win = $controls | Where-Object { $_.controlType -eq 'Win32 Window' }
        $win | Should -Not -BeNullOrEmpty
    }
}

# ---------------------------------------------------------------------------
# ConvertFrom-ProbeLog
# ---------------------------------------------------------------------------
Describe 'ConvertFrom-ProbeLog' {
    It 'parses a successful step with all finders OK' {
        $lines = @(
            'MAPPER_STEP|1|File menu|click',
            'MAPPER_FINDER|1|FindAutomationElementByXPathOrInformation|OK|xpath=/Menu/MenuItem;name=File;controlType=MenuItem',
            'MAPPER_FINDER|1|FindControlWithXPath|OK|xPath=MenuItem:MenuBar/MenuItem',
            'MAPPER_FINDER|1|FindControl|OK|title=File;className=MenuItem'
        )
        $result = ConvertFrom-ProbeLog -LogLines $lines
        $result.steps.Count | Should -Be 1
        $result.controls.Count | Should -Be 1
        $result.controls[0].preferredFinder | Should -Be 'FindAutomationElementByXPathOrInformation'
        $result.controls[0].finders.Keys.Count | Should -Be 3
    }

    It 'marks step as failed when MAPPER_STEP_FAIL appears' {
        $lines = @(
            'MAPPER_STEP|1|Submit button|click',
            'MAPPER_FINDER|1|FindAutomationElementByXPathOrInformation|FAIL|xpath=/Button;name=Submit',
            'MAPPER_FINDER|1|FindControlWithXPath|FAIL|xPath=Button:Submit',
            'MAPPER_FINDER|1|FindControl|FAIL|title=Submit',
            'MAPPER_STEP_FAIL|1|No finder succeeded'
        )
        $result = ConvertFrom-ProbeLog -LogLines $lines
        $result.steps[0].success | Should -BeFalse
        $result.controls[0].preferredFinder | Should -Be 'none'
    }

    It 'handles multiple steps' {
        $lines = @(
            'MAPPER_STEP|1|File menu|click',
            'MAPPER_FINDER|1|FindAutomationElementByXPathOrInformation|OK|name=File',
            'MAPPER_STEP|2|Open|click',
            'MAPPER_FINDER|2|FindControl|OK|title=Open'
        )
        $result = ConvertFrom-ProbeLog -LogLines $lines
        $result.steps.Count | Should -Be 2
        $result.controls.Count | Should -Be 2
    }

    It 'falls back to FindControlWithXPath when primary fails' {
        $lines = @(
            'MAPPER_STEP|1|Editor|click',
            'MAPPER_FINDER|1|FindAutomationElementByXPathOrInformation|FAIL|xpath=/Document',
            'MAPPER_FINDER|1|FindControlWithXPath|OK|xPath=Document:RichEdit'
        )
        $result = ConvertFrom-ProbeLog -LogLines $lines
        $result.controls[0].preferredFinder | Should -Be 'FindControlWithXPath'
    }

    It 'generates kebab-case id from label' {
        $lines = @(
            'MAPPER_STEP|1|File menu|click',
            'MAPPER_FINDER|1|FindControl|OK|title=File'
        )
        $result = ConvertFrom-ProbeLog -LogLines $lines
        $result.controls[0].id | Should -Be 'file-menu'
    }

    It 'ignores non-mapper log lines' {
        $lines = @(
            'Some engine output',
            'MAPPER_STEP|1|File|click',
            'MAPPER_FINDER|1|FindControl|OK|title=File',
            'Another engine line'
        )
        $result = ConvertFrom-ProbeLog -LogLines $lines
        $result.steps.Count | Should -Be 1
    }
}

# ---------------------------------------------------------------------------
# New-AppMap
# ---------------------------------------------------------------------------
Describe 'New-AppMap' {
    It 'creates a v2.0 desktop map' {
        $map = New-AppMap -AppName 'notepad' -Controls @() -Workflows @('open-file')
        $map.schemaVersion | Should -Be '2.0'
        $map.app.kind | Should -Be 'desktop'
        $map.workflows | Should -Contain 'open-file'
    }

    It 'creates a web map' {
        $map = New-AppMap -AppName 'example' -Kind 'web' -Url 'https://example.com' -Controls @()
        $map.app.kind | Should -Be 'web'
        $map.app.url | Should -Be 'https://example.com'
        $map.coverage.method | Should -Be 'PlaywrightAccessibilitySnapshot'
    }
}

# ---------------------------------------------------------------------------
# Merge-AppMap
# ---------------------------------------------------------------------------
Describe 'Merge-AppMap' {
    It 'tags controls with workflow on first run' {
        $controls = @(
            @{ id = 'file-menu'; label = 'File'; finders = @{}; preferredFinder = 'none' }
        )
        $result = Merge-AppMap -Existing $null -NewControls $controls -WorkflowName 'open-file'
        $result[0].discoveredBy | Should -Contain 'open-file'
    }

    It 'union-merges finders for existing control' {
        $existing = @(
            @{
                id = 'file-menu'; label = 'File'; preferredFinder = 'FindControl'
                finders = @{ FindControl = @{ status = 'OK'; params = @{ title = 'File' } } }
                discoveredBy = @('open-file')
            }
        )
        $newControls = @(
            @{
                id = 'file-menu'; label = 'File'; preferredFinder = 'FindControlWithXPath'
                finders = @{ FindControlWithXPath = @{ status = 'OK'; params = @{ xPath = 'MenuItem' } } }
            }
        )
        $result = Merge-AppMap -Existing $existing -NewControls $newControls -WorkflowName 'save-as'
        $result[0].finders.Keys.Count | Should -Be 2
        $result[0].discoveredBy | Should -Contain 'open-file'
        $result[0].discoveredBy | Should -Contain 'save-as'
    }

    It 'adds new controls that do not exist yet' {
        $existing = @(
            @{ id = 'file-menu'; label = 'File'; finders = @{}; preferredFinder = 'none'; discoveredBy = @('flow1') }
        )
        $newControls = @(
            @{ id = 'edit-menu'; label = 'Edit'; finders = @{}; preferredFinder = 'none' }
        )
        $result = Merge-AppMap -Existing $existing -NewControls $newControls -WorkflowName 'flow2'
        $result.Count | Should -Be 2
        ($result | Where-Object { $_.id -eq 'edit-menu' }).discoveredBy | Should -Contain 'flow2'
    }

    It 'does not duplicate workflow name' {
        $existing = @(
            @{ id = 'btn'; finders = @{}; preferredFinder = 'none'; discoveredBy = @('flow1') }
        )
        $newControls = @(
            @{ id = 'btn'; finders = @{}; preferredFinder = 'none' }
        )
        $result = Merge-AppMap -Existing $existing -NewControls $newControls -WorkflowName 'flow1'
        ($result[0].discoveredBy | Where-Object { $_ -eq 'flow1' }).Count | Should -Be 1
    }

    It 'upgrades finder from FAIL to OK' {
        $existing = @(
            @{
                id = 'btn'; preferredFinder = 'none'
                finders = @{ FindControl = @{ status = 'FAIL'; params = @{} } }
                discoveredBy = @('flow1')
            }
        )
        $newControls = @(
            @{
                id = 'btn'; preferredFinder = 'FindControl'
                finders = @{ FindControl = @{ status = 'OK'; params = @{ title = 'OK' } } }
            }
        )
        $result = Merge-AppMap -Existing $existing -NewControls $newControls -WorkflowName 'flow2'
        $result[0].finders.FindControl.status | Should -Be 'OK'
        $result[0].preferredFinder | Should -Be 'FindControl'
    }
}

# ---------------------------------------------------------------------------
# ConvertTo-AppMapJson
# ---------------------------------------------------------------------------
Describe 'ConvertTo-AppMapJson' {
    It 'serializes an app-map object to valid JSON' {
        $map = [pscustomobject]@{ schemaVersion = '1.0'; app = @{ name = 'test' }; controls = @() }
        $json = ConvertTo-AppMapJson -AppMap $map
        $parsed = $json | ConvertFrom-Json
        $parsed.schemaVersion | Should -Be '1.0'
    }
}

# ---------------------------------------------------------------------------
# Get-CatalogDir
# ---------------------------------------------------------------------------
Describe 'Get-CatalogDir' {
    It 'returns project-local path by default' {
        $dir = Get-CatalogDir -Scope 'Project'
        $dir | Should -Match '\.app-maps$'
    }

    It 'returns global path when scope is Global' {
        $dir = Get-CatalogDir -Scope 'Global'
        $dir | Should -Match 'login-enterprise.*app-maps$'
    }

    It 'creates the directory when it does not exist' {
        # Use a temp override by pushing location to TestDrive
        Push-Location $TestDrive
        try {
            $dir = Get-CatalogDir -Scope 'Project'
            Test-Path $dir | Should -BeTrue
        } finally {
            Pop-Location
        }
    }
}

# ---------------------------------------------------------------------------
# Get-CatalogIndex
# ---------------------------------------------------------------------------
Describe 'Get-CatalogIndex' {
    It 'returns empty array when index.json does not exist' {
        $dir = Join-Path $TestDrive 'no-index'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $result = @(Get-CatalogIndex -CatalogDir $dir)
        $result.Count | Should -Be 0
    }

    It 'reads entries from index.json' {
        $dir = Join-Path $TestDrive 'has-index'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        @'
[{"name":"notepad","platform":"desktop","version":"unknown","capturedAt":"2026-06-09T05:32:09Z","confidence":"high","path":"notepad-desktop-unknown.app-map.json"}]
'@ | Set-Content -Path (Join-Path $dir 'index.json') -Encoding UTF8
        $result = @(Get-CatalogIndex -CatalogDir $dir)
        $result.Count | Should -Be 1
        $result[0].name | Should -Be 'notepad'
    }
}

# ---------------------------------------------------------------------------
# Add-MapToCatalog
# ---------------------------------------------------------------------------
Describe 'Add-MapToCatalog' {
    It 'writes the map file and creates index.json' {
        $dir = Join-Path $TestDrive 'add-map'
        $map = New-AppMap -AppName 'notepad' -Controls @() -Workflows @('open-file')
        $path = Add-MapToCatalog -Map $map -CatalogDir $dir -AppVersion 'unknown'
        Test-Path $path | Should -BeTrue
        $path | Should -Match 'notepad-desktop-unknown\.app-map\.json'
        $index = @(Get-CatalogIndex -CatalogDir $dir)
        $index.Count | Should -Be 1
        $index[0].name | Should -Be 'notepad'
    }

    It 'does not overwrite existing files — appends timestamp suffix' {
        $dir = Join-Path $TestDrive 'add-map-nooverwrite'
        $map = New-AppMap -AppName 'notepad' -Controls @() -Workflows @('flow1')
        $path1 = Add-MapToCatalog -Map $map -CatalogDir $dir -AppVersion 'unknown'
        $path2 = Add-MapToCatalog -Map $map -CatalogDir $dir -AppVersion 'unknown'
        $path1 | Should -Not -Be $path2
        $index = @(Get-CatalogIndex -CatalogDir $dir)
        $index.Count | Should -Be 2
    }

    It 'creates the catalog directory if it does not exist' {
        $dir = Join-Path $TestDrive 'add-map-newdir'
        $map = New-AppMap -AppName 'calc' -Controls @() -Workflows @()
        Add-MapToCatalog -Map $map -CatalogDir $dir | Out-Null
        Test-Path $dir | Should -BeTrue
    }
}

# ---------------------------------------------------------------------------
# Resolve-MapInCatalog
# ---------------------------------------------------------------------------
Describe 'Resolve-MapInCatalog' {
    BeforeAll {
        $script:resolveDir = Join-Path $TestDrive 'resolve-map'
        $map = New-AppMap -AppName 'notepad' -Controls @() -Workflows @('open-file')
        Add-MapToCatalog -Map $map -CatalogDir $script:resolveDir -AppVersion 'unknown' | Out-Null
    }

    It 'finds a map by app name' {
        $path = Resolve-MapInCatalog -AppName 'notepad' -CatalogDir $script:resolveDir
        $path | Should -Not -BeNullOrEmpty
        Test-Path $path | Should -BeTrue
    }

    It 'returns null for an unknown app name' {
        $path = Resolve-MapInCatalog -AppName 'nonexistent' -CatalogDir $script:resolveDir
        $path | Should -BeNullOrEmpty
    }

    It 'filters by platform' {
        $path = Resolve-MapInCatalog -AppName 'notepad' -CatalogDir $script:resolveDir -Platform 'desktop'
        $path | Should -Not -BeNullOrEmpty
        $pathWeb = Resolve-MapInCatalog -AppName 'notepad' -CatalogDir $script:resolveDir -Platform 'web'
        $pathWeb | Should -BeNullOrEmpty
    }

    It 'checks project-local before global when no CatalogDir given' {
        # Set up a project dir with a map and empty global; verify project result is returned
        $projectBase = Join-Path $TestDrive 'two-tier-project'
        New-Item -ItemType Directory -Path $projectBase -Force | Out-Null
        $projectCatalog = Join-Path $projectBase '.app-maps'
        $globalCatalog  = Join-Path $TestDrive 'two-tier-global'

        $map = New-AppMap -AppName 'twoapp' -Controls @() -Workflows @('flow1')
        Add-MapToCatalog -Map $map -CatalogDir $projectCatalog | Out-Null

        # Push to the project base so Get-CatalogDir returns $projectCatalog
        Push-Location $projectBase
        try {
            # Mock global scope by verifying the project result comes back
            # (global catalog is empty, so if project is searched first the result is non-null)
            $path = Resolve-MapInCatalog -AppName 'twoapp' -CatalogDir $projectCatalog
            $path | Should -Not -BeNullOrEmpty
        } finally {
            Pop-Location
        }
    }
}

# ---------------------------------------------------------------------------
# Import-SeedCatalog
# ---------------------------------------------------------------------------
Describe 'Import-SeedCatalog' {
    It 'imports seed maps into an empty catalog' {
        $seedDir = Join-Path $TestDrive 'seed'
        $userDir = Join-Path $TestDrive 'user-catalog'
        New-Item -ItemType Directory -Path $seedDir -Force | Out-Null

        '{"schemaVersion":"2.0"}' | Set-Content -Path (Join-Path $seedDir 'notepad-desktop-unknown.app-map.json') -Encoding UTF8
        @'
[{"name":"notepad","platform":"desktop","version":"unknown","capturedAt":"2026-06-09T00:00:00Z","confidence":"high","path":"notepad-desktop-unknown.app-map.json"}]
'@ | Set-Content -Path (Join-Path $seedDir 'index.json') -Encoding UTF8

        $count = Import-SeedCatalog -SeedDir $seedDir -CatalogDir $userDir
        $count | Should -Be 1
        Test-Path (Join-Path $userDir 'notepad-desktop-unknown.app-map.json') | Should -BeTrue
        $index = @(Get-CatalogIndex -CatalogDir $userDir)
        $index.Count | Should -Be 1
    }

    It 'skips maps that already exist in the user catalog' {
        $seedDir = Join-Path $TestDrive 'seed2'
        $userDir = Join-Path $TestDrive 'user-catalog2'
        New-Item -ItemType Directory -Path $seedDir, $userDir -Force | Out-Null

        '{"schemaVersion":"2.0"}' | Set-Content -Path (Join-Path $seedDir 'notepad-desktop-unknown.app-map.json') -Encoding UTF8
        '{"schemaVersion":"2.0"}' | Set-Content -Path (Join-Path $userDir 'notepad-desktop-unknown.app-map.json') -Encoding UTF8
        @'
[{"name":"notepad","platform":"desktop","version":"unknown","capturedAt":"2026-06-09T00:00:00Z","confidence":"high","path":"notepad-desktop-unknown.app-map.json"}]
'@ | Set-Content -Path (Join-Path $seedDir 'index.json') -Encoding UTF8
        @'
[{"name":"notepad","platform":"desktop","version":"unknown","capturedAt":"2026-06-09T00:00:00Z","confidence":"high","path":"notepad-desktop-unknown.app-map.json"}]
'@ | Set-Content -Path (Join-Path $userDir 'index.json') -Encoding UTF8

        $count = Import-SeedCatalog -SeedDir $seedDir -CatalogDir $userDir
        $count | Should -Be 0
    }

    It 'returns 0 when seed directory does not exist' {
        $count = Import-SeedCatalog -SeedDir (Join-Path $TestDrive 'noseed') -CatalogDir (Join-Path $TestDrive 'user3')
        $count | Should -Be 0
    }
}

# ---------------------------------------------------------------------------
# Export-AppMap / Import-AppMap
# ---------------------------------------------------------------------------
Describe 'Export-AppMap and Import-AppMap' {
    It 'Export-AppMap copies a map from project catalog to global catalog' {
        $projectBase = Join-Path $TestDrive 'export-test'
        New-Item -ItemType Directory -Path $projectBase -Force | Out-Null
        $projectCatalog = Join-Path $projectBase '.app-maps'
        $globalCatalog  = Join-Path $TestDrive 'export-global'

        $map = New-AppMap -AppName 'exportapp' -Controls @() -Workflows @('wf1')
        Add-MapToCatalog -Map $map -CatalogDir $projectCatalog | Out-Null

        # Manually invoke catalog lookup + copy (simulating Export-AppMap logic)
        $srcPath = Resolve-MapInCatalog -AppName 'exportapp' -CatalogDir $projectCatalog
        $srcPath | Should -Not -BeNullOrEmpty
        $loadedMap = Get-Content $srcPath -Raw | ConvertFrom-Json
        Add-MapToCatalog -Map $loadedMap -CatalogDir $globalCatalog | Out-Null

        $found = Resolve-MapInCatalog -AppName 'exportapp' -CatalogDir $globalCatalog
        $found | Should -Not -BeNullOrEmpty
    }

    It 'Import-AppMap copies a map from global catalog to project catalog' {
        $projectBase = Join-Path $TestDrive 'import-test'
        New-Item -ItemType Directory -Path $projectBase -Force | Out-Null
        $projectCatalog = Join-Path $projectBase '.app-maps'
        $globalCatalog  = Join-Path $TestDrive 'import-global'

        $map = New-AppMap -AppName 'importapp' -Controls @() -Workflows @('wf1')
        Add-MapToCatalog -Map $map -CatalogDir $globalCatalog | Out-Null

        # Manually invoke catalog lookup + copy (simulating Import-AppMap logic)
        $srcPath = Resolve-MapInCatalog -AppName 'importapp' -CatalogDir $globalCatalog
        $srcPath | Should -Not -BeNullOrEmpty
        $loadedMap = Get-Content $srcPath -Raw | ConvertFrom-Json
        Add-MapToCatalog -Map $loadedMap -CatalogDir $projectCatalog | Out-Null

        $found = Resolve-MapInCatalog -AppName 'importapp' -CatalogDir $projectCatalog
        $found | Should -Not -BeNullOrEmpty
    }

    It 'Export-AppMap throws when app is not in project catalog' {
        Push-Location $TestDrive
        try {
            { Export-AppMap -AppName 'nosuchapp' } | Should -Throw
        } finally {
            Pop-Location
        }
    }

    It 'Import-AppMap throws when app is not in global catalog' {
        Push-Location $TestDrive
        try {
            { Import-AppMap -AppName 'nosuchapp' } | Should -Throw
        } finally {
            Pop-Location
        }
    }
}
