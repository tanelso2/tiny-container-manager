import
    times,
    nim_utils/logline

template waitForChecks*(timeoutSeconds: Natural, body: untyped) =
  let startTime = getTime().toUnix
  var timeElapsed = getTime().toUnix - startTime
  while timeElapsed < timeoutSeconds:
    try:
        logDebug("time elapsed = " & $timeElapsed)
        `body`
        break # We passed everything, break out
    except AssertionDefect:
        sleep(1000)
    finally:
        timeElapsed = getTime().toUnix - startTime
  # Run the tests again as a final check/fail
  `body`
