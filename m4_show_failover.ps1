# M4 — the preferred backend fails, the caller still gets an answer.
# One call as Team B. Expect status 200 and x-ai-backend=fallback.

$keys = terraform output -json team_subscription_keys | ConvertFrom-Json
$url  = terraform output -raw gateway_chat_completions_url
$body = '{"messages":[{"role":"user","content":"Say hello"}]}'

try {
  $r = Invoke-WebRequest -Uri $url -Method POST -Body $body `
    -Headers @{ "Ocp-Apim-Subscription-Key" = $keys.'team-b'; "Content-Type" = "application/json" }
  "status=$($r.StatusCode)  served-by=$($r.Headers['x-ai-backend'])"
} catch {
  $resp = $_.Exception.Response
  "status=$($resp.StatusCode.value__)  (caller saw the failure)"
}