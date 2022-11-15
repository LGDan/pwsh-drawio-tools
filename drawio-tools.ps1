function Convert-FromDrawIO($filePath) {
    $rawDrawIOXML = [xml](Get-Content $filePath) 
    $diagramElement = $rawDrawIOXML | Select-Xml -XPath "//diagram"
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

function Get-DrawIOCells($filePath) {
    [xml]$mxGraphXML = Convert-FromDrawIO -filePath $filePath
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
    if ($cell.vertex -eq 1) {
        # Cell is a Vertex
        $graphTheoryType = "Vertex"
        [PSCustomObject]@{
            Name = $cell.value
            id = $cell.id
            GraphObjectType = $graphTheoryType
        }
    }
    if ($cell.edge -eq 1) {
        # Cell is an Edge
        $graphTheoryType = "Edge"
        $startArrow = "none"
        $endArrow = "classic"


        # Figure out direction
        $style = Get-DrawIOStyleProperties -cell $cell
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

Get-DrawIOCells -filePath .\Pwsh-Dag-Demo.drawio | Where edge -eq 1 | % {
    Parse-DrawIOCell -cell $_
}

#Get-DrawIOStyleProperties -cell $cell
#Convert-FromDrawIO -filePath .\IT-Process-Graph.drawio
