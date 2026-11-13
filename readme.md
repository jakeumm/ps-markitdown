# ps-markitdown

A PowerShell module that converts files, or whole folder trees, to Markdown with
[MarkItDown](https://github.com/microsoft/markitdown).

## Requirements

- Windows (the module calls `.venv\Scripts\markitdown.exe`)
- PowerShell 7 or later
- Python 3.10 or later on `PATH`

This is an unofficial wrapper and isn't affiliated with Microsoft.

## Setup

Clone or download the repository, then run the setup script from that folder:

```powershell
git clone https://github.com/jakeumm/ps-markitdown
cd ps-markitdown
.\setup.ps1
```

The script:

1. Checks whether its parent folder is listed in `$env:PSModulePath`.
   If it isn't, it copies `markitdown.psm1`, `ps-markitdown.psd1`, `readme.md`, and `setup.ps1` to
   `<Documents>\PowerShell\Modules\ps-markitdown`.
2. Creates a Python virtual environment in the install folder, or reuses an existing one:

   ```powershell
   python -m venv .venv
   .\.venv\Scripts\Activate.ps1
   ```

3. Installs MarkItDown with all optional dependencies:

   ```powershell
   pip install 'markitdown[all]'
   ```

Run `setup.ps1` again to overwrite the installed module files and rerun pip using the existing
virtual environment. Packages that already satisfy the requirements are kept, not upgraded.

## Getting started

```powershell
Import-Module ps-markitdown
Get-Help Convert-Markdown -Examples
```

If setup prints a full-path `Import-Module` command instead, use that command. This handles
install folders outside `$env:PSModulePath` or folders not named `ps-markitdown`.

The module calls `markitdown.exe` from its own `.venv` directly, so you don't need to activate the
virtual environment.

## Usage

Convert a single file. This example creates `.\reports\Q3.pdf.md`:

```powershell
Convert-Markdown .\reports\Q3.pdf
```

Choose the output file, or a folder (a trailing `\` marks it as a folder):

```powershell
Convert-Markdown -Path .\reports\Q3.docx -Destination .\Q3-summary.md
Convert-Markdown -Path .\reports\Q3.docx -Destination .\notes\
```

Convert files from the pipeline:

```powershell
Get-ChildItem .\inbox\*.pdf | Convert-Markdown -Destination .\inbox-md\
```

Convert a folder tree and keep its subfolders. Without `-Destination`, output goes to a sibling
`<folder>-md` folder:

```powershell
Convert-Markdown -MirrorFolder -Path .\Policies\ -Destination C:\temp\Policies\
Convert-Markdown -MirrorFolder -Path .\Policies\ -Extension docx, html
```

Preview the conversions without writing anything, or overwrite existing `.md` files:

```powershell
Convert-Markdown -MirrorFolder -Path .\Policies\ -WhatIf
Convert-Markdown -MirrorFolder -Path .\Policies\ -Force
```

## Parameters

| Parameter       | Description                                                                          |
| --------------- | ------------------------------------------------------------------------------------ |
| `-Path`         | File to convert, or folder with `-MirrorFolder`. Accepts pipeline input.             |
| `-Destination`  | Output file or folder. Always a folder in mirror mode.                               |
| `-MirrorFolder` | Recursively convert a folder and keep its subfolder layout.                          |
| `-Extension`    | Mirror mode only. File types to convert, such as `docx`, `.docx`, or `*.docx`.       |
| `-Force`        | Overwrite existing `.md` files.                                                      |
| `-WhatIf`, `-Confirm` | Preview or confirm each conversion.                                            |

By default, mirror mode converts: pdf, docx, pptx, xlsx, xls, html, htm, csv, json, xml, epub, msg,
ipynb, rss, zip.

Notes:

- Existing `.md` files are skipped with a warning unless you use `-Force`.
- Each converted file is returned as a `FileInfo` object.
- `-Extension` is ignored, with a warning, when `-MirrorFolder` isn't used.
- In mirror mode, a destination inside the source folder is excluded from conversion.

## Updating and uninstalling

To update, pull the latest changes and run `.\setup.ps1` again. To upgrade MarkItDown itself, run this
from the install folder:

```powershell
.\.venv\Scripts\python.exe -m pip install -U 'markitdown[all]'
```

To uninstall, delete the install folder (`<Documents>\PowerShell\Modules\ps-markitdown` by default).

## Using the markitdown CLI directly

Change to the install folder printed by setup, then activate its Python virtual environment:

```powershell
.\.venv\Scripts\Activate.ps1
```

Convert a file and redirect the output:

```powershell
markitdown path-to-file.pdf > document.md
```

Or use `-o` to specify the output file:

```powershell
markitdown path-to-file.pdf -o document.md
```

Pipe content through standard input:

```powershell
Get-Content path-to-file.pdf -AsByteStream | markitdown
```

## License

TODO: add a LICENSE file and name the license here before publishing.

## References

- [microsoft/markitdown](https://github.com/microsoft/markitdown)
