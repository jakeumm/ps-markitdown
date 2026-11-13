@{
    RootModule        = 'markitdown.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '1e946692-cbee-428d-82f6-149dc5624166'
    Description       = 'Convert files and folder trees to Markdown with Microsoft MarkItDown.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('Convert-Markdown')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            ProjectUri = 'https://github.com/jakeumm/ps-markitdown'
        }
    }
}
