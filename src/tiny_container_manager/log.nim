import
  std/logging,
  strutils

var logger = newConsoleLogger(fmtStr="[$time] - $levelname: ")

template logDebug*(msg: string): typed =
  let pos = instantiationInfo()
  logger.log(lvlDebug, "$1:$2 $3" % [pos.filename, $pos.line, msg])
