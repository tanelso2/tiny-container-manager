import
  tiny_container_manager/[
    collection,
    container,
    docker,
    nginx
  ],
  asyncdispatch,
  sugar

proc disableOnChange*[I,E](this: ManagedCollection[I,E]) =
  proc onChange(cr: ChangeResult[I,E]) {.async.} =
    discard
  this.onChange = onChange

# This doesn't work because it doesn't know how to make a Future of a generic type
#
# proc mkExpected*[I,E](this: ManagedCollection[I,E], expected: seq[I]) =
#   proc f[I](): Future[seq[I]] =
#     let fut = newFuture[seq[I]]()
#     fut.complete(x)
#     return fut
#   this.getExpected = f
# 
# So we use a template instead and instantiate it for each collection

template mkExpectedMethod(I: untyped, E: untyped, collType: untyped) =
  proc mkExpected*(this: collType, expected: seq[I]) =
    proc f(): Future[seq[I]] =
      let fut = newFuture[seq[I]]()
      fut.complete(expected)
      return fut
    this.getExpected = f

mkExpectedMethod Container, DContainer, ContainersCollection
mkExpectedMethod NginxConfig, ActualNginxConfig, NginxConfigsCollection
mkExpectedMethod EnabledLink, NginxEnabledFile, NginxEnabledCollection

