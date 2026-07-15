#Requires -Version 7
<#
.SYNOPSIS
  Validate ContinuityOps S4 alerts.yaml schema (repo-only).
#>
[CmdletBinding()]
param(
    [string]$Root = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Root) {
    $Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
}

$alertsPath = Join-Path $Root 'observability/alerts/alerts.yaml'
$failures = [System.Collections.Generic.List[string]]::new()

$requiredAlertFields = @(
    'name',
    'description',
    'owner',
    'severity',
    'runbook',
    'dedupe',
    'condition',
    'recovery_condition'
)

$requiredDedupeFields = @('key', 'window')
$requiredRecoveryFields = @('comparator', 'for')

function Add-Failure {
    param([string]$Message)
    $failures.Add($Message)
}

function Parse-SimpleYamlMap {
    param([string[]]$Lines, [int]$StartIndex)

    $map = [ordered]@{}
    $i = $StartIndex
    $baseIndent = ($Lines[$StartIndex] -replace '(\S.*)$', '').Length

    while ($i -lt $Lines.Count) {
        $line = $Lines[$i]
        if ($line -match '^\s*$') {
            $i++
            continue
        }

        $indent = ($line -replace '(\S.*)$', '').Length
        if ($indent -lt $baseIndent) {
            break
        }
        if ($indent -gt $baseIndent) {
            $i++
            continue
        }

        if ($line -match '^\s*-\s+id:\s*(.+)$') {
            break
        }

        if ($line -match '^\s*([A-Za-z0-9_]+):\s*(.*)$') {
            $key = $Matches[1]
            $value = $Matches[2].Trim()
            if ($value -eq '' -or $value -eq '>') {
                $map[$key] = $null
            }
            else {
                $map[$key] = $value.Trim('"').Trim("'")
            }
        }

        $i++
    }

    return [pscustomobject]@{
        Map = $map
        NextIndex = $i
    }
}

function Get-AlertBlocks {
    param([string[]]$Lines)

    $blocks = [System.Collections.Generic.List[hashtable]]::new()
    $current = $null
    $currentLines = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $Lines) {
        if ($line -match '^\s*-\s+id:\s*(.+)$') {
            if ($null -ne $current) {
                $blocks.Add(@{
                    Id = $current
                    Lines = $currentLines.ToArray()
                })
            }
            $current = $Matches[1].Trim().Trim('"').Trim("'")
            $currentLines = [System.Collections.Generic.List[string]]::new()
            $currentLines.Add($line)
            continue
        }

        if ($null -ne $current) {
            $currentLines.Add($line)
        }
    }

    if ($null -ne $current) {
        $blocks.Add(@{
            Id = $current
            Lines = $currentLines.ToArray()
        })
    }

    return $blocks
}

function Get-NestedSection {
    param(
        [string[]]$Lines,
        [string]$SectionName
    )

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match "^\s*${SectionName}:\s*$") {
            return Parse-SimpleYamlMap -Lines $Lines -StartIndex ($i + 1)
        }
    }

    return $null
}

if (-not (Test-Path -LiteralPath $alertsPath)) {
    Add-Failure "missing file: observability/alerts/alerts.yaml"
}
else {
  $raw = Get-Content -LiteralPath $alertsPath -Raw
  if ($raw -match '(?m)^\t') {
      Add-Failure 'alerts.yaml must not use tab indentation'
  }

  $lines = Get-Content -LiteralPath $alertsPath
  $hasVersion = $false
  $hasAlertsList = $false
  foreach ($line in $lines) {
      if ($line -match '^\s*version:\s*') { $hasVersion = $true }
      if ($line -match '^\s*alerts:\s*$') { $hasAlertsList = $true }
  }
  if (-not $hasVersion) {
      Add-Failure 'alerts.yaml missing top-level version'
  }
  if (-not $hasAlertsList) {
      Add-Failure 'alerts.yaml missing top-level alerts list'
  }

  $blocks = Get-AlertBlocks -Lines $lines
  if ($blocks.Count -eq 0) {
      Add-Failure 'alerts.yaml contains no alert entries'
  }

  $seenIds = @{}
  foreach ($block in $blocks) {
      $id = $block.Id
      if ($seenIds.ContainsKey($id)) {
          Add-Failure "duplicate alert id: $id"
      }
      else {
          $seenIds[$id] = $true
      }

      $blockLines = $block.Lines
      if ([string]::IsNullOrWhiteSpace($id)) {
          Add-Failure 'alert block missing id on list item (- id:)'
      }

      foreach ($field in $requiredAlertFields) {
          $pattern = "^\s*${field}:"
          $found = $false
          foreach ($line in $blockLines) {
              if ($line -match $pattern) {
                  $found = $true
                  break
              }
          }
          if (-not $found) {
              Add-Failure "alert '$id' missing required field: $field"
          }
      }

      $severityOk = $false
      foreach ($line in $blockLines) {
          if ($line -match '^\s*severity:\s*(SEV-[1-4])\s*$') {
              $severityOk = $true
              break
          }
      }
      if (-not $severityOk) {
          Add-Failure "alert '$id' severity must be SEV-1 .. SEV-4"
      }

      $dedupe = Get-NestedSection -Lines $blockLines -SectionName 'dedupe'
      if ($null -eq $dedupe) {
          Add-Failure "alert '$id' missing dedupe section"
      }
      else {
          foreach ($df in $requiredDedupeFields) {
              if (-not $dedupe.Map.Contains($df)) {
                  Add-Failure "alert '$id' dedupe missing: $df"
              }
          }
      }

      $recovery = Get-NestedSection -Lines $blockLines -SectionName 'recovery_condition'
      if ($null -eq $recovery) {
          Add-Failure "alert '$id' missing recovery_condition section"
      }
      else {
          foreach ($rf in $requiredRecoveryFields) {
              if (-not $recovery.Map.Contains($rf)) {
                  Add-Failure "alert '$id' recovery_condition missing: $rf"
              }
          }
      }

      $runbookLine = $blockLines | Where-Object { $_ -match '^\s*runbook:\s*(.+)$' } | Select-Object -First 1
      if ($runbookLine -match '^\s*runbook:\s*(.+)$') {
          $runbook = $Matches[1].Trim()
          if ($runbook -match '(?i)(password|secret|api[_-]?key|token)\s*=') {
              Add-Failure "alert '$id' runbook appears to contain secret material"
          }
          if ($runbook.Length -lt 3) {
              Add-Failure "alert '$id' runbook is empty"
          }
      }
  }
}

if ($failures.Count -gt 0) {
    Write-Error ("Test-AlertSchema failed:`n - " + ($failures -join "`n - "))
}

Write-Host "Test-AlertSchema: $($blocks.Count) alerts validated."
