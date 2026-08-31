function Resolve-Symlinks {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string] $Path
    )

    [string] $separator = '/'
    [string[]] $parts = $Path.Split($separator)

    [string] $realPath = ''
    foreach ($part in $parts) {
        if ($realPath -and !$realPath.EndsWith($separator)) {
            $realPath += $separator
        }

        $realPath += $part.Replace('\', '/')

        # The slash is important when using Get-Item on Drive letters in pwsh.
        if (-not($realPath.Contains($separator)) -and $realPath.EndsWith(':')) {
            $realPath += '/'
        }

        # -Force 允许解析隐藏目录（如 AppData），SilentlyContinue 让 Get-Item
        # 在中间路径不可解析（非符号链接目录）时不抛错，只跳过该段。
        $item = Get-Item -Force -ErrorAction SilentlyContinue $realPath
        if ($item -and $item.LinkTarget) {
            $realPath = $item.LinkTarget.Replace('\', '/')
        }
    }
    $realPath
}

$path = Resolve-Symlinks -Path $args[0]
Write-Host $path
