# https://man7.org/linux/man-pages/man5/proc.5.html

import
  os,
  strutils,
  std/posix,
  nim_utils/logline,
  ./metrics

type
  ProcInfo* = object
    pid*: Natural
    openFiles*: Natural
    memSize*: Natural
    memPeak*: Natural

proc getProcStatus: string =
  return readFile("/proc/self/status")

proc countOpenFiles*: Natural =
  result = 0
  for _ in walkFiles("/proc/self/fdinfo/*"):
    result += 1

proc getProcInfo*(): ProcInfo =
  let pid = getpid()
  var memSize = 0
  var memPeak = 0
  for line in getProcStatus().splitLines:
    let words = line.splitWhitespace()
    if len(words) == 0:
      continue
    case words[0]
    of "VmPeak:":
      memPeak = parseInt words[1]
      if words[2] != "kB":
        logError "VmPeak wasn't in kB"
    of "VmSize:":
      memSize = parseInt words[1]
      if words[2] != "kB":
        logError "VmSize wasn't in kB"
  result = ProcInfo(
    pid: pid,
    openFiles: countOpenFiles(),
    memSize: memSize,
    memPeak: memPeak
  )

proc updateProcInfoMetrics* =
  let info = getProcInfo()
  tcmMemSize.set(info.memSize)
  tcmOpenFiles.set(info.openFiles)
