# M3 — two teams, one model, two token totals.
# Sends three calls as Team A and one as Team B, then reads the usage workspace.
# Token metrics usually take a couple of minutes to appear.
# This Azure CLI has no `az monitor app-insights` command, so the read goes
# through the workspace query API instead.

$keys = terraform output -json team_subscription_keys | ConvertFrom-Json
$url  = terraform output -raw gateway_chat_completions_url
$rg   = terraform output -raw resource_group_name
$body = '{"messages":[{"role":"user","content":"Say hello"}]}'

function Invoke-TeamCall($team, $n) {
  foreach ($i in 1..$n) {
    try {
      $r = Invoke-WebRequest -Uri $url -Method POST -Body $body `
        -Headers @{ "Ocp-Apim-Subscription-Key" = $keys.$team; "Content-Type" = "application/json" }
      "$team call ${i} : $($r.StatusCode)"
    } catch {
      "$team call ${i} : $($_.Exception.Response.StatusCode.value__)"
    }
  }
}

Invoke-TeamCall "team-a" 3
Invoke-TeamCall "team-b" 1

$workspace = az monitor log-analytics workspace list -g $rg --query "[?ends_with(name, '-law')].name | [0]" -o tsv
if (-not $workspace) {
  "Could not find the usage workspace in $rg."
  exit 1
}

$query = @'
AppMetrics
| where TimeGenerated > ago(1h)
| where Name == "Total Tokens"
| extend Team = tostring(Properties["Team"])
| summarize Tokens = sum(Sum) by Team
| order by Team asc
'@

$queryFile = Join-Path $env:TEMP "m3-token-query.json"
@{ query = $query.Trim() } | ConvertTo-Json -Compress | Set-Content -Path $queryFile -Encoding ascii
$queryUrl = "https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/$rg/providers/Microsoft.OperationalInsights/workspaces/$workspace/api/query?api-version=2020-08-01"

"Waiting for token metrics to reach Application Insights..."
$deadline = (Get-Date).AddMinutes(4)
$rows = @()
$columns = @()
do {
  Start-Sleep -Seconds 20
  $raw = az rest --method post --url $queryUrl --body "@$queryFile" -o json
  if ($LASTEXITCODE -ne 0 -or -not $raw) {
    "Could not read the usage workspace."
    exit 1
  }
  $table = ($raw | ConvertFrom-Json).Tables[0]
  $columns = @($table.Columns | ForEach-Object { $_.ColumnName })
  $rows = @()
  if ($null -ne $table.Rows) { $rows = @($table.Rows) }
} while ($rows.Count -eq 0 -and (Get-Date) -lt $deadline)

if ($rows.Count -eq 0) {
  "No rows yet. Run this query again in a few minutes, in the usage workspace:"
  $query
} else {
  $columns -join "`t"
  foreach ($row in $rows) { $row -join "`t" }
}
