# Dan's Powershell Draw.io Toolkit

>*"What if you could have one visual design that can be hierarchically explored, details all aspects to the degree of depth required, subconsciously enforce best practices, and programatically maintain all documentation, links, interfaces, contracts, requirements, and descriptions of all components at each level?"*

---

This repo contains a selection of Powershell scripts use for parsing and working with draw.io diagram files.

## drawio-tools.ps1

The main library for interacting with the raw file format. Provides an abstraction layer between the elements in the diagram, and what ever code that needs to interact.

## diagram-processor.ps1

Tools for generating markdown documents based on draw.io diagrams.

Support for:

- Hierarchical nesting using containers.
- Arbitrary metadata fields on elements.
- Markdown/section rendering behavior based on custom logic (i.e. if shape has certain fields, render paragraph differently) (Shape Preprocessors)
- Custom rendering behavior based on page (i.e. cover page, HLD, LLD, Systems, Subsystems, Interfaces, etc)

## diagram-linter.ps1

Functions for building very simple linter rules for diagrams.

```powershell
# Simple, match everything that does not have a description meta field, return false.
New-DiagramLinterRule `
    -Name "All shapes must have a description" `
    -Where {$null -eq $_.ObjectProperties.description} `
    -Rule {$false} `
    -ErrorMessage "Shape does not have a description!"

# Bit more advanced, match objects where a type field is defined as 'ethernet'
# then enforce it having a number in srcport and dstport.
New-DiagramLinterRule `
    -Name "All ethernet connections must have a port defined." `
    -Where {$_.ObjectProperties.type -eq "ethernet"} `
    -Rule {
        ($Input[0].ObjectProperties.srcport -match "\d+") -and ($Input[0].ObjectProperties.dstport -match "\d+")
    } `
    -ErrorMessage "Ethernet does not have src and dst!"
```

## watcher.ps1

Monitors for diagram changes, and re-renders the diagram if the linter passes.

### Usage

```powershell

# 'Node' object fields. Use these for working with PreProcessor Logic :)
#
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

# Shape preprocessors are where you define custom behavior for rendering the document. Each diagram element is fed through this based on a depth-first graph traversal that recursively explores all draw.io 'containers'.
$ShapePreprocessors = {
    param($node, $depth)
    # Catch for rubbish/aesthetic
    if ($null -eq $node) {return ""}

    # Start the actual thing
    $result = [System.Text.StringBuilder]::new()

    # If a shape has a property 'labelType' defined on it, with a value of "Title"...
    if ($node.ObjectProperties.labelType -eq "Title") {
        # Render it as a top level heading.
        $result.AppendLine(("# " + $node.Name))
    }
    # If a shape is an AWS region container, repurpose it as a 'location', and summarise it with the description field.
    elseif ($node.StyleIcon -eq "mxgraph.aws4.group_region") {
        $result.Append((Write-MarkdownBlock -title ("Location - " + $node.Name) -text ("$($node.ObjectProperties.description)`r`n`r`n") -level ($depth+1)))
    }
    # If no match, render normally.
    else {
        $result.Append((Write-MarkdownBlock -title $node.Name -text ("$($node.ObjectProperties.description)`r`n`r`n") -level ($depth+1)))
    }

    $result.ToString()
}

$file = ".\test.drawio"
$pages = "Page-1","Page-2"

forEach ($page in $pages) {
    $pageElements = Get-Elements -filePath $file -tabName $page
    Get-DecomposedDiagramElementsV2 -Elements @($pageElements.Vertecies) -ShapePreprocessors $ShapePreprocessors | Out-File "test-$page.md"
}
```

## scratchpad.ps1

More abstractions and examples to make working with the other scripts easier.