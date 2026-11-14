$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$features = Join-Path $root 'folia-server/paper-patches/features'
$version = Get-Content -Raw -LiteralPath (Join-Path $features '0009-Modernize-version-command.patch')
$bars = Get-Content -Raw -LiteralPath (Join-Path $features '0007-Add-folia-native-bars.patch')
$build = Get-Content -Raw -LiteralPath (Join-Path $features '0002-Build-changes.patch')
foreach ($name in '0002-Build-changes.patch', '0007-Add-folia-native-bars.patch', '0009-Modernize-version-command.patch') {
    git -C $root apply --numstat (Join-Path $features $name) | Out-Null
    if ($LASTEXITCODE) { throw "Invalid patch: $name" }
}
foreach ($expected in @(
    'fetchDistanceFromGitHub(branch.get(), commit.get()) : DISTANCE_UNKNOWN',
    'COMPONENT_LOGGER.info(getUpdateStatusMessage())',
    'ClickEvent.openUrl(DOWNLOAD_PAGE)',
    'distance == 1 ? " commit behind" : " commits behind"',
    'thenCombineAsync(this.hardwareInfo',
    'FoliaStatusBarCommand.systemUsage()',
    'updateMessage.hoverEvent(history)'
)) {
    if (!$version.Contains($expected)) { throw "Missing version behavior: $expected" }
}
$added = ($version -split "`n" | Where-Object { $_.StartsWith('+') }) -join "`n"
if ($added -match 'fetchDistanceFromSiteApi|fetchMinecraftVersionList|papermc.io/downloads') {
    throw 'Version check still uses upstream builds'
}
if (!$build.Contains('+    private static final String DOWNLOAD_PAGE = "https://github.com/LisoSMP-de/Folia"')) {
    throw 'Wrong download target'
}
foreach ($expected in 'cpuUsageText(sampleCpuPercent())', 'cpuUsageText(percent)',
    'memoryUsageText(memoryUsed(heap), memoryMax(heap))', 'memoryUsageText(totalUsed, safeMax)') {
    if (!$bars.Contains($expected)) { throw "Missing shared bar formatter: $expected" }
}
Write-Output 'PASS: patch syntax, fork-only version lookup, shared live metrics formatting'
