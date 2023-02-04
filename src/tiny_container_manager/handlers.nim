import
  asyncdispatch,
  macros,
  sugar,
  os,
  ./cert,
  ./events,
  ./metrics,
  ./container_collection,
  ./collection,
  ./shell_utils,
  nginx/[
    config_collection,
    enabled_collection
  ],
  nim_utils/logline

proc eventEmitterSetup*(em: EventManager) {.async.} =
  # asyncCheck em.triggerRepeat(newEvent(evFlushStdout), 5)
  # asyncCheck em.triggerRepeat(newEvent(evCleanLEBackups), 300)
  asyncCheck em.triggerRepeat(newEvent(evRunCheck), 15)
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

  proc handleRunCheck(e: Event) {.async.} =
    assertEvent e, evRunCheck
    logInfo("Running all the checks!")
    metrics.incRuns()
    asyncCheck cc.ensureDiscardResults()
    asyncCheck ncc.ensureDiscardResults()
    asyncCheck nec.ensureDiscardResults()

  proc handleRunCC(e: Event) {.async.} =
    assertEvent e, evRunCheck
    logInfo("Running cc ensure")
    asyncCheck cc.ensureDiscardResults()

  proc handleRunNCC(e: Event) {.async.} =
    assertEvent e, evRunCheck
    logInfo("Running ncc ensure")
    asyncCheck ncc.ensureDiscardResults()

  proc handleRunNEC(e: Event) {.async.} =
    assertEvent e, evRunCheck
    logInfo("Running nec ensure")
    asyncCheck nec.ensureDiscardResults()

  proc handleIncRunCount(e: Event) {.async.} =
    assertEvent e, evRunCheck
    logInfo("Incrementing metrics")
    metrics.incRuns()

  # em.registerHandler(evRunCheck, handleIncRunCount)
  # em.registerHandler(evRunCheck, handleRunCC)
  # em.registerHandler(evRunCheck, handleRunNCC)
  em.registerHandler(evRunCheck, handleRunNEC)

  #em.registerHandler(evRunCheck, handleRunCheck)

  proc handleTest(e: Event) {.async.} =
    assertEvent e, evTest
    logInfo("Handling the test event")
    await checkNginxService()
  
  em.registerHandler(evTest, handleTest)
