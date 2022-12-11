. ./drawio-tools.ps1
function Get-Elements($filePath, $tabName) {
    $vertecies = Get-DrawIOVertecies -filePath $filePath -tabName $tabName
    $idMapping = @{}
    foreach($v in $vertecies) {
        $idMapping.Add($v.id, $v)|Out-Null
    }
    [pscustomobject]@{
        Vertecies = $vertecies
        LookupTable = $idMapping
    }
}

function Write-MarkdownBlock($title, $text, $level) {
    $sb = [System.Text.StringBuilder]::new()
    1..$level | ForEach-Object {$sb.Append("#")|Out-Null}
    $sb.AppendLine(" $title")|Out-Null
    $sb.AppendLine()|Out-Null
    $sb.Append($text)|Out-Null
    $sb.ToString()
}

function Get-DrawIOContainerComponents($Elements, $ContainerID) {
    $containers = $Elements.Vertecies | Where-Object Container -eq $true
    $Elements.Vertecies | Where-Object Parent -eq $ContainerID | ForEach-Object {
        [PSCustomObject]@{
            id = $_.id
            Name = $_.Name
            StyleShape = $_.StyleShape
            StyleIcon = $_.StyleIcon
            Object = $_
        }
    }
}

function Get-MarkdownTOCFromText($text) {
    $sb = [System.Text.StringBuilder]::new()
    $headings = $text.Split("`n",[System.StringSplitOptions]::RemoveEmptyEntries) | Where-Object {$_.StartsWith("#")}
    forEach($heading in $headings) {
        $linkText = $heading.ToLower().Replace("#","").Replace("_","").Trim().Replace(" ","-").Replace("--","-").Replace("`r","").Replace("`n","")
        $sb.AppendLine(($heading.Replace("# ","- [").Replace("#","  ").Replace("`r","").Replace("`n","") + "](#" + $linkText + ")"))|Out-Null
    }
    $sb.ToString()
}

function Invoke-ShapePreProcessors([scriptblock]$preprocessors, $node, $depth = 0) {
    if ($null -ne $preprocessors) {
        $preprocessors.Invoke($node, $depth)[0]
    }else{
        # Do nothing ATM, just render to MD
        Write-Debug -Message "Generating MD for $($node.Name)..."
        Write-MarkdownBlock -title $node.Name -text ("$($node.ObjectProperties.description)`r`n`r`n") -level ($depth+1)
    }
}

function Get-DecomposedDiagramElementsV2($Elements, [scriptblock]$ShapePreprocessors = $null) {
    $baseSB = [System.Text.StringBuilder]::new()

    function Depth-TraverseV2([System.Collections.IEnumerable]$nodes, $startid, $depth = 0) {
        # Initialise Vars
        Write-Debug -Message "New Depth Traverse Started for $startid"
        $depthSB = [System.Text.StringBuilder]::new()

        # Get the start node
        $startNode = $nodes | Where-Object id -eq $startid
        Write-Debug -Message "Start node $($startNode.Name) found."

        # Summarise the current node.
        $depthSB.Append((Invoke-ShapePreProcessors -node $startNode -preprocessors $ShapePreprocessors -depth $depth))|Out-Null

        # Get all shapes below the start node.
        $children = $nodes | Where-Object Parent -eq $startid
        Write-Debug -Message (($children | Measure-Object).Count.ToString() + " children found.")

        # Iterate through, go deep.
        forEach ($node in $children) {
            $result = Depth-TraverseV2 -nodes $nodes -startid $node.id -depth ($depth+1)
            $depthSB.Append($result)|Out-Null
        }
        # Close the Function.
        return $depthSB.ToString()
    }

    $baseSB.Append((Depth-TraverseV2 -nodes $Elements -startid 1))|Out-Null
    $baseSB.ToString()

}

function Get-DecomposedDiagramElements($Elements) {
    # Title
    $title = ($Elements.Vertecies | Where-Object {$_.ObjectProperties.labelType -eq "Title"}).Name

    # Heirarchy
    $heirarchy = @{}
    $containers = $Elements.Vertecies | Where-Object Container -eq $true
    $roots = @($containers | Where-Object Parent -eq 1)

    function Depth-Traverse([System.Collections.IEnumerable]$nodes, $depth = 0, $acc) {
        forEach ($node in $nodes) {
            $nextNodes = @($containers | Where-Object Parent -eq $node.id)
            $res = Depth-Traverse -nodes $nextNodes -depth ($depth+1) -acc $acc
            # Do Stuff
            # What ever the code after this line returns will be in the res variable.
            $elementsAtThisLevel = $Elements.Vertecies | Where-Object Container -eq $false | Where-Object Parent -eq $node.id
            $sb = [System.Text.StringBuilder]::new()
            forEach ($el in $elementsAtThisLevel) {
                $sb.AppendLine((Write-MarkdownBlock -title $el.Name -text $el.ObjectProperties.description -level ($depth+2)))|Out-Null
            }
            Write-MarkdownBlock -title $node.Name -text ("$($node.ObjectProperties.description)`r`n`r`n" + $sb.ToString() + $res) -level ($depth+1)
        }
    }

    #$sb = [System.Text.StringBuilder]::new()
    $text = Depth-Traverse -nodes $roots -acc $sb
    #$sb.ToString()

    [PSCustomObject]@{
        Title = $title
        TOC = (Get-MarkdownTOCFromText -text $text)
        Text = $text
    }
}