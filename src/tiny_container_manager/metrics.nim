import
  asyncdispatch,
  prometheus as prom

export prom

when isFutureLoggingEnabled:
  import
    prometheus/collectors/asynccollector
  let asyncCollector = newAsyncCollector()

var runs = prom.newCounter(
  "tcm_runs",
  ""
)

var iters* = prom.newGauge(
  "tcm_iterations",
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

var letsEncryptBackupsDeleted* {.global.} = prom.newCounter(
  "tcm_letsencrypt_backups_deleted",
  "",
  @[]
)

proc getOutput*(): string =
  #
  # No idea if actually gcsafe, just want compiler to shut up
  #
  # If I'm worried about thread safety of the metrics variables,
  # maybe I should switch to using a gc strategy that has a shared heap?
  # https://nim-lang.org/docs/gc.html
  #
  {.gcsafe.}:
    return prom.generateLatest()
