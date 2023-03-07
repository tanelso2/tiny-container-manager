discard """
"""

import
    os,
    osproc,
    times,
    nim_utils/logline,
    ../test_utils/waiting

waitForChecks 120:
  let retVal = execCmd "curl --fail localhost:6969/metrics"
  assert retVal == 0