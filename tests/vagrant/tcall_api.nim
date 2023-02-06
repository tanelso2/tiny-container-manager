import
    os,
    osproc,
    strformat,
    times,
    unittest,
    nim_utils/logline

proc checkApi() =
    let retVal = execCmd "curl --fail localhost:6969/metrics"
    assert retVal == 0

template waitForChecks(timeoutSeconds: Natural, body: untyped) =
  let startTime = getTime().toUnix
  var timeElapsed = getTime().toUnix - startTime
  while timeElapsed < timeoutSeconds:
    try:
        logInfo("time elapsed = " & $timeElapsed)
        `body`
        logInfo "Hooray we passed"
        break # We passed everything, break out
    except AssertionDefect:
        sleep(1000)
    finally:
        timeElapsed = getTime().toUnix - startTime

waitForChecks 120:
    checkApi()