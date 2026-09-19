$keys = terraform output -json team_subscription_keys | ConvertFrom-Json
$url  = terraform output -raw gateway_chat_completions_url
$body = '{"messages":[{"role":"user","content":"Say hello"}]}'

# Team A (low cap) — hammer it until it trips
foreach ($i in 1..15) {
  try {
    $r = Invoke-WebRequest -Uri $url -Method POST -Body $body `
      -Headers @{ "Ocp-Apim-Subscription-Key" = $keys.'team-a'; "Content-Type" = "application/json" }
    "Call $i : $($r.StatusCode)  remaining=$($r.Headers['x-remaining-tokens'])"
  } catch {
    "Call $i : $($_.Exception.Response.StatusCode.value__)  <-- rate limited (429)"
  }
}

# Team B (normal cap) — should still work
try {
  $r = Invoke-WebRequest -Uri $url -Method POST -Body $body `
    -Headers @{ "Ocp-Apim-Subscription-Key" = $keys.'team-b'; "Content-Type" = "application/json" }
  "Team B: $($r.StatusCode) - still working while Team A is capped"
} catch {
  "Team B: $($_.Exception.Response.StatusCode.value__)"
}