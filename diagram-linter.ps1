. ./drawio-tools.ps1

function New-DiagramLinterRule($Name, [scriptblock]$Where, [ScriptBlock]$Rule, $ErrorMessage) {
    [PSCustomObject]@{
        Name = $Name
        Where = $Where
        Rule = $Rule
        ErrorMessage = $ErrorMessage
    }
}

function Invoke-DiagramLint($Elements, $RuleSet) {
    Write-Debug -Message (($Elements | Measure-Object).Count.ToString() + " elements.")
    Write-Debug -Message (($RuleSet | Measure-Object).Count.ToString() + " rules.")

    foreach($rule in $RuleSet) {
        $filtered = $Elements | Where-Object -FilterScript $rule.Where
        Write-Debug -Message "$(($filtered | Measure-Object).Count) matches for rule $($rule.Name)"
        forEach ($m in $filtered) {
            $result = ($m | Invoke-Command $rule.Rule)
            if ($result[0] -ne $true) {
                Write-Warning -Message "$($m.Name) ($($m.id)): $($rule.ErrorMessage))"
            }
        }
    }
}