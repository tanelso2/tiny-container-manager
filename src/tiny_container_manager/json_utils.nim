import 
  jester,
  json,
  streams,
  yaml

export yaml

proc jsonDump*[T](t: T, s: Stream) =
  jsonDumper().dump(t, s)

proc jsonDump*[T](t: T): string =
  {.gcsafe.}:
    jsonDumper().dump(t)

proc jsonBody*[T](r: jester.request.Request, t: typedesc[T]): T =
  let jsonNode = parseJson(r.body)
  return jsonNode.to(t)

template jsonResp*(s: string) =
  resp s, contentType = "application/json"

template jsonResp*[T](t: T) =
  jsonResp jsonDump(t)
