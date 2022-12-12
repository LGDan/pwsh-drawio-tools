. ./drawio-tools.ps1
. ./diagram-processor.ps1
. ./diagram-linter.ps1

$Path = $PWD.Path

$FileFilter = '*.drawio'
$AttributeFilter = [IO.NotifyFilters]::FileName, [IO.NotifyFilters]::LastWrite
$ChangeTypes = [System.IO.WatcherChangeTypes]::Created, [System.IO.WatcherChangeTypes]::Deleted, [System.IO.WatcherChangeTypes]::Changed
$Timeout = 1000

function Invoke-SomeAction {
    param
    (
        [Parameter(Mandatory)]
        [System.IO.WaitForChangedResult]
        $ChangeInformation
    )
  
    #Write-Warning 'Change detected:'
    #$ChangeInformation | Out-String | Write-Host -ForegroundColor DarkYellow

    $file = $ChangeInformation.Name
    $pages = "Page-1","Page-2"

    # Lint and Render!
    $vertexRules = @(
    New-DiagramLinterRule `
        -Name "All shapes must have a description" `
        -Where {$null -eq $_.ObjectProperties.description} `
        -Rule {$false} `
        -ErrorMessage "Shape does not have a description!"
    )

    $edgeRules = @(
        New-DiagramLinterRule `
            -Name "All ethernet connections must have a port defined." `
            -Where {$_.ObjectProperties.type -eq "ethernet"} `
            -Rule {
                ($Input[0].ObjectProperties.srcport -match "\d+") -and ($Input[0].ObjectProperties.dstport -match "\d+")
            } `
            -ErrorMessage "Ethernet does not have src and dst!"
    )

    $ShapePreprocessors = {
        param($node, $depth)
        # Catch for rubbish/aesthetic
        if ($null -eq $node) {return ""}

        # Start the actual thing
        $result = [System.Text.StringBuilder]::new()

        if ($node.ObjectProperties.labelType -eq "Title") {
            $result.AppendLine(("# " + $node.Name))}
        elseif ($node.StyleIcon -eq "mxgraph.aws4.group_region") {
            $result.Append((Write-MarkdownBlock -title ("Location - " + $node.Name) -text ("$($node.ObjectProperties.description)`r`n`r`n") -level ($depth+1)))
        }
        else {
            $result.Append((Write-MarkdownBlock -title $node.Name -text ("$($node.ObjectProperties.description)`r`n`r`n") -level ($depth+1)))}

        $result.ToString()
    }

    forEach ($page in $pages) {
        $pageElements = Get-Elements -filePath $file -tabName $page
        $vertexCheck = Invoke-DiagramLint -Elements @($pageElements.Vertecies) -RuleSet $vertexRules
        $edgeCheck = Invoke-DiagramLint -Elements @($pageElements.Edges) -RuleSet $edgeRules
        if ($vertexCheck -and $edgeCheck) {
            Write-Host -ForegroundColor Green "Lint Success! Rendering..."
            Get-DecomposedDiagramElementsV2 -Elements @($pageElements.Vertecies) -ShapePreprocessors $ShapePreprocessors | Out-File "test-$page.md"
        }else{
            Write-Host -ForegroundColor Red "Lint Failed! No Render!"
        }
    }
    Write-Host "-------------------"
}

try {
    Write-Warning "FileSystemWatcher is monitoring $Path"
  
    # create a filesystemwatcher object
    $watcher = New-Object -TypeName IO.FileSystemWatcher -ArgumentList $Path, $FileFilter -Property @{
        IncludeSubdirectories = $IncludeSubfolders
        NotifyFilter          = $AttributeFilter
    }

    # start monitoring manually in a loop:
    do {
        # wait for changes for the specified timeout
        # IMPORTANT: while the watcher is active, PowerShell cannot be stopped
        # so it is recommended to use a timeout of 1000ms and repeat the
        # monitoring in a loop. This way, you have the chance to abort the
        # script every second.
        $result = $watcher.WaitForChanged($ChangeTypes, $Timeout)
        # if there was a timeout, continue monitoring:
        if ($result.TimedOut) { continue }
    
        Invoke-SomeAction -Change $result
        # the loop runs forever until you hit CTRL+C    
    } while ($true)
}
finally {
    # release the watcher and free its memory:
    $watcher.Dispose()
    Write-Warning 'FileSystemWatcher removed.'
}
