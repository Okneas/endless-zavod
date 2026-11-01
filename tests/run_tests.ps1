<#
.SYNOPSIS
  Запускает автоматические проверки проекта (tests/test_*.gd) через Godot из консоли.
.DESCRIPTION
  Простой запуск без фреймворка: сначала импорт проекта, затем каждый тест отдельным процессом Godot
  (несколько процессов одновременно, число задаёт -Jobs). Для каждого теста печатает число PASS/FAIL, время и сами провалы.
  По умолчанию идёт быстрый набор: долгие тесты (обход зон, забег целиком) включаются ключом -Full.
  Код выхода: 0 если всё прошло, иначе 1.
.PARAMETER Godot
  Путь к exe Godot (по умолчанию Steam-сборка автора).
.PARAMETER Project
  Папка проекта с project.godot (по умолчанию родитель папки tests).
.PARAMETER Only
  Запустить только эти тесты (имя или часть имени, можно несколько через запятую): -Only shield,cover.
  Долгие тесты в этом случае запускаются, если названы явно.
.PARAMETER Full
  Добавить долгие тесты (обход 30 зон, забег целиком): минуты вместо секунд.
.PARAMETER Jobs
  Сколько тестов идёт одновременно. Каждый тест это отдельный процесс Godot со своим временем симуляции
  (--fixed-fps), поэтому нагрузка меняет только время ожидания. 1 даёт последовательный запуск.
.PARAMETER Window
  Запустить ещё и тест мыши. Ему нужно окно (оно появится за пределами экрана), пока он идёт,
  физическую мышь не двигайте: захваченная мышь принимает её движения и сбивает числа. Идёт один, после остальных.
.PARAMETER TimeoutSeconds
  Сколько ждать каждый тест, секунды.
.EXAMPLE
  .\tests\run_tests.ps1
.EXAMPLE
  .\tests\run_tests.ps1 -Only shield,weak
.EXAMPLE
  .\tests\run_tests.ps1 -Full -Window
#>
param(
	[string]$Godot = 'G:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',
	[string]$Project = (Split-Path -Parent $PSScriptRoot),
	[string[]]$Only = @(),
	[switch]$Full,
	[int]$Jobs = 4,
	[switch]$Window,
	[int]$TimeoutSeconds = 300
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Godot)) { throw "Не найден Godot: $Godot (укажите путь параметром -Godot)" }
if (-not (Test-Path (Join-Path $Project 'project.godot'))) { throw "В папке $Project нет project.godot (параметр -Project)" }

$tmp = Join-Path $env:TEMP 'endless_zavod_tests'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$quotedProject = '"' + $Project + '"'

function Start-Godot([string[]]$GodotArgs, [string]$Name) {
	$out = Join-Path $tmp "$Name.out.txt"
	$err = Join-Path $tmp "$Name.err.txt"
	$proc = Start-Process -FilePath $Godot -ArgumentList $GodotArgs -PassThru -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err
	return [pscustomobject]@{ Proc = $proc; Out = $out; Err = $err; Name = $Name; Started = Get-Date }
}

Write-Host '== Импорт проекта'
$import = Start-Godot @('--headless', '--path', $quotedProject, '--import') 'import'
if (-not $import.Proc.WaitForExit($TimeoutSeconds * 1000)) { Stop-Process -Id $import.Proc.Id -Force; Write-Host 'Импорт завис, прерван по таймауту' -ForegroundColor Red }
$importErrors = @(Get-Content $import.Out, $import.Err -Encoding UTF8 | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Compile Error' })
if ($importErrors.Count -gt 0) { Write-Host ("Ошибки скриптов при импорте: " + $importErrors.Count) -ForegroundColor Red; $importErrors | Select-Object -First 5 }

$windowed = @('test_mouse_look.gd')
# Долгие тесты (много зон и физический проход, забег целиком): им нужно больше времени, чем остальным, и в быстрый набор они не входят.
$longTests = @{ 'test_zone_sweep.gd' = 1800; 'test_zone.gd' = 600; 'test_run_flow.gd' = 600 }
$all = Get-ChildItem (Join-Path $Project 'tests') -Filter 'test_*.gd' | Sort-Object Name
$queue = New-Object System.Collections.Generic.Queue[object]
$windowQueue = New-Object System.Collections.Generic.Queue[object]
foreach ($test in $all) {
	$named = $Only.Count -gt 0 -and @($Only | Where-Object { $test.BaseName -like "*$_*" }).Count -gt 0
	if ($Only.Count -gt 0 -and -not $named) { continue }
	if ($windowed -contains $test.Name) {
		if ($Window -or $named) { $windowQueue.Enqueue($test) } else { Write-Host "-- $($test.Name): пропущен (нужен ключ -Window)" -ForegroundColor DarkGray }
		continue
	}
	if ($longTests.ContainsKey($test.Name) -and -not $Full -and -not $named) { Write-Host "-- $($test.Name): долгий, пропущен (нужен ключ -Full)" -ForegroundColor DarkGray; continue }
	$queue.Enqueue($test)
}
if ($queue.Count + $windowQueue.Count -eq 0) { throw 'Не нашлось ни одного теста под условия запуска' }

$failedTests = 0
$total = [Diagnostics.Stopwatch]::StartNew()

function Report-Test($run, $limit) {
	$timedOut = $false
	if (-not $run.Proc.HasExited) { Stop-Process -Id $run.Proc.Id -Force; $timedOut = $true }
	$seconds = [int]((Get-Date) - $run.Started).TotalSeconds
	$lines = @(Get-Content $run.Out -Encoding UTF8)
	$pass = @($lines | Where-Object { $_ -match '^PASS' }).Count
	$failLines = @($lines | Where-Object { $_ -match '^FAIL' })
	$finished = @($lines | Where-Object { $_ -match '^=== FAILS:' }).Count -gt 0
	$scriptErrors = @(Get-Content $run.Out, $run.Err -Encoding UTF8 | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Compile Error' })
	$ok = $finished -and $failLines.Count -eq 0 -and $scriptErrors.Count -eq 0 -and -not $timedOut
	$color = if ($ok) { 'Green' } else { 'Red' }
	Write-Host ("{0,-28} PASS {1,3}  FAIL {2,2}  {3,4} с  {4}" -f ($run.Name + '.gd'), $pass, $failLines.Count, $seconds, $(if ($ok) { 'OK' } else { 'ПРОВАЛ' })) -ForegroundColor $color
	if (-not $ok) {
		$script:failedTests++
		if ($timedOut) { Write-Host '   тест завис, прерван по таймауту' }
		elseif (-not $finished) { Write-Host '   тест не дошёл до конца (ошибка скрипта?)' }
		$failLines | ForEach-Object { Write-Host "   $_" }
		$scriptErrors | Select-Object -First 3 | ForEach-Object { Write-Host "   $_" }
		Write-Host "   полный вывод: $($run.Out)"
	}
}

function Get-Limit($test) {
	if ($longTests.ContainsKey($test.Name)) { return [Math]::Max($TimeoutSeconds, $longTests[$test.Name]) }
	return $TimeoutSeconds
}

# Пул: до $Jobs процессов одновременно, готовые разбираются по мере завершения.
$running = New-Object System.Collections.ArrayList
while ($queue.Count -gt 0 -or $running.Count -gt 0) {
	while ($queue.Count -gt 0 -and $running.Count -lt [Math]::Max($Jobs, 1)) {
		$test = $queue.Dequeue()
		$run = Start-Godot @('--headless', '--path', $quotedProject, '--fixed-fps', '120', '--script', "res://tests/$($test.Name)") $test.BaseName
		$run | Add-Member -NotePropertyName Limit -NotePropertyValue (Get-Limit $test)
		[void]$running.Add($run)
	}
	Start-Sleep -Milliseconds 250
	foreach ($run in @($running)) {
		$elapsed = ((Get-Date) - $run.Started).TotalSeconds
		if ($run.Proc.HasExited -or $elapsed -gt $run.Limit) {
			Report-Test $run $run.Limit
			$running.Remove($run)
		}
	}
}

# Оконный тест идёт один: ему нужна неподвижная физическая мышь.
while ($windowQueue.Count -gt 0) {
	$test = $windowQueue.Dequeue()
	$run = Start-Godot @('--path', $quotedProject, '--fixed-fps', '120', '--resolution', '320x200', '--position', '-3000,-3000', '--script', "res://tests/$($test.Name)") $test.BaseName
	[void]$run.Proc.WaitForExit((Get-Limit $test) * 1000)
	Report-Test $run (Get-Limit $test)
}

Write-Host ''
Write-Host ("Время: {0} с" -f [int]$total.Elapsed.TotalSeconds)
if ($failedTests -eq 0) { Write-Host 'Все тесты прошли.' -ForegroundColor Green; exit 0 }
Write-Host "Провалено тестов: $failedTests" -ForegroundColor Red
exit 1
