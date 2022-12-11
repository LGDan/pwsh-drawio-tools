function Convert-FromDrawIO($filePath, $tabName) {
    $rawDrawIOXML = [xml](Get-Content $filePath) 
    $diagramElements = $rawDrawIOXML | Select-Xml -XPath "//diagram"
    $diagramElement = $diagramElements | Where-Object {$_.Node.Name -eq $tabName} | Select-Object -First 1
    $base64string = $diagramElement.node.InnerXML
    $base64data =  $base64string
    
    $data = [System.Convert]::FromBase64String($base64data)
    $ms = New-Object System.IO.MemoryStream
    $ms.Write($data, 0, $data.Length)
    $ms.Seek(0,0) | Out-Null
    
    $sr = New-Object System.IO.StreamReader(New-Object System.IO.Compression.DeflateStream($ms, [System.IO.Compression.CompressionMode]::Decompress))
    
    while ($line = $sr.ReadLine()) {  
        [System.Web.HttpUtility]::UrlDecode($line)
    }
    $sr.Close()
}

function Get-DrawIOCells($filePath, $tabName) {
    [xml]$mxGraphXML = Convert-FromDrawIO -filePath $filePath -tabName $tabName
    $mxGraphXML | Select-Xml -XPath "//mxCell" | % {
        $_.Node
    }
}

function Get-DrawIOStyleProperties($cell) {
    $obj = @{}
    $pairs = $cell.style.Split(";",[System.StringSplitOptions]::RemoveEmptyEntries)
    forEach($pair in $pairs) {
        $arr = $pair.Split("=")
        $obj.Add($arr[0],$arr[1])|Out-Null
    }
    $obj
}

function Parse-DrawIOCell($cell) {
    $graphTheoryType = ""
    $style = Get-DrawIOStyleProperties -cell $cell

    if ($cell.vertex -eq 1) {
        # Cell is a Vertex
        $graphTheoryType = "Vertex"

        # Shape
        $shape = "rectangle"
        if ($style.ContainsKey("shape")) {$shape = $style["shape"]}

        # Colour
        $fillColor = "#bbbbbb"
        if ($style.ContainsKey("fillColor")) {$fillColor = $style["fillColor"]}

        # Group?
        $isGroup = $false
        if ($style.ContainsKey("group")) {$isGroup = $true}

        # Container?
        $isContainer = $false
        if ($style.ContainsKey("container")) {$isContainer = $true}

        # Name
        $name = ""

        # id
        $id = ""

        # Shape
        $styleShape = ""
        if ($style.ContainsKey("shape")) {$styleShape = $style["shape"]}

        # Icon (for AWS things)
        $styleIcon = ""
        if ($style.ContainsKey("resIcon")) {$styleIcon = $style["resIcon"]}
        if ($style.ContainsKey("grIcon")) {$styleIcon = $style["grIcon"]}

        # Child of Object? (For extra meta labels)
        $isChildOf = $cell.ParentNode.Name
        $objectProperties = @{}
        if ($isChildOf -eq "object") {
            # Vertex is a child of an object node, meaning there's extra metadata wrapped around
            # it in the XML. Likely for custom label logic and properties.
            forEach ($attrib in $cell.ParentNode.Attributes) {
                $objectProperties.Add($attrib.Name, $attrib.Value)|Out-Null
            }

            # ID does not change
            $id = $cell.ParentNode.id

            # Placeholder Logic
            if ($objectProperties.ContainsKey("label")) {
                $name = $objectProperties["label"]
            }
            if ($objectProperties.ContainsKey("placeholder")) {
                $labelProp = $objectProperties["placeholder"]
                $name = $objectProperties[$labelProp]
            }
            if ($objectProperties.ContainsKey("placeholders")) {
                # TODO: Need to implement 'search up' logic for parent container inheritance.
                forEach ($kv in $objectProperties.GetEnumerator()) {
                    if ($null -ne $kv.Value) {$name = $name.Replace("%" + $kv.Key + "%", $kv.Value)}
                }
                $name = $name.Replace("<br>"," - ")
            }
        }else{
            # Vertex is a child of the root. Standard Behavior.
            $name = $cell.value
            $id = $cell.id
        }

        [PSCustomObject]@{
            Name = $name
            id = $id
            GraphObjectType = $graphTheoryType
            Shape = $shape
            FillColor = $fillColor
            Group = $isGroup
            ChildOf = $isChildOf
            ObjectProperties = $objectProperties
            Parent = $cell.parent
            Container = $isContainer
            StyleShape = $styleShape
            StyleIcon = $styleIcon
        }
    }

    if ($cell.edge -eq 1) {
        # Cell is an Edge
        $graphTheoryType = "Edge"
        $startArrow = "none"
        $endArrow = "classic"


        # Figure out direction
        $direction = "bi"

        if ($style.ContainsKey("startArrow")) {$startArrow = $style["startArrow"]}
        if ($style.ContainsKey("endArrow")) {$endArrow = $style["endArrow"]}
        if (($startArrow -eq "none") -xor ($endArrow -eq "none")) {
            $direction = "uni"
            if ($endArrow -eq "none"){$direction = "backward"}else{$direction = "forward"}
        }

        if (($null -eq $cell.source) -or ($null -eq $cell.target)){$graphTheoryType = "none"}

        [PSCustomObject]@{
            Name = $cell.value
            id = $cell.id
            GraphObjectType = $graphTheoryType
            Direction = $direction
            Source = $cell.source
            Target = $cell.target
        }
    }
}

function Get-DrawIOEdges($filePath, $tabName) {
    Get-DrawIOCells -filePath $filePath -tabName $tabName | Where-Object edge -eq 1 | ForEach-Object {
        Parse-DrawIOCell -cell $_
    }
}

function Get-DrawIOVertecies($filePath, $tabName) {
    Get-DrawIOCells -filePath $filePath -tabName $tabName | Where-Object vertex -eq 1 | ForEach-Object {
        Parse-DrawIOCell -cell $_
    }
}

function Get-DrawIOEntities($filePath, $tabName) {
    $vertecies = [System.Collections.ArrayList]::new()
    $edges = [System.Collections.ArrayList]::new()
    Get-DrawIOCells -filePath $filePath -tabName $tabName | ForEach-Object {
        if ($_.vertex -eq 1) {
            $vertecies.Add((Parse-DrawIOCell -cell $_))|Out-Null
        }elseif ($_.edge -eq 1) {
            $edges.Add((Parse-DrawIOCell -cell $_))|Out-Null
        }
    }
    [pscustomobject]@{
        FilePath = $filePath
        TabName = $tabName
        Vertecies = $vertecies
        Edges = $edges
    }
}

# ---------------------------------
