# Uses the markitdown executable from the .venv next to this module, so no manual activation is needed.
$script:MarkItDownExe = Join-Path $PSScriptRoot '.venv\Scripts\markitdown.exe'

# File types converted by -MirrorFolder when -Extension is not given.
$script:DefaultExtensions = @(
    'pdf', 'docx', 'pptx', 'xlsx', 'xls',
    'html', 'htm', 'csv', 'json', 'xml',
    'epub', 'msg', 'ipynb', 'rss', 'zip'
)

function Invoke-MarkItDownFile {
    param(
        [Parameter(Mandatory)] [System.Management.Automation.PSCmdlet]$Cmdlet,
        [Parameter(Mandatory)] [string]$Source,
        [Parameter(Mandatory)] [string]$Target,
        [switch]$Force
    )

    if ((Test-Path -LiteralPath $Target) -and -not $Force) {
        Write-Warning "Skipping '$Source': '$Target' already exists. Use -Force to overwrite."
        return
    }

    if (-not $Cmdlet.ShouldProcess($Source, "Convert to $Target")) {
        return
    }

    $targetDir = Split-Path -Parent $Target
    if (-not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force -WhatIf:$false | Out-Null
    }

    & $script:MarkItDownExe $Source -o $Target
    if ($LASTEXITCODE -ne 0) {
        Write-Error "markitdown failed (exit code $LASTEXITCODE) for: $Source"
        return
    }
    Get-Item -LiteralPath $Target
}

function Convert-Markdown {
    <#
    .SYNOPSIS
    Converts files, or whole folder trees, to Markdown using MarkItDown from the local virtual environment.

    .DESCRIPTION
    Single-file mode (default): converts one file. The output is written next to the source as
    '<name>.<ext>.md', or to -Destination. If -Destination is an existing folder or ends with '\',
    the file is written into that folder as '<name>.<ext>.md'. Otherwise -Destination is used as
    the exact output file path.

    Mirror mode (-MirrorFolder): recursively converts every supported file under -Path into
    -Destination and recreates the relative subfolder layout. If -Destination is omitted, the
    output goes to a sibling folder named '<folder>-md'. Only subfolders that receive converted
    files are created.

    Existing .md files are skipped with a warning unless -Force is given. Supports -WhatIf and -Confirm.

    .PARAMETER Path
    The file to convert, or the folder to convert when -MirrorFolder is used. Accepts pipeline
    input, including FileInfo objects from Get-ChildItem.

    .PARAMETER Destination
    The output file or folder. In mirror mode this is always treated as a folder.

    .PARAMETER MirrorFolder
    Recursively converts the folder given by -Path and mirrors its structure into -Destination.

    .PARAMETER Extension
    Mirror mode only. Limits conversion to these file types. Accepts 'docx', '.docx', or '*.docx'.
    Defaults to: pdf, docx, pptx, xlsx, xls, html, htm, csv, json, xml, epub, msg, ipynb, rss, zip.

    .PARAMETER Force
    Overwrites .md files that already exist.

    .EXAMPLE
    Convert-Markdown .\reports\Q3.pdf

    Creates .\reports\Q3.pdf.md.

    .EXAMPLE
    Convert-Markdown -Path .\reports\Q3.docx -Destination .\Q3-summary.md

    Creates .\Q3-summary.md from .\reports\Q3.docx.

    .EXAMPLE
    Convert-Markdown -Path .\reports\Q3.docx -Destination .\notes\

    Creates .\notes\Q3.docx.md. The trailing '\' marks .\notes as a folder, which is created if needed.

    .EXAMPLE
    Get-ChildItem .\inbox\*.pdf | Convert-Markdown -Destination .\inbox-md\

    Converts every PDF in .\inbox into .\inbox-md\.

    .EXAMPLE
    Convert-Markdown -MirrorFolder -Path .\Policies\ -Destination C:\temp\Policies\

    Converts every supported file under .\Policies into C:\temp\Policies and keeps the subfolders,
    for example .\Policies\HR\leave.docx -> C:\temp\Policies\HR\leave.docx.md.

    .EXAMPLE
    Convert-Markdown -MirrorFolder -Path .\Policies\ -Extension docx, html

    Converts only .docx and .html files into the sibling folder .\Policies-md\.

    .EXAMPLE
    Convert-Markdown -MirrorFolder -Path .\Policies\ -WhatIf

    Lists the conversions that would be made without writing anything.

    .EXAMPLE
    Convert-Markdown -MirrorFolder -Path .\Policies\ -Force

    Re-converts everything and overwrites .md files that already exist in .\Policies-md\.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'InputFile')]
        [string]$Path,

        [Parameter(Position = 1)]
        [Alias('OutputFile')]
        [string]$Destination,

        [switch]$MirrorFolder,

        [string[]]$Extension,

        [switch]$Force
    )

    begin {
        if (-not (Test-Path -LiteralPath $script:MarkItDownExe)) {
            throw "markitdown not found at '$script:MarkItDownExe'. Create the venv and run: pip install 'markitdown[all]'"
        }

        $exts = if ($Extension) { $Extension } else { $script:DefaultExtensions }
        $exts = $exts | ForEach-Object { '.' + $_.TrimStart('*').TrimStart('.').ToLowerInvariant() }

        if ($Extension -and -not $MirrorFolder) {
            Write-Warning '-Extension is only used with -MirrorFolder and will be ignored.'
        }
    }

    process {
        # Resolve against the PowerShell location, not the process working directory.
        $in = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)

        if ($MirrorFolder) {
            if (-not (Test-Path -LiteralPath $in -PathType Container)) {
                Write-Error "-MirrorFolder requires -Path to be a folder: $in"
                return
            }
            $in = $in.TrimEnd('\', '/')

            if ($Destination) {
                $dest = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Destination).TrimEnd('\', '/')
            }
            else {
                $dest = Join-Path (Split-Path -Parent $in) ((Split-Path -Leaf $in) + '-md')
            }

            # Skip the destination folder if it sits inside the source tree.
            $destPrefix = $dest + [IO.Path]::DirectorySeparatorChar
            $files = @(Get-ChildItem -LiteralPath $in -Recurse -File | Where-Object {
                    $exts -contains $_.Extension.ToLowerInvariant() -and
                    -not $_.FullName.StartsWith($destPrefix, [StringComparison]::OrdinalIgnoreCase)
                })

            if ($files.Count -eq 0) {
                Write-Warning "No matching files found under '$in' (extensions: $($exts -join ', '))."
                return
            }

            for ($i = 0; $i -lt $files.Count; $i++) {
                $file = $files[$i]
                $rel = [IO.Path]::GetRelativePath($in, $file.FullName)
                Write-Progress -Activity "Converting to Markdown -> $dest" -Status $rel -PercentComplete (100 * $i / $files.Count)
                Invoke-MarkItDownFile -Cmdlet $PSCmdlet -Source $file.FullName -Target (Join-Path $dest "$rel.md") -Force:$Force
            }
            Write-Progress -Activity "Converting to Markdown -> $dest" -Completed
            return
        }

        if (Test-Path -LiteralPath $in -PathType Container) {
            Write-Error "'$in' is a folder. Use -MirrorFolder to convert a folder tree."
            return
        }
        if (-not (Test-Path -LiteralPath $in -PathType Leaf)) {
            Write-Error "Input file not found: $in"
            return
        }

        if (-not $Destination) {
            $out = "$in.md"
        }
        else {
            $out = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Destination)
            if ($Destination -match '[\\/]$' -or (Test-Path -LiteralPath $out -PathType Container)) {
                $out = Join-Path $out ((Split-Path -Leaf $in) + '.md')
            }
        }

        Invoke-MarkItDownFile -Cmdlet $PSCmdlet -Source $in -Target $out -Force:$Force
    }
}

Export-ModuleMember -Function Convert-Markdown
