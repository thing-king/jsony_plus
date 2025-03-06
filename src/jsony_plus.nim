# jsony
import jsony
export jsony

# std
import macros
import strutils, options

# pragma
template json*(name: string) {.pragma.}


# TODO: throw warning when an un-allowed serialization happens to catch unthrown issues

macro allowSerialization*(T: typed) =
  # scans supplied type to construct `dumpHook` and `renameHook` aligning with `{.json: "new_name"}` rename pragma
  # more things aught to come here

  type Override = object
    typeName: string
    jsonName: string
  var overrides: seq[Override] = @[Override(typeName: "", jsonName: "")]
  var name: string

  let typeDef = T.getImpl()
  let sym = typeDef[0]
  name = sym.strVal
  # echo "Allowing serialization for: " & sym.strVal
  # echo typeDef.treeRepr
  if typeDef.kind != nnkTypeDef:
    # hint "Expected a type definition, got: " & $typeDef.kind, typeDef
    return
  if typeDef[2].kind notin {nnkObjectTy, nnkRefTy}:
    # hint "Expected an object type, got: " & $typeDef[2].kind, typeDef[2]
    return

  var objTy = typeDef[2]
  if objTy.kind == nnkRefTy:
    objTy = objTy[0]
  
  let recList = objTy[2]
    
    # echo recList.treeRepr

  proc handleDef(node: NimNode) =
    proc nameStrVal(node: NimNode): string =
      if node.kind == nnkIdent:
        return node.strVal
      elif node.kind == nnkPostfix:
        return nameStrVal(node[1])
      else:
        error "Unknown kind: " & $node.kind, node
    
    if node.kind != nnkIdentDefs:
      error "Expected an identDefs, got: " & $node.kind, node
    let name = node[0]
    if name.kind == nnkPragmaExpr:
      let nameIdent = name[0]
      let pragma = name[1]
      for pragmaItem in pragma:
        if pragmaItem.kind == nnkExprColonExpr:
          let pragmaName = pragmaItem[0]
          let pragmaValue = pragmaItem[1]
          if pragmaName.strVal == "json":
            let typeName = nameStrVal(nameIdent)
            let jsonName = pragmaValue.strVal
            # echo "Convert json name '" & jsonName & "' to '" & typeName & "'"

            overrides.add(Override(typeName: typeName, jsonName: jsonName))
  for field in recList:
    if field.kind == nnkIdentDefs:
      handleDef(field)
    if field.kind == nnkRecCase:
      for branch in field:
        if branch.kind == nnkIdentDefs:
          handleDef(field[0])
        elif branch.kind == nnkOfBranch:
          let branchList = branch[^1]
          if branchList.kind != nnkRecList:
            error "Unknown branch body kind: " & $branchList.kind, branchList
          for branchField in branchList:
            if branchField.kind == nnkIdentDefs:
              handleDef(branchField)
            elif branchField.kind == nnkNilLit:
              discard
            else:
              error "Unknown branch field kind: " & $branchField.kind, branchField
        elif branch.kind == nnkElse:
          let elseList = branch[0]
          if elseList.kind != nnkRecList:
            error "Unknown else body kind: " & $elseList.kind, elseList
          for elseField in elseList:
            if elseField.kind == nnkIdentDefs:
              handleDef(elseField)
            elif elseField.kind == nnkNilLit:
              discard
            else:
              error "Unknown else field kind: " & $elseField.kind, elseField
        else:
          error "Unknown kind: " & $branch.kind, branch
  result = quote do:
    proc renameHook*(t: var `T`, fieldName: var string) =
      # echo "Field name: " & fieldName
      for override in `overrides`:
        if fieldName == override.jsonName:
          fieldName = override.typeName
    proc dumpHook*(s: var string, t: `T`) =
      template addField(name: string, value: untyped, first: var bool) =
        when compiles(toJson(value)):
          if not first:
            s.add ","
          first = false
          var jsonName = name
          for override in `overrides`:
            if name == override.typeName:
              jsonName = override.jsonName
          s.add "\""
          s.add jsonName
          s.add "\":"
          when value is ref:
            if value == nil:
              s.add "null"
            else:
              s.add value.toJson()
          else:
            s.add value.toJson()

      s.add "{"
      var first = true
      when t is ref:
        for name, value in t[].fieldPairs:
          when value is Option:
            if value.isSome and compiles(toJson(value.get)):
              addField(name, value.get, first)
          else:
            addField(name, value, first)
      else:
        for name, value in t.fieldPairs:
          when value is Option:
            if value.isSome and compiles(toJson(value.get)):
              addField(name, value.get, first)
          else:
            addField(name, value, first)
      s.add "}"

proc stripEmptyObjects*(s: string): string =
  result = s.replace(":{}", ":null").replace(": {}", ": null")
proc parse*[T](jsonStr: string): T =
  result = fromJson(stripEmptyObjects(jsonStr), T)
proc to*[T](jsonStr: string): T =
  result = parse[T](jsonStr)
proc to*(jsonStr: string, T: typedesc): T =
  result = parse[T](jsonStr)

# Creates a blank object of type T and compares it to given X to determine if X is empty (default object)
proc isEmpty*[T](x: T): bool =
  template isFieldEmpty[T](x: T): bool =
    type defaultObj = object
      value: T
    defaultObj().value == x
  
  when T is ref:
    if x == nil: return true
    for name, field in x[].fieldPairs:
      if not isFieldEmpty(field):
        return false
  else:
    for name, field in x.fieldPairs:
      if not isFieldEmpty(field):
        return false
  return true

proc isOf*[T](jsonStr: string): bool =
  not (parse[T](jsonStr)).isEmpty()

proc tryParse*[T](jsonStr: string): Option[T] =
  try:
    let parsed = parse[T](jsonStr)
    if parsed.isEmpty():
      return none(T)
    return some(parsed)
  except:
    result = none(T)

proc pretty*(json: string): string =
 var 
   indent = 0
   inQuote = false
   
 template addIndent() =
   result.add("\n")
   for i in 0..<indent: result.add("  ")
   
 for i, c in json:
   if c == '"' and (i == 0 or json[i-1] != '\\'):
     inQuote = not inQuote
     result.add(c)
   elif inQuote:
     result.add(c) 
   else:
     case c:
       of '{', '[':
         result.add(c)
         indent.inc
         addIndent()
       of '}', ']':
         indent.dec
         addIndent()
         result.add(c)
       of ',':
         result.add(c)
         addIndent()
       else:
         result.add(c)