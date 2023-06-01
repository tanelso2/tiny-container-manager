import
  asyncdispatch,
  ./cert,
  ./events,
  ./metrics,
  ./container_collection,
  ./collection,
  ./procinfo,
  ./shell_utils,
  nginx/[
    config_collection,
    enabled_collection
  ],
  nim_utils/logline

proc eventEmitterSetup*(em: EventManager) {.async.} =
  asyncCheck em.triggerRepeat(newEvent(evUpdateProcMetrics), 15)
  asyncCheck em.triggerRepeat(newEvent(evFlushStdout), 5)
  asyncCheck em.triggerRepeat(newEvent(evCleanLEBackups), 300)
  asyncCheck em.triggerRepeat(newEvent(evRunCheck), 5)
  asyncCheck em.triggerRepeat(newEvent(evTest), 15)

proc eventHandlerSetup*(em: EventManager,
                        cc: ContainersCollection,
                        ncc: NginxConfigsCollection,
                        nec: NginxEnabledCollection) {.async.} =

  proc handleFlush(e: Event) {.async.} =
    assertEvent e, evFlushStdout
    flushFile(stdout)

  em.registerHandler(evFlushStdout, handleFlush)

  proc handleCleanLEBackups(e: Event) {.async.} =
    assertEvent e, evCleanLEBackups
    logInfo("Cleaning up the letsencrypt backups")
    cleanUpLetsEncryptBackups()

  em.registerHandler(evCleanLEBackups, handleCleanLEBackups)

  proc handleRunCC(e: Event) {.async.} =
    assertEvent e, evRunCheck
    logInfo("Running cc ensure")
    await cc.ensureDiscardResults()

  proc handleRunNCC(e: Event) {.async.} =
    assertEvent e, evRunCheck
    logInfo("Running ncc ensure")
    await ncc.ensureDiscardResults()

  proc handleRunNEC(e: Event) {.async.} =
    assertEvent e, evRunCheck
    logInfo("Running nec ensure")
    await nec.ensureDiscardResults()

  proc handleIncRunCount(e: Event) {.async.} =
    assertEvent e, evRunCheck
    logInfo("Incrementing run count")
    metrics.incRuns()
  
  proc handleCreateContainer(e: Event) {.async.} =
    assertEvent e, evCreateContainer
    await cc.ensureDiscardResults()

  em.registerHandler(evRunCheck, handleIncRunCount)
  em.registerHandler(evRunCheck, handleRunCC)
  em.registerHandler(evRunCheck, handleRunNCC)
  em.registerHandler(evRunCheck, handleRunNEC)

  proc handleMetricsUpdate(e: Event) {.async.} =
    assertEvent e, evUpdateProcMetrics
    logInfo "Updating metrics"
    updateProcInfoMetrics()

  em.registerHandler(evUpdateProcMetrics, handleMetricsUpdate)