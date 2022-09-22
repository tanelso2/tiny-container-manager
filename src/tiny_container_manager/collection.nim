import
  sequtils,
  sugar,
  asyncdispatch

type
  ManagedCollection*[I, E] = ref object of RootObj
    ##
    ## Manages a collection of Objects.
    ## I is the internal representation of an object
    ## E is the external representation of an object
    ## For example, we have a Container definition for our internal definition,
    ## and a DContainer definition representing the actual docker containers that exist on the system.
    ##
    getExpected*: (() {.async.} -> Future[seq[I]])
    getWorldState*: (() {.async.} -> Future[seq[E]])
    matches*: (I, E) -> bool
    remove*: ((dc: E) {.async.} -> Future[void])
    create*: ((I) {.async.} -> Future[void])
    onChange*: ((ChangeResult[I,E]) {.async.} -> Future[void])
  ChangeResult*[I,E] = ref object of RootObj
    added*: seq[I]
    removed*: seq[E]

proc removeUnexpected[I,E](this: ManagedCollection[I,E]): Future[seq[E]] {.async.} =
  result = newSeq[E](0)
  let expected = await this.getExpected()
  let world = await this.getWorldState()
  for w in world:
    if not expected.anyIt(this.matches(it, w)):
      await this.remove(w)
      result.add(w)

proc createMissing[I,E](this: ManagedCollection[I,E]): Future[seq[I]] {.async.} =
  result = newSeq[I](0)
  let expected = await this.getExpected()
  let world = await this.getWorldState()
  for e in expected:
    if not world.anyIt(this.matches(e, it)):
      await this.create(e)
      result.add(e)

proc ensure*[I,E](this: ManagedCollection[I,E]): Future[ChangeResult[I,E]] {.async.} =
  let removed = await this.removeUnexpected()
  let created = await this.createMissing()
  result = ChangeResult[I,E](added: created, removed: removed)
  if result.anythingChanged:
    await this.onChange(result)

proc anythingChanged*[I,E](this: ChangeResult[I,E]): bool =
  len(this.added) != 0 or len(this.removed) != 0
