import macros, json, jsony, strutils
export jsony, json
import pkg/colors

proc formatJsonNode(node: JsonNode, indent = 2, isArrayItem = false): string =
  const indentSize = 2
  let spaces = " ".repeat(indent)
  
  case node.kind
  of JObject:
    result = "\n"
    var first = true
    for key, value in node.pairs:
      if not first: result.add "\n"
      first = false
      # Key in cyan, colon in gray
      result.add spaces & key.cyan & ": ".black
      # Value with appropriate color and indentation
      result.add formatJsonNode(value, indent + indentSize)
  
  of JArray:
    if node.elems.len == 0:
      result &= "empty array".red.italic
    else:
      result = "\n"
      for i, item in node.elems:
        if i > 0: result.add "\n"
        # Add bullet point for array items
        result.add spaces & "- " & formatJsonNode(item, indent + indentSize, true).strip()

  of JString:
    # Strings in green
    if node.str == "...":
      result.add "...".yellow.italic
    else:
      result.add ("\"" & node.str & "\"").green
  
  of JInt:
    # Numbers in yellow
    result.add ($node.num).yellow
  
  of JFloat:
    # Floats in yellow
    result.add ($node.fnum).yellow
  
  of JBool:
    # Booleans in magenta
    result.add ($node.bval).magenta
  
  of JNull:
    # Null in red
    result.add "none".red.italic


proc shouldProcess(path: string, paths: openArray[string]): bool =
  for p in paths:
    if path.startsWith(p):
      return true
  false

proc processJsonPaths(node: var JsonNode, currentPath: string = "", deletePaths, collapsePaths: openArray[string]) =
  case node.kind
  of JObject:
    var keysToDelete: seq[string] = @[]
    var keysToCollapse: seq[string] = @[]
    
    for key in node.keys:
      let newPath = if currentPath.len > 0: currentPath & "." & key else: key
      if shouldProcess(newPath, deletePaths):
        keysToDelete.add(key)
      elif shouldProcess(newPath, collapsePaths):
        keysToCollapse.add(key)
      else:
        var value = node[key]
        processJsonPaths(value, newPath, deletePaths, collapsePaths)
        node[key] = value
        
    for key in keysToDelete:
      node.delete(key)
    for key in keysToCollapse:
      node[key] = %* "..."  # Replace with ellipsis
  
  of JArray:
    var i = 0
    for value in node.mitems:
      let newPath = currentPath
      if not shouldProcess(newPath, deletePaths):
        if shouldProcess(newPath, collapsePaths):
          value = %* "..."
        else:
          processJsonPaths(value, newPath, deletePaths, collapsePaths)
      inc i
  else:
    discard

macro displayable*(rawArgs: varargs[untyped]): untyped =
  if rawArgs.len != 1 and rawArgs.len != 2:
    error "displayable macro expects 1 or 2 arguments"
  let arg = rawArgs[0]
  var body = newStmtList()
  if rawArgs.len == 2:
    body = rawArgs[1]
    if body.kind != nnkStmtList:
      error "displayable macro expects a statement list as the second argument"
  
  var deletePaths: seq[string] = @[]
  var collapsePaths: seq[string] = @[]
  
  for child in body:
    expectKind(child, nnkCommand)
    expectLen(child, 2)
    expectKind(child[1], nnkStrLit)
    let operation = child[0].strVal
    let path = child[1].strVal
    
    case operation
    of "delete":
      deletePaths.add path
    of "collapse":
      collapsePaths.add path
    else:
      error "displayable macro expects only 'delete' or 'collapse' commands"

  let T = arg
  let argName = ident(arg.strVal.toLower)
  let prettyName = newStrLitNode(arg.strVal)
  
  # Create the paths arrays at compile time
  let deletePathsNode = newTree(nnkBracket)
  deletePathsNode.add newStrLitNode("-")
  for path in deletePaths:
    deletePathsNode.add newStrLitNode(path)

  let collapsePathsNode = newTree(nnkBracket)
  collapsePathsNode.add newStrLitNode("-")
  for path in collapsePaths:
    collapsePathsNode.add newStrLitNode(path)

  result = quote do:
    proc pretty*(`argName`: `T`): string =
      let jsonStr = `argName`.toJson()
      var jsonNode = parseJson(jsonStr)
      
      # Convert the compile-time arrays to runtime arrays
      let deletePaths = `deletePathsNode`
      let collapsePaths = `collapsePathsNode`
      
      # Process the paths
      processJsonPaths(jsonNode, "", deletePaths, collapsePaths)
      
      result = `prettyName`.cyan & ":\n  " & formatJsonNode(jsonNode).strip()



when isMainModule:
  # Example usage:
  type
    Hobby = object
      name: string
      hoursPerWeek: int

    Person = object
      name: string
      age: int
      hobbies: seq[Hobby]
      address: Address

    Address = object
      street: string
      city: string
    
  displayable(Person):
    collapse "address.city"
    delete "hobbies.hoursPerWeek"
  
  let person = Person(
    name: "John Doe",
    age: 30,
    hobbies: @[Hobby(name: "Cycling", hoursPerWeek: 5), Hobby(name: "Reading", hoursPerWeek: 10)],
    address: Address(
      street: "123 Main St",
      city: "Springfield"
    )
  )
  
  echo person.pretty()