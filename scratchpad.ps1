. ./drawio-tools.ps1
. ./diagram-processor.ps1

# Get-DrawIOCells -filePath .\test.drawio -tabName "Page-1"
# | Select-Object -First 1 -Skip 11
# | Select-Object -Property *
# | fl

#Convert-FromDrawIO -filePath .\test.drawio -tabName "Page-1"

# 2022-12-11
# $docStruct = Get-DecomposedDiagramElements -Elements (Get-Elements)
# $sb = [System.Text.StringBuilder]::new()
# $sb.AppendLine("# " + $docStruct.Title)|Out-Null
# $sb.AppendLine("## Table of Contents")|Out-Null
# $sb.AppendLine($docStruct.TOC)|Out-Null
# $sb.AppendLine("---")|Out-Null
# $sb.Append($docStruct.Text)|Out-Null
# $sb.ToString()

# $sb.ToString() | Out-File "test.md"

# Name             : Site H
# id               : oU-0djraLoVSS_Ljd1G1-2
# GraphObjectType  : Vertex
# Shape            : mxgraph.aws4.group
# FillColor        : none
# Group            : False
# ChildOf          : object
# ObjectProperties : {[placeholder, location], [placeholders, 1], [description, Foo Bar.], [id, oU-0djraLoVSS_Ljd1G1-2]…}
# Parent           : CA1oepuSkN0H81AaIjU9-24
# Container        : True
# StyleShape       : mxgraph.aws4.group
# StyleIcon        : mxgraph.aws4.group_region

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

$file = ".\test.drawio"
$pages = "Page-1","Page-2"

forEach ($page in $pages) {
    $pageElements = Get-Elements -filePath $file -tabName $page
    Get-DecomposedDiagramElementsV2 -Elements @($pageElements.Vertecies) -ShapePreprocessors $ShapePreprocessors | Out-File "test-$page.md"
}