<#
.SYNOPSIS
    Mechanical consistency checks for this kit. Run locally before finishing a
    change; run in CI on every push/PR (.github/workflows/verify.yml calls it).

.DESCRIPTION
    Every check here exists because the corresponding failure was actually
    observed in a shipped kit, not because it sounded prudent:

      1. Generator drift      — .claude/rules, .cursor/rules and .claude/commands
                                out of sync with .agents/ because someone edited a
                                generated copy, or forgot to re-run the generator.
      2. Cursor extension     — a rule written as .md under .cursor/rules, which
                                Cursor silently ignores (cursor.com/docs/rules).
      3. Claude skill links   — .claude/skills/ missing an entry, i.e. Claude Code
                                discovering none of this kit's skills.
      4. SKILL.md frontmatter — a `name` the Agent Skills spec rejects (anything
                                but lowercase/digits/hyphen), a missing or
                                over-long `description`.
      5. Unfilled placeholders— a literal [FILL IN marker shipped to users. The
                                .specify/ templates are exempt: their placeholders
                                are the product.
      6. Dead image links     — README embedding docs/images/*.png that isn't there.
      7. LICENSE presence     — a README license badge with no LICENSE file.

    Exits non-zero if any check fails, printing every failure rather than
    stopping at the first one.

.NOTES
    Needs PowerShell 7+ and git. Safe to run repeatedly; changes nothing except
    regenerating the generated folders (which is the point of check 1).
#>

param(
    # In CI the generator must not leave the tree dirty. Locally you may want the
    # regeneration itself to be the fix, so drift is reported but not fatal.
    [switch]$SkipDriftCheck
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

# Is this the unfilled blank scaffold rather than a real kit? In the scaffold,
# placeholders ARE the product and the banner PNGs cannot exist yet (they are
# generated per kit from Prompts/image-prompts.md). Failing on either there
# would mean the template can never be green, which trains people to ignore the
# gate. Both stay hard failures in a real kit.
#
# Identify it by DIRECTORY NAME, not by content. The first version matched
# "[Project Name]" on README.md's first line, which inverted the check exactly
# where it mattered: a real kit whose author forgot to fill in the README title
# was declared a scaffold, and the placeholder and banner gates -- the two that
# would have caught that very omission -- switched themselves off. A kit is
# never named blank-scaffold, so this cannot misfire the same way.
$IsScaffold = (Split-Path -Leaf $RepoRoot) -eq 'blank-scaffold'
if ($IsScaffold) {
    Write-Host "Detected the unfilled blank scaffold: placeholder and banner checks are advisory here." -ForegroundColor Cyan
}

function Add-Failure { param([string]$Check, [string]$Detail) $script:failures.Add("[$Check] $Detail") }
function Add-Warning { param([string]$Check, [string]$Detail) $script:warnings.Add("[$Check] $Detail") }
function Write-Section { param([string]$Name) Write-Host ""; Write-Host "== $Name" -ForegroundColor Cyan }

function Get-FrontmatterValue {
    <#
      Reads one frontmatter key, handling BLOCK SCALARS.

      This function exists because the naive '^description:\s*(.+)$' regex it
      replaces measured a folded value as its indicator: for

          description: >-
            Searches for and recommends ...

      it captured ">-" and reported the description as 2 characters long. Every
      SKILL.md written that way sailed through the length check unmeasured --
      including the one this repo deliberately converted to a folded scalar to
      fix a YAML parse failure. The check silently stopped checking the file it
      had just been used on.

      PowerShell ships no YAML parser, and pulling one in for two fields is not
      worth it. This handles what a SKILL.md frontmatter actually uses: plain
      inline scalars, quoted scalars, and the block forms | > |- >- |+ >+.
    #>
    param(
        [Parameter(Mandatory)] [string[]]$FrontmatterLines,
        [Parameter(Mandatory)] [string]$Key
    )

    for ($i = 0; $i -lt $FrontmatterLines.Count; $i++) {
        if ($FrontmatterLines[$i] -notmatch "^$([regex]::Escape($Key)):(.*)$") { continue }
        $rest = $Matches[1].Trim()

        # Inline scalar: return it, unquoted.
        if ($rest -notmatch '^[|>]([+-]?\d*|\d*[+-]?)$') {
            return $rest.Trim().Trim('"').Trim("'")
        }

        # Block scalar: collect the more-indented lines that follow.
        $fold = $rest.StartsWith('>')
        $body = [System.Collections.Generic.List[string]]::new()
        for ($j = $i + 1; $j -lt $FrontmatterLines.Count; $j++) {
            $line = $FrontmatterLines[$j]
            if ($line.Trim() -eq '') { $body.Add(''); continue }
            if ($line -notmatch '^\s') { break }   # dedented: block ended
            $body.Add($line.TrimStart())
        }
        while ($body.Count -gt 0 -and $body[$body.Count - 1] -eq '') { $body.RemoveAt($body.Count - 1) }

        if ($fold) {
            # Folded: single newlines become spaces, blank lines become newlines.
            $out = ''
            foreach ($l in $body) {
                if ($l -eq '') { $out = $out.TrimEnd() + "`n" }
                elseif ($out -eq '' -or $out.EndsWith("`n")) { $out += $l }
                else { $out += ' ' + $l }
            }
            return $out.Trim()
        }
        return ($body -join "`n").Trim()
    }
    return $null
}

# --- 1. Generator drift -------------------------------------------------------
Write-Section "Generator drift"
if ($SkipDriftCheck) {
    Write-Host "  skipped (-SkipDriftCheck)"
} else {
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'generate-ai-configs.ps1') | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Add-Failure 'drift' "generate-ai-configs.ps1 exited $LASTEXITCODE"
    } else {
        # --porcelain is empty exactly when the working tree matches HEAD.
        $dirty = @(git -C $RepoRoot status --porcelain -- .claude .cursor 2>$null)
        if ($dirty.Count -gt 0) {
            Add-Failure 'drift' "generated files differ from committed ones — run 'pwsh tools/generate-ai-configs.ps1' and commit the result:`n    $($dirty -join "`n    ")"
        } else {
            Write-Host "  OK — generated copies match .agents/"
        }
    }
}

# --- 2. Cursor rule extension -------------------------------------------------
Write-Section "Cursor rule extension"
$cursorRules = Join-Path $RepoRoot '.cursor/rules'
if (Test-Path $cursorRules) {
    $wrongExt = @(Get-ChildItem $cursorRules -File -Recurse | Where-Object { $_.Extension -ne '.mdc' })
    if ($wrongExt.Count -gt 0) {
        Add-Failure 'cursor-ext' "Cursor ignores anything but .mdc under .cursor/rules: $($wrongExt.Name -join ', ')"
    } else {
        Write-Host "  OK — $((Get-ChildItem $cursorRules -File).Count) rule(s), all .mdc"
    }
} else {
    Write-Host "  skipped — no .cursor/rules"
}

# --- 3. Claude skill links ----------------------------------------------------
Write-Section "Claude skill discovery"
$agentsSkills = Join-Path $RepoRoot '.agents/skills'
$claudeSkills = Join-Path $RepoRoot '.claude/skills'
if (Test-Path $agentsSkills) {
    $expected = @(Get-ChildItem $agentsSkills -Directory | Select-Object -ExpandProperty Name)
    $actual   = if (Test-Path $claudeSkills) { @(Get-ChildItem $claudeSkills -Directory -Force | Select-Object -ExpandProperty Name) } else { @() }
    $missing  = @($expected | Where-Object { $_ -notin $actual })
    if ($missing.Count -gt 0) {
        Add-Failure 'skill-links' ".claude/skills/ has no entry for: $($missing -join ', ') — Claude Code discovers skills only there, so these would never trigger."
    } else {
        Write-Host "  OK — $($expected.Count) skill(s) reachable under .claude/skills/"
    }
} else {
    Write-Host "  skipped — no .agents/skills"
}

# --- 4. SKILL.md frontmatter --------------------------------------------------
Write-Section "SKILL.md frontmatter"
$skillCount = 0
if (Test-Path $agentsSkills) {
    Get-ChildItem $agentsSkills -Directory | ForEach-Object {
        $md = Join-Path $_.FullName 'SKILL.md'
        if (-not (Test-Path $md)) { Add-Failure 'skill-md' "$($_.Name)/ has no SKILL.md"; return }
        $skillCount++

        $text = Get-Content $md -Raw
        if ($text -notmatch '(?s)^﻿?---\r?\n(.*?)\r?\n---') {
            Add-Failure 'skill-md' "$($_.Name)/SKILL.md has no YAML frontmatter block"
            return
        }
        $fm = $Matches[1]
        $fmLines = $fm -split '\r?\n'
        $folder  = $_.Name

        # Constraints below are the Agent Skills specification's, verified at
        # agentskills.io/specification -- not this repo's own preferences.
        # `skills-ref validate ./<skill>` is the authoritative checker; this is
        # the subset that can run with no extra dependency.
        $name = Get-FrontmatterValue -FrontmatterLines $fmLines -Key 'name'
        if ($null -eq $name -or $name -eq '') {
            Add-Failure 'skill-md' "$folder/SKILL.md frontmatter has no 'name:'"
        } else {
            if ($name.Length -gt 64) {
                Add-Failure 'skill-md' "$folder/SKILL.md name is $($name.Length) chars (spec max 64)"
            }
            # Lowercase alphanumerics and hyphens; no leading, trailing or
            # consecutive hyphens. The pattern encodes all four at once.
            if ($name -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
                Add-Failure 'skill-md' "$folder/SKILL.md name '$name' violates the spec (lowercase a-z/0-9 and single hyphens only; no leading, trailing or consecutive hyphens)"
            }
            # The spec requires name == parent directory name. Without this the
            # two can drift and a tool resolving by name finds nothing.
            if ($name -cne $folder) {
                Add-Failure 'skill-md' "$folder/SKILL.md name '$name' does not match its parent directory '$folder' (the spec requires them to be equal)"
            }
        }

        $desc = Get-FrontmatterValue -FrontmatterLines $fmLines -Key 'description'
        if ($null -eq $desc -or $desc -eq '') {
            Add-Failure 'skill-md' "$folder/SKILL.md frontmatter has no non-empty 'description:' — without it the model cannot trigger the skill"
        } elseif ($desc.Length -gt 1024) {
            # HARD limit, not a preference: the spec states 1-1024 characters.
            # This was previously a warning on the grounds that no ceiling could
            # be found in Claude Code's own docs; the ceiling is in the Agent
            # Skills spec, which is the document this kit's skills claim to
            # follow.
            Add-Failure 'skill-md' "$folder/SKILL.md description is $($desc.Length) chars (spec max 1024)"
        }
    }
    Write-Host "  checked $skillCount SKILL.md file(s)"
}

# --- 5. Unfilled placeholders -------------------------------------------------
Write-Section "Unfilled placeholders"
# .specify/ templates are meant to carry placeholders — they are the deliverable.
$placeholderHits = @(
    Get-ChildItem $RepoRoot -Recurse -File -Include *.md, *.json, *.ps1, *.bat -ErrorAction SilentlyContinue |
        Where-Object {
            $rel = $_.FullName.Substring($RepoRoot.Length + 1).Replace('\', '/')
            # .claude/skills/* is excluded because it is a link farm into
            # .agents/skills — scanning it would report every skill twice.
            # This script is excluded because it necessarily contains the
            # literal marker it searches for.
            $rel -notlike '.specify/*' -and $rel -notlike '.git/*' -and
            $rel -notlike '.claude/skills/*' -and $rel -ne 'tools/verify-kit.ps1'
        } |
        # -SimpleMatch treats the pattern as literal text, so the regex-escaped
        # '\[FILL IN' it was first written with searched for an actual backslash
        # and matched nothing -- the check reported a clean scaffold that is in
        # fact full of placeholders. Literal pattern, literal match.
        Select-String -Pattern '[FILL IN' -SimpleMatch |
        Where-Object {
            # Excluding this script by name was not enough: any file that
            # DESCRIBES this check also contains the literal marker, so
            # docs/proje-haritasi.md and CHANGELOG.md were reported as holding
            # unfilled placeholders they do not have. A gate that fails on its
            # own documentation trains people to ignore it, which costs more
            # than the check is worth.
            #
            # Prose always writes the marker inside backticks -- `[FILL IN` --
            # while a real placeholder is bare text meant to be replaced.
            # Excluding only the backticked form is the conservative cut: it
            # can never hide an actual placeholder, because an actual
            # placeholder is never backticked.
            $_.Line -notmatch '`\[FILL IN'
        }
)
if ($placeholderHits.Count -gt 0) {
    $shown = $placeholderHits | Select-Object -First 20 | ForEach-Object {
        "$($_.Path.Substring($RepoRoot.Length + 1)):$($_.LineNumber)"
    }
    $detail = "$($placeholderHits.Count) unfilled [FILL IN marker(s):`n    $($shown -join "`n    ")"
    if ($IsScaffold) {
        Add-Warning 'placeholders' "$detail`n    (expected: this is the blank scaffold, where placeholders are the product)"
    } else {
        Add-Failure 'placeholders' $detail
    }
} else {
    Write-Host "  OK — none outside .specify/"
}

# --- 6. README image links ----------------------------------------------------
Write-Section "README image links"
$readmeImageProblems = 0
Get-ChildItem $RepoRoot -File -Filter 'README*.md' | ForEach-Object {
    $readme = $_
    [regex]::Matches((Get-Content $readme.FullName -Raw), '!\[[^\]]*\]\((docs/images/[^)\s]+)\)') | ForEach-Object {
        $imgRel = $_.Groups[1].Value
        if (-not (Test-Path (Join-Path $RepoRoot $imgRel))) {
            $msg = "$($readme.Name) embeds '$imgRel' which does not exist"
            if ($IsScaffold) {
                Add-Warning 'readme-images' "$msg (expected in the scaffold: banners are generated per kit from Prompts/image-prompts.md)"
            } else {
                Add-Failure 'readme-images' "$msg — generate it from Prompts/image-prompts.md, or drop the embed"
            }
            $readmeImageProblems++
        }
    }
}
if ($readmeImageProblems -eq 0) { Write-Host "  OK — every embedded docs/images/* resolves" }

# --- 7. LICENSE presence ------------------------------------------------------
Write-Section "LICENSE"
if (Test-Path (Join-Path $RepoRoot 'LICENSE')) {
    Write-Host "  OK"
} else {
    Add-Failure 'license' "README references a license but no LICENSE file exists at the repo root"
}

# --- 8. Declared counts vs. reality -------------------------------------------
# The generator's map gate only checks that each rule/skill is MENTIONED in
# docs/proje-haritasi.md. It never checks the numbers those documents state, so
# every kit drifted: docs claiming "16 rules" next to 18 on disk, "28 skills"
# next to 33. A number is a claim like any other and goes stale the same way.
Write-Section "Declared counts"
$realCounts = @{
    'rule'  = @(Get-ChildItem (Join-Path $RepoRoot '.agents/rules') -Filter *.md -ErrorAction SilentlyContinue).Count
    'skill' = @(Get-ChildItem (Join-Path $RepoRoot '.agents/skills') -Directory -ErrorAction SilentlyContinue |
                Where-Object { -not $_.Name.StartsWith('.') }).Count
}
Write-Host ("  on disk: {0} rule(s), {1} skill(s)" -f $realCounts['rule'], $realCounts['skill'])

$countDocs = @('AGENTS.md', 'README.md', 'README.tr-TR.md', 'docs/proje-haritasi.md',
               '.claude/CLAUDE.md', '.github/copilot-instructions.md', '.gemini/rules/project-rules.md')

# A count claim is only recognized on a line that also NAMES the folder it is
# counting. The first version of this gate matched any "N rules"/"N skills" in
# free prose, which was wrong in both directions at once: it missed the real
# inventory headings, which are written as "`.agents/rules/` — 16 dosya"
# (Turkish for "files") and so never mentioned the noun it was looking for,
# while it happily matched narrative sentences about upstream projects that
# were never claims about this kit at all. Anchoring on the path removes both.
$countAnchors = @(
    @{ Pattern = '\.agents/rules/';            Kind = 'rule'  },
    @{ Pattern = '\.claude/rules/';            Kind = 'rule'  },
    @{ Pattern = '\.cursor/rules/';            Kind = 'rule'  },
    @{ Pattern = '\.agents/skills/';           Kind = 'skill' },
    @{ Pattern = '\.claude/skills/';           Kind = 'skill' },
    @{ Pattern = '\.claude/commands/<skill';   Kind = 'skill' }   # one wrapper per skill
)
# Counted nouns in both languages this workspace writes in. "dosya"/"klasör"
# are how the map documents actually phrase it.
$countNoun = '(rules?|skills?|kural|beceri|dosya|klasör|files?|folders?)'

$countMismatches = 0
foreach ($rel in $countDocs) {
    $full = Join-Path $RepoRoot $rel
    if (-not (Test-Path $full)) { continue }
    $lines = Get-Content $full
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        foreach ($anchor in $countAnchors) {
            if ($line -notmatch $anchor.Pattern) { continue }
            foreach ($m in [regex]::Matches($line, "(?i)\b(\d{1,3})\s+$countNoun\b")) {
                $claimed = [int]$m.Groups[1].Value
                $real = $realCounts[$anchor.Kind]
                if ($claimed -ne $real) {
                    Add-Failure 'counts' "$rel`:$($i+1) claims $claimed for $($anchor.Pattern -replace '\\','') ; there are $real $($anchor.Kind)(s) on disk"
                    $countMismatches++
                }
            }
            break   # one anchor per line: the first path named owns the numbers
        }
    }
}
if ($countMismatches -eq 0) { Write-Host "  OK — every path-anchored count matches disk" }

# --- 9. Dead repo-relative references -----------------------------------------
# A backticked repo-relative path in an AI-primary file is a promise that the
# path exists. script-expert shipped three dead .agents/** references and
# prompt-analyzer-expert three dead ACKNOWLEDGMENTS links; nothing caught either.
Write-Section "Dead references"
$refDocs = @('AGENTS.md', '.claude/CLAUDE.md', '.github/copilot-instructions.md',
             '.gemini/rules/project-rules.md', 'docs/ai-ignore-strategy.md', 'docs/proje-haritasi.md')

# Paths this kit declares it borrows from ANOTHER kit are resolved through the
# machine-wide hub, not against this repo root. Flagging them as dead was a
# false positive on a correctly-designed cross-kit reference -- Rad-Server
# citing Rad-DB's .agents/rules/db-schema.md is the real case this hit.
$crossKitPaths = @{}
$kitSettings = Join-Path $RepoRoot 'settings.json'
if (Test-Path $kitSettings) {
    try {
        $sj = Get-Content $kitSettings -Raw | ConvertFrom-Json
        # A kit with no cross-kit references has no `references` property at
        # all; reaching through it directly throws under StrictMode rather than
        # yielding $null, which turned "nothing to exempt" into a warning.
        if ($sj.PSObject.Properties.Name -contains 'references') {
            foreach ($ref in @($sj.references)) {
                if ($null -eq $ref) { continue }
                foreach ($rp in @($ref.paths)) { if ($rp) { $crossKitPaths[$rp] = $ref.kit } }
            }
        }
    } catch {
        Add-Warning 'dead-ref' "settings.json could not be parsed, so cross-kit reference paths cannot be exempted: $($_.Exception.Message)"
    }
}
if ($crossKitPaths.Count -gt 0) {
    Write-Host ("  exempting {0} cross-kit path(s) declared in settings.json" -f $crossKitPaths.Count)
}
$deadRefs = 0
foreach ($rel in $refDocs) {
    $full = Join-Path $RepoRoot $rel
    if (-not (Test-Path $full)) { continue }
    $lines = Get-Content $full
    for ($i = 0; $i -lt $lines.Count; $i++) {
        foreach ($m in [regex]::Matches($lines[$i], '`((?:\.agents|\.claude|\.cursor|\.github|\.kiro|\.specify|\.gemini|docs|examples|src|tools|Prompts)/[^`]+)`')) {
            $path = $m.Groups[1].Value
            # Skip anything with a glob or a placeholder — those are patterns,
            # not paths, and resolving them is not this check's job.
            if ($path -match '[\*\?]' -or $path -match '\[FILL IN' -or $path -match '[<>]') { continue }

            # A declared cross-kit path lives in ANOTHER repo and is resolved
            # through the hub; it is correct precisely because it is absent here.
            if ($crossKitPaths.ContainsKey($path)) { continue }

            # A templated path such as src/analysis/{ai_name}_v{n}.md names a
            # naming convention, not a file. Verify the static parent instead —
            # that the directory it will be written into exists — and never
            # demand the example filename itself.
            if ($path -match '\{[^}]+\}') {
                $staticParent = ($path -split '/' | Where-Object { $_ -notmatch '\{' }) -join '/'
                if ($staticParent -and -not (Test-Path (Join-Path $RepoRoot $staticParent))) {
                    Add-Failure 'dead-ref' "$rel`:$($i+1) references '$path'; its non-templated parent '$staticParent' does not exist"
                    $deadRefs++
                }
                continue
            }

            if (-not (Test-Path (Join-Path $RepoRoot $path))) {
                Add-Failure 'dead-ref' "$rel`:$($i+1) references '$path', which does not exist"
                $deadRefs++
            }
        }
    }
}
if ($deadRefs -eq 0) { Write-Host "  OK — every backticked repo-relative path resolves" }

# --- Result -------------------------------------------------------------------
Write-Host ""
if ($warnings.Count -gt 0) {
    Write-Host "$($warnings.Count) warning(s):" -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    Write-Host ""
}
if ($failures.Count -gt 0) {
    Write-Host "FAILED — $($failures.Count) problem(s):" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
Write-Host "All checks passed." -ForegroundColor Green
exit 0
