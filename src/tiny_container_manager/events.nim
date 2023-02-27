import 
    asyncdispatch,
    sequtils,
    strformat,
    sugar,
    tables,
    ./async_utils,
    ./container,
    nim_utils/logline

type
    EventKind* = enum
        evCreateContainer,
        evRunCheck,
        evFlushStdout,
        evCleanLEBackups,
        evTest
    Event* = object
        case kind*: EventKind
        of evCreateContainer:
            spec*: Container
        of evRunCheck, evTest, evCleanLEBackups, evFlushStdout:
            discard
    EventHandler* = ((e: Event) {.async.} -> Future[void])
    EventManager* = object
        handlers*: TableRef[EventKind, seq[EventHandler]]

proc triggerEvent*(manager: EventManager, e: Event) {.async.} =
    logDebug fmt"Triggering {e.kind=}"
    flushFile(stdout)
    for handler in manager.handlers.getOrDefault(e.kind, @[]):
        await handler(e)
    logDebug fmt"Done triggering {e.kind=}"

proc registerHandler*(manager: EventManager, ek: EventKind, handler: EventHandler) =
    var handlers = manager.handlers.getOrDefault(ek, @[])
    handlers.add(handler)
    manager.handlers[ek] = handlers

proc newManager*(): EventManager =
    let handlers = newTable[EventKind, seq[EventHandler]]()
    EventManager(handlers: handlers)

proc assertEvent*(e: Event, ek: EventKind) =
    if e.kind != ek:
        raise newException(ValueError, fmt"{e.kind} != expected {ek}")

proc triggerRepeat*(manager: EventManager, e: Event, sleepSeconds: Natural) {.async.} =
    proc f() {.async.} =
        await manager.triggerEvent(e)
    asyncCheck asyncLoop(f, sleepSeconds) 

proc newEvent*(kind: EventKind): Event =
    Event(kind: kind)