import
  asyncdispatch,
  os,
  ./cert,
  ./events,
  ./metrics,
  ./container_collection,
  ./collection,
  nginx/[
    config_collection,
    enabled_collection
  ],
  nim_utils/logline

proc eventEmitterSetup*(em: EventManager) {.async.} =
  asyncCheck em.triggerRepeat(newEvent(evFlushStdout), 5)
  asyncCheck em.triggerRepeat(newEvent(evCleanLEBackups), 300)
  asyncCheck em.triggerRepeat(newEvent(evRunCheck), 15)

proc eventHandlerSetup*(em: EventManager,
                        cc: ContainersCollection,
                        ncc: NginxConfigsCollection,
                        nec: NginxEnabledCollection) {.async.} =

  proc handleFlush(e: Event) {.async.} =
    assertEvent e, evFlushStdout
    logInfo "Handling a flush"
    flushFile(stdout)

  em.registerHandler(evFlushStdout, handleFlush)

  proc handleCleanLEBackups(e: Event) {.async, gcsafe.} =
    assertEvent e, evCleanLEBackups
    logInfo("Cleaning up the letsencrypt backups")
    {.gcsafe.}:
      cleanUpLetsEncryptBackups()

  em.registerHandler(evCleanLEBackups, handleCleanLEBackups)

  proc handleRunCheck(e: Event) {.async,gcsafe.} =
    assertEvent e, evRunCheck
    logInfo("Running all the checks!")
    metrics.incRuns()
    {.gcsafe.}:
      asyncCheck cc.ensureDiscardResults()
      asyncCheck ncc.ensureDiscardResults()
      asyncCheck nec.ensureDiscardResults()

  em.registerHandler(evRunCheck, handleRunCheck)