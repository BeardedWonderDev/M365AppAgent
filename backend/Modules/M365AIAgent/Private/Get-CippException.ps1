function Get-CippException {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Exception
    )
    
    # Format exception details for logging following CIPP pattern
    return @{
        Message = $Exception.Exception.Message
        StackTrace = $Exception.Exception.StackTrace
        Line = $Exception.InvocationInfo.ScriptLineNumber
        Command = $Exception.InvocationInfo.MyCommand
        ScriptName = $Exception.InvocationInfo.ScriptName
        PositionMessage = $Exception.InvocationInfo.PositionMessage
        CategoryInfo = $Exception.CategoryInfo.ToString()
        FullyQualifiedErrorId = $Exception.FullyQualifiedErrorId
        Type = $Exception.Exception.GetType().FullName
        InnerException = if ($Exception.Exception.InnerException) {
            $Exception.Exception.InnerException.Message
        } else {
            $null
        }
    }
}