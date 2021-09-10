import
  locks,
  prometheus as prom

var uptimeMetric* = prom.newCounter(
  "tcm_uptime",
  "",
  @["site"]
)

var healthCheckStatus* = prom.newCounter(
  "tcm_healthcheck",
  "",
  @["site", "checktype", "result"]
)

var containerStarts* = prom.newCounter(
  "tcm_container_starts",
  "",
  @["site"]
)

var letsEncryptRuns* = prom.newCounter(
  "tcm_letsencrypt_runs",
  "",
  @["site"]
)

var nginxConfigsWritten* = prom.newCounter(
  "tcm_nginx_configs",
  "",
  @["site"]
)

proc getOutput*(): string =
  return prom.generateLatest()
