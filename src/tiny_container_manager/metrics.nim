import
  prometheus as prom

export prom

var runs = prom.newCounter(
  "tcm_runs",
  ""
)

proc incRuns*() =
  {.gcsafe.}:
    runs.inc()

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

var nginxCheckStarts* {.global.} = prom.newCounter(
  "tcm_nginx_check_starts",
  "",
  @[]
)

var nginxCheckFinishes* {.global.} = prom.newCounter(
  "tcm_nginx_check_finishes",
  "",
  @[]
)

var tcmOpenFiles* {.global.} = prom.newGauge(
  "tcm_open_files",
  "Number of open files held by tcm",
  @[]
)

var tcmMemSize* {.global.} = prom.newGauge(
  "tcm_mem_size_kb",
  "",
  @[]
)

var tcmMemPeak* {.global.} = prom.newGauge(
  "tcm_mem_peak_kb",
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
