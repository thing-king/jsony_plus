import macros, tables, os, strutils
export tables

proc repr*[K, V](tbl: Table[K, V]): string =
  # Create a valid Nim constructor syntax
  result = "["
  var first = true
  var empty = true
  for key, val in tbl.pairs:
    empty = false
    if not first:
      result.add(", ")
    result.add("(\"" & key & "\", " & val.repr & ")")
    first = false
  result.add("].toTable")
  if empty:
    result = "initTable[" & $K & ", " & $V & "]()"
macro cacheSchema*(pathNode: untyped, writePathNode: untyped, body: untyped): untyped =
  expectKind(pathNode, nnkStrLit)
  expectKind(writePathNode, nnkStrLit)
  let path = pathNode.strVal
  let writePath = writePathNode.strVal

  var handled = false

  when not defined(js):
    if not fileExists(path):
      result = newStmtList()
      for node in body:
        expectKind(node, nnkCommand)
        if node[0].strVal != "fromSchema":
          error "Only fromSchema commands are allowed in cache2"
        node.add newStrLitNode(writePath)

        result.add node
      handled = true
      
  if not handled:
    # echo "Importing cache 2"
    let path = newStrLitNode("../" & path)
    let fileName = ident(path.strVal.replace(".nim", "").split("/")[^1])
    result = quote do:
      import `path`
      export `fileName`
    # echo "Done 2"
  
  # echo result.repr

macro cacheTypes*(pathNode: untyped, schemaLocalPathNode: untyped, body: untyped): untyped =
  expectKind(pathNode, nnkStrLit)
  let path = pathNode.strVal
  let schemaLocalPath = schemaLocalPathNode.strVal


  var handled = false
  when not defined(js):
    if not fileExists(path):
      var names: seq[NimNode] = @[]

      let writeBody = ident("writeBody")

      result = newStmtList()
      result.add quote do:
        var `writeBody`: string = "import \"" & `schemaLocalPath` & "\"\nimport tables, options, jsony\n\n"

      for node in body:
        if node.kind == nnkConstSection:
          let nameIdent = node[0][0]
          if nameIdent.kind == nnkPostfix:
            if nameIdent[0].strVal == "*":
              names.add(nameIdent[1])
    
      result.add body
      for name in names:
        let nameStr = name.strVal
        result.add quote do:
          `writeBody` = `writeBody` & "\nconst " & `nameStr` & "* = " & `name`.repr.replace("\n", "")

      result.add quote do:
        # make sure newlines are ascii only
        writeFile(`path`, `writeBody`)

      handled = true
  
  if not handled:
    # echo "Importing cache 1"
    let pathNode = newStrLitNode(path)
    let fileName = ident(pathNode.strVal.replace(".nim", "").split("/")[^1])
    result = quote do:
      import `pathNode`
      export `fileName`