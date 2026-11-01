<#
.SYNOPSIS
  Запускает автоматические проверки проекта (tests/test_*.gd) через Godot из консоли.
.DESCRIPTION
  Простой запуск без фреймворка: сначала импорт проекта, затем каждый тест отдельным процессом Godot.
  Для каждого теста печатает число PASS/FAIL и сами провалы. Код выхода: 0 если всё прошло, иначе 1.
.PARAMETER Godot
  Путь к exe Godot (по умолчанию Steam-сборка автора).
.PARAMETER Project
  Папка проекта с project.godot (по умолчанию родитель папки tests).
.PARAMETER Window
  Запустить ещё и тест мыши. Ему нужно окно (оно появится за пределами экрана), пока он идёт,
  физическую мышь не двигайте: захваченная мышь принимает её движения и сбивает числа.
.PARAMETER TimeoutSeconds
  Сколько ждать каждый тест, секунды.
.EXAMPLE
  .\tests\run_tests.ps1
.EXAMPLE
  .\tests\run_tests.ps1 -Window
#>
param(
	[string]$Godot = 'G:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',
	[string]$Project = (Split-Path -Parent $PSScriptRoot),
	[switch]$Window,
	[int]$TimeoutSeconds = 300
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Godot)) { throw "Не найден Godot: $Godot (укажите путь параметром -Godot)" }
if (-not (Test-Path (Join-Path $Project 'project.godot'))) { throw "В папке $Project нет project.godot (параметр -Project)" }

$tmp = Join-Path $env:TEMP 'endless_zavod_tests'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$quotedProject = '"' + $Project + '"'

# Запускает Godot, ждёт завершения (или убивает по таймауту). Возвращает пути к файлам вывода.
function Invoke-Godot([string[]]$GodotArgs, [string]$Name, [int]$Seconds = $TimeoutSeconds) {
	$out = Join-Path $tmp "$Name.out.txt"
	$err = Join-Path $tmp "$Name.err.txt"
	$proc = Start-Process -FilePath $Godot -ArgumentList $GodotArgs -PassThru -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err
	$timedOut = -not $proc.WaitForExit($Seconds * 1000)
	if ($timedOut) { Stop-Process -Id $proc.Id -Force }
	return [pscustomobject]@{ Out = $out; Err = $err; TimedOut = $timedOut }
}

Write-Host '== Импорт проекта'
$import = Invoke-Godot @('--headless', '--path', $quotedProject, '--import') 'import'
$importErrors = @(Get-Content $import.Out, $import.Err -Encoding UTF8 | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Compile Error' })
if ($import.TimedOut) { Write-Host 'Импорт завис, прерван по таймауту' -ForegroundColor Red }
if ($importErrors.Count -gt 0) { Write-Host ("Ошибки скриптов при импорте: " + $importErrors.Count) -ForegroundColor Red; $importErrors | Select-Object -First 5 }

$windowed = @('test_mouse_look.gd')
# Долгие тесты (много зон и физический проход): им нужно больше времени, чем остальным.
$longTests = @{ 'test_zone_sweep.gd' = 1800; 'test_zone.gd' = 600 }
$tests = Get-ChildItem (Join-Path $Project 'tests') -Filter 'test_*.gd' | Sort-Object Name
$failedTests = 0
foreach ($test in $tests) {
	$isWindowed = $windowed -contains $test.Name
	if ($isWindowed -and -not $Window) { Write-Host "-- $($test.Name): пропущен (нужен ключ -Window)" -ForegroundColor DarkGray; continue }
	$res = "res://tests/$($test.Name)"
	if ($isWindowed) {
		$godotArgs = @('--path', $quotedProject, '--fixed-fps', '120', '--resolution', '320x200', '--position', '-3000,-3000', '--script', $res)
	} else {
		$godotArgs = @('--headless', '--path', $quotedProject, '--fixed-fps', '120', '--script', $res)
	}
	$limit = if ($longTests.ContainsKey($test.Name)) { [Math]::Max($TimeoutSeconds, $longTests[$test.Name]) } else { $TimeoutSeconds }
	$run = Invoke-Godot $godotArgs $test.BaseName $limit
	$lines = @(Get-Content $run.Out -Encoding UTF8)
	$pass = @($lines | Where-Object { $_ -match '^PASS' }).Count
	$failLines = @($lines | Where-Object { $_ -match '^FAIL' })
	$finished = @($lines | Where-Object { $_ -match '^=== FAILS:' }).Count -gt 0
	$scriptErrors = @(Get-Content $run.Out, $run.Err -Encoding UTF8 | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Compile Error' })
	$ok = $finished -and $failLines.Count -eq 0 -and $scriptErrors.Count -eq 0 -and -not $run.TimedOut
	$color = if ($ok) { 'Green' } else { 'Red' }
	Write-Host ("{0,-24} PASS {1,3}  FAIL {2,2}  {3}" -f $test.Name, $pass, $failLines.Count, $(if ($ok) { 'OK' } else { 'ПРОВАЛ' })) -ForegroundColor $color
	if (-not $ok) {
		$failedTests++
		if ($run.TimedOut) { Write-Host '   тест завис, прерван по таймауту' }
		elseif (-not $finished) { Write-Host '   тест не дошёл до конца (ошибка скрипта?)' }
		$failLines | ForEach-Object { Write-Host "   $_" }
		$scriptErrors | Select-Object -First 3 | ForEach-Object { Write-Host "   $_" }
		Write-Host "   полный вывод: $($run.Out)"
	}
}

Write-Host ''
if ($failedTests -eq 0) { Write-Host 'Все тесты прошли.' -ForegroundColor Green; exit 0 }
Write-Host "Провалено тестов: $failedTests" -ForegroundColor Red
exit 1
