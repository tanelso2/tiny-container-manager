import 
  jester,
  json,
  streams,
  yaml

export yaml

proc jsonDump*[T](t: T, s: Stream) =
  dump(t, s, options = defineOptions(style = psJson))

proc jsonDump*[T](t: T): string =
  {.gcsafe.}:
    dump(t, options = defineOptions(style = psJson))

proc jsonBody*[T](r: jester.request.Request, t: typedesc[T]): T =
  let jsonNode = parseJson(r.body)
  return jsonNode.to(t)

template jsonResp*(s: string) =
  resp s, contentType = "application/json"

template jsonResp*[T](t: T) =
  jsonResp jsonDump(t)


