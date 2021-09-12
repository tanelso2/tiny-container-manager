import
  prometheus as prom

var runs = prom.newCounter(
  "tcm_runs",
  ""
)

proc incRuns*() =
  {.gcsafe.}:
    runs.inc()

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

var letsEncryptRuns* {.global.} = prom.newCounter(
  "tcm_letsencrypt_runs",
  "",
  @["site"]
)

var nginxConfigsWritten* {.global.} = prom.newCounter(
  "tcm_nginx_configs",
  "",
  @["site"]
)

proc getOutput*(): string =
  # No idea if actually gcsafe, just want compiler to shut up
  {.gcsafe.}:
    return prom.generateLatest()
