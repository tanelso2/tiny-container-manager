import
  std/options,
  std/sugar,
  std/times

proc mkTimedCache*[A](f: () -> A, length: Duration): () -> A =
  var prevOutput: Option[A] = none(A)
  var prevTime: DateTime = now() - length - initDuration(days = 1)

  proc ret(): A =
    let currentTime = now()
    if prevOutput.isSome() and currentTime <= prevTime + length:
      return prevOutput.get()
    else:
      let o = f()
      prevOutput = some(o)
      prevTime = currentTime
      return o

  return ret
