# ============================================================
#  生成万能Z 紧凑二进制索引 keke_fuzzy_z_<86|98|nc>.idx
#  （Windows 自带 PowerShell，无需安装 Python）
#
#  三种运行方式（任选其一）：
#    1) 双击同目录的 gen_fuzzy_idx.bat        （推荐）
#    2) 右键本文件 - 使用 PowerShell 运行      （不传参数：自动定位 Rime 目录，
#                                              一次生成 86 / 98 / nc 三套）
#    3) 命令行带参数（可只生成一个方案）：
#       powershell -NoProfile -ExecutionPolicy Bypass -File tools\gen_fuzzy_idx.ps1 "<Rime目录>" 86 "<输出.idx>"
#
#  算法与 tools/gen_fuzzy_idx.py 完全一致：
#    只收单字；q = len(code)*1048576 + 26进制值；按 q 升序、
#    同 q 保持词典顺序；签名 = 三本词典文件大小滚动哈希 ^ 条目数
#
#  格式：
#    header(20B): 'KKEZ' | ver u8 | 3B pad | n u32 | sig u32 | dlen u32 | 4B pad
#    entries: n x 8B (q u32, off u32) 按 q 升序
#    data   : 每条 (wlen u8, tier u8, word bytes)
# ============================================================
param(
    [string]$Rime,    # 省略 = 本文件所在目录的上一级
    [string]$Ver,     # 省略 = 86 / 98 / nc 全做；或只写其中一个
    [string]$Out      # 省略 = <Rime>\lua\keke_fuzzy_z_<Ver>.idx
)

$ErrorActionPreference = 'Stop'

# 无参数运行（右键/双击 ps1）时，结束前停一下，让窗口能看清结果
$interactive = ($PSBoundParameters.Count -eq 0)

$utf8 = New-Object System.Text.UTF8Encoding($false, $false)

# 与 python 端 len(word)==1 等价（含增补平面汉字，如“𠀀”）
function Test-SingleChar([string]$s) {
    if ([string]::IsNullOrEmpty($s)) { return $false }
    if ($s.Length -eq 1) { return $true }
    if ($s.Length -eq 2 -and [char]::IsHighSurrogate($s[0]) -and [char]::IsLowSurrogate($s[1])) { return $true }
    return $false
}

# 编码转 q 值；非法返回 -1
function Get-Q([string]$code) {
    $n = $code.Length
    if ($n -lt 1 -or $n -gt 4) { return -1 }
    $v = [int64]0
    foreach ($ch in $code.ToCharArray()) {
        if ($ch -lt 'a' -or $ch -gt 'z') { return -1 }
        $v = $v * 26 + ([int]$ch - 97)
    }
    return [uint32]($n * 1048576 + $v)
}

# 生成一个方案的索引
function Generate-Idx {
    param([string]$RimeDir, [string]$V, [string]$OutPath)

    $RimeDir = $RimeDir.TrimEnd('\', '/')

    # ---- 1. 读取三本词典，收单字 ----
    $groups = @(
        @(1, "keke_wubi_${V}_common"),
        @(2, "keke_wubi_${V}_system"),
        @(3, "keke_wubi_${V}_rare")
    )

    $seen  = New-Object 'System.Collections.Generic.HashSet[string]'
    $recs  = New-Object 'System.Collections.Generic.List[object]'   # 每项: @(q, 序号, word, tier)
    $sizes = @{}
    $seq   = 0

    foreach ($g in $groups) {
        $tier = [byte]$g[0]
        $name = $g[1]
        $path = Join-Path $RimeDir ($name + '.dict.yaml')
        if (-not (Test-Path -LiteralPath $path)) { throw "缺少词典文件：$path（三本必须齐全，否则生成的索引无效）" }
        $sizes[$name] = (Get-Item -LiteralPath $path).Length

        $lines    = [System.IO.File]::ReadAllLines($path, $utf8)
        $inHeader = $true

        foreach ($line in $lines) {
            if ($inHeader) {
                if ($line.StartsWith('...')) { $inHeader = $false }
                continue
            }
            if ($line -eq '') { continue }
            if ($line.TrimStart().StartsWith('#')) { continue }
            $parts = $line.Split([char]"`t")
            if ($parts.Length -lt 2) { continue }
            $word = $parts[0].Trim()
            $code = $parts[1].Trim()
            if (-not (Test-SingleChar $word)) { continue }   # 只收单字
            $q = Get-Q $code
            if ($q -lt 0) { continue }
            $key = "$q`t$word"
            if (-not $seen.Add($key)) { continue }           # 同码同字去重
            $recs.Add(@([uint32]$q, $seq, $word, $tier))
            $seq++
        }
    }

    if ($recs.Count -eq 0) { throw "没有读到任何词条，请确认目录里有 keke_wubi_${V}_*.dict.yaml" }

    # ---- 2. 稳定排序：q 升序，同 q 保持词典顺序（与 python sort 一致）----
    $sorted = $recs | Sort-Object -Property @{Expression = { $_[0] } }, @{Expression = { $_[1] } }

    # ---- 3. 组装 data 与偏移表 ----
    $msData  = New-Object System.IO.MemoryStream
    $entries = New-Object 'System.Collections.Generic.List[object]'   # 每项: @(q, off)
    $off     = [uint32]0

    foreach ($r in $sorted) {
        $word = [string]$r[2]
        $tier = [byte]$r[3]
        $wb   = $utf8.GetBytes($word)
        if ($wb.Length -gt 255) { continue }
        $rec = New-Object byte[] (2 + $wb.Length)
        $rec[0] = [byte]$wb.Length
        $rec[1] = $tier
        [Array]::Copy($wb, 0, $rec, 2, $wb.Length)
        $msData.Write($rec, 0, $rec.Length)
        $entries.Add(@([uint32]$r[0], [uint32]$off))
        $off = [uint32]($off + $rec.Length)
    }

    $n    = $entries.Count
    $dlen = [int]$msData.Length

    # ---- 4. 签名（三本词典按名称字典序 + 条目数）----
    $nameList = New-Object 'System.Collections.Generic.List[string]'
    foreach ($k in $sizes.Keys) { $nameList.Add([string]$k) }
    $nameList.Sort([System.StringComparer]::Ordinal)

    $sig = [uint32]0
    foreach ($nm in $nameList) {
        $sig = [uint32](([uint64]$sig * 131 + [uint64]$sizes[$nm]) -band 0xFFFFFFFF)
    }
    $sig = [uint32](([uint64]$sig -bxor [uint64]$n) -band 0xFFFFFFFF)

    # ---- 5. 写文件 ----
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $bw.Write([byte[]](0x4B, 0x4B, 0x45, 0x5A))    # 'KKEZ'
    $bw.Write([byte]1)                              # ver
    $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0)   # 3B pad
    $bw.Write([uint32]$n)
    $bw.Write([uint32]$sig)
    $bw.Write([uint32]$dlen)
    $bw.Write([byte[]](0, 0, 0, 0))                 # 4B pad
    foreach ($e in $entries) {
        $bw.Write([uint32]$e[0])
        $bw.Write([uint32]$e[1])
    }
    $dataArr = $msData.ToArray()
    $bw.Write($dataArr)
    $bw.Flush()

    [System.IO.File]::WriteAllBytes($OutPath, $ms.ToArray())
    $bw.Close(); $ms.Close(); $msData.Close()

    Write-Host ("{0}: 条目 {1}  data {2}  文件 {3}  sig {4}" -f $V, $n, $dlen, (Get-Item -LiteralPath $OutPath).Length, $sig)
}

try {
    # ---- 定位目录与方案 ----
    $tools = $PSScriptRoot
    if (-not $tools) { $tools = Split-Path -Parent $MyInvocation.MyCommand.Path }

    if (-not $Rime) { $Rime = Split-Path -Parent $tools }
    if (-not (Test-Path -LiteralPath $Rime)) { throw "Rime 目录不存在：$Rime" }

    if ($Ver) {
        if (@('86', '98', 'nc') -notcontains $Ver) { throw "Ver 只能是 86 / 98 / nc，收到：$Ver" }
        $vers = @($Ver)
    } else {
        $vers = @('86', '98', 'nc')
    }

    foreach ($v in $vers) {
        $outPath = $Out
        if (-not $outPath) { $outPath = Join-Path $Rime ("lua\keke_fuzzy_z_" + $v + ".idx") }
        $luaDir = Split-Path -Parent $outPath
        if ($luaDir -and -not (Test-Path -LiteralPath $luaDir)) { New-Item -ItemType Directory -Path $luaDir -Force | Out-Null }
        Generate-Idx -RimeDir $Rime -V $v -OutPath $outPath
    }
    exit 0
}
catch {
    Write-Host ("错误：{0}" -f $_.Exception.Message)
    exit 1
}
finally {
    if ($interactive) {
        Write-Host ""
        Read-Host "运行结束，按回车键退出" | Out-Null
    }
}
