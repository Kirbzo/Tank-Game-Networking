$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$engine = Join-Path $root 'Godot/.godot/validation_engine/Godot_v4.7.2-stable_win64.exe'
$results = [Collections.Generic.List[object]]::new()
function Run-Group($name, $roles, $limit = 35) {
    $running = @()
    foreach ($role in $roles) {
        $label = $role.label
        $prefix = Join-Path $PSScriptRoot "$name-$label"
        $arguments = @('--headless', '--path', ('"' + (Join-Path $root 'Godot') + '"'), '--log-file', ('"' + $prefix + '.engine.log"')) + $role.arguments
        $info = [Diagnostics.ProcessStartInfo]::new()
        $info.FileName = $engine
        $info.Arguments = $arguments -join ' '
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $info
        $null = $process.Start()
        $running += @{process=$process; prefix=$prefix; arguments=$arguments; label=$label; outTask=$process.StandardOutput.ReadToEndAsync(); errTask=$process.StandardError.ReadToEndAsync()}
        Start-Sleep -Milliseconds 250
    }
    $deadline = [DateTime]::UtcNow.AddSeconds($limit)
    while (@($running | Where-Object { -not $_.process.HasExited }).Count -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
    foreach ($item in $running) {
        $timedOut = -not $item.process.HasExited
        if ($timedOut) { $item.process.Kill(); $item.process.WaitForExit() }
        $item.process.WaitForExit()
        $stdout = $item.outTask.Result
        $stderr = $item.errTask.Result
        [IO.File]::WriteAllText($item.prefix + '.stdout.log', $stdout)
        [IO.File]::WriteAllText($item.prefix + '.stderr.log', $stderr)
        $passed = -not $timedOut -and $item.process.ExitCode -eq 0 -and $stdout.Contains('PASS') -and $stderr -notmatch 'SCRIPT ERROR|Parse Error|FAIL:'
        $result = [ordered]@{group=$name; role=$item.label; command=('"' + $engine + '" ' + ($item.arguments -join ' ')); exit=$item.process.ExitCode; timeout=$timedOut; passed=$passed; stdout=$stdout; stderr=$stderr}
        $results.Add($result)
        Write-Output "$name/$($item.label): passed=$passed exit=$($item.process.ExitCode) timeout=$timedOut"
        $stdout -split "`n" | Where-Object { $_ -match 'PASS|FAIL' } | Write-Output
        if (-not $passed) { Write-Output $stderr }
    }
    $results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'results.json') -Encoding UTF8
}
function Single($name,$script,$extra=@()) {
    Run-Group $name @(@{label='single';arguments=(@('--script',"res://tests/$script.gd",'--') + $extra)})
}
function Pair($name,$script,$extra=@()) {
    Run-Group $name @(@{label='host';arguments=(@('--script',"res://tests/$script.gd",'--','host')+$extra)},@{label='client';arguments=(@('--script',"res://tests/$script.gd",'--')+$extra)})
}
Single 'initial' 'join_smoke' @('initial')
Single 'host-failure' 'alpha_smoke' @('failure')
Single 'packets' 'alpha_smoke' @('packets')
Single 'join-failure' 'join_smoke' @('failure')
Single 'join-delay' 'join_delay_smoke'
Single 'join-cancel-full-timeout' 'join_cancel_smoke' @('full-timeout')
Single 'network-ui' 'network_ui_smoke'
Single 'room-preview' 'game_room_smoke'
Single 'room-escape' 'game_room_smoke' @('escape')
Single 'prediction' 'room_view_smoke'
Single 'movement-validation' 'world_sync_smoke' @('unit')
Pair 'room-client-leaves' 'connected_room_smoke'
Pair 'room-host-leaves' 'connected_room_smoke' @('host-leaves')
Pair 'world-sync' 'world_sync_smoke'
Pair 'pending-host-loss' 'pending_host_loss_smoke'
Run-Group 'room-full' @(@{label='host';arguments=@('--script','res://tests/room_full_smoke.gd','--','host')},@{label='occupant';arguments=@('--script','res://tests/room_full_smoke.gd','--','occupant')},@{label='third';arguments=@('--script','res://tests/room_full_smoke.gd')})
Run-Group 'discovery' @(@{label='observer';arguments=@('--script','res://tests/alpha_smoke.gd','--','observer')},@{label='host';arguments=@('--script','res://tests/alpha_smoke.gd','--','host')})
Run-Group 'discovery-direct-ip' @(@{label='observer';arguments=@('--script','res://tests/alpha_smoke.gd','--','observer','unicast')},@{label='host';arguments=@('--script','res://tests/alpha_smoke.gd','--','host','unicast')})
Single 'combined-entry' 'combined_smoke' @('local')
Run-Group 'combat-entry' @(@{label='host';arguments=@('--script','res://tests/combat_smoke.gd','--','host')}) 5
