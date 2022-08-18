import
  ./collection,
  asyncdispatch,
  sugar

proc disableOnChange*[I,E](this: ManagedCollection[I,E]) =
  proc onChange(cr: ChangeResult[I,E]) {.async.} =
    discard
  this.onChange = onChange

# proc mkExpectedProc*[I](x: seq[I]): () -> Future[seq[I]] =
#   proc f[I](): Future[seq[I]] =
#     let fut = newFuture[seq[I]]()
#     fut.complete(x)
#     return fut
#   return f
