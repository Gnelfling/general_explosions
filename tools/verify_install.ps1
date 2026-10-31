# Read-only inventory. Does not install, copy, rename or remove anything.
param([Parameter(Mandatory=$true)][string]$AddonPath)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $AddonPath).Path
$missing = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$required = @('shaders/fxc/ge_volume_ps30.vcs','shaders/fxc/ge_volume_vs30.vcs',
 'lua/general_explosions/runtime.lua','lua/general_explosions/load_runtime.lua',
 'lua/general_explosions/data/ground_explosion.lua')
foreach ($cue in @('railgun_charge.wav','railgun_fire.wav','railgun_explosion.wav')) {
 $required += "sound/general_explosions/railgun/$cue"
}
foreach ($path in $required) {
 if (-not (Test-Path -LiteralPath (Join-Path $root $path) -PathType Leaf)) { $missing.Add($path) }
}
$manifest = Join-Path $root 'lua/general_explosions/data/ground_explosion.lua'
$records = 0; $last = -1
if (Test-Path -LiteralPath $manifest -PathType Leaf) {
 $source = Get-Content -LiteralPath $manifest -Raw
 foreach ($match in [regex]::Matches($source,'\bframe\s*=\s*(\d+)')) {
  $records++; $last = [math]::Max($last,[int]$match.Groups[1].Value)
 }
 foreach ($match in [regex]::Matches($source,'texture\s*=\s*"([^"]+)"')) {
  $texture = $match.Groups[1].Value
  if ($texture -match '(^/|\.\.|:)') { throw 'Unsafe texture path in manifest' }
  foreach ($ext in @('vtf','vmt')) {
   $path = "materials/$texture.$ext"
   if (-not (Test-Path -LiteralPath (Join-Path $root $path) -PathType Leaf)) { $missing.Add($path) }
  }
 }
 if ($records -eq 0) { $warnings.Add('No frame records recognized; inspect manifest format.') }
 if ($last -lt 199) { $warnings.Add('Sequence ends before frame 199. Valid short exports are supported; preserve the owner full 200-frame export if available.') }
}
[pscustomobject]@{AddonPath=$root; FrameRecords=$records; LastRecord=$last;
 Missing=@($missing.ToArray()); Warnings=@($warnings.ToArray());
 Scope='Existence inventory only: not Lua execution, texture/shader compatibility, audio quality or in-game validation.'} | ConvertTo-Json -Depth 4
if ($missing.Count -gt 0) { exit 1 }
