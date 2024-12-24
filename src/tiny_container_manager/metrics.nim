import
  prometheus as prom,
  nim_utils/logline

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

var containerCPUPerc* {.global.} = prom.newGauge(
  "tcm_container_cpu_perc",
  "",
  labelNames = @["site"]
)

var containerMemPerc* {.global.} = prom.newGauge(
  "tcm_container_mem_perc",
  "",
  labelNames = @["site"]
)

var containerMemBytes* {.global.} = prom.newGauge(
  "tcm_container_mem_bytes",
  "",
  labelNames = @["site"],
  unit = Unit.Bytes
)

var containerPIDs* {.global.} = prom.newGauge(
  "tcm_container_pids",
  "",
  labelNames = @["site"]
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
  # UPDATE 2024-11-25 - I am using a gc strategy with a shared heap due to being on Nim 2.x
  # It hasn't segfaulted yet!
  #
  {.gcsafe.}:
    return prom.generateLatest()
