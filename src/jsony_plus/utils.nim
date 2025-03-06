import strutils

proc toEnumValue*(propertyName: string, enumValue: string): string =
  proc generateAcronym(input: string): string =
    result = ""
    var isNewWord = true
    
    for i, letter in input:
      if letter == '_':  # Just mark next letter as start of new word
        isNewWord = true
      elif (i == 0 or isNewWord) and letter.isAlphaAscii():  # First letter of word
        result.add(letter.toLowerAscii())
        isNewWord = false
      elif letter.isUpperAscii():  # Uppercase in camelCase
        result.add(letter.toLowerAscii())

  proc generateEnumName(input: string): string =
    result = ""
    var prevCharIsLowercase = true
    for i, letter in input:
      if letter.isUpperAscii():
        if i > 0 and prevCharIsLowercase:
          result.add('_')
        prevCharIsLowercase = false
      else:
        prevCharIsLowercase = true
      result.add(letter)
    result = result.toUpperAscii()
  
  var cleanPropertyName = propertyName
  # if cleanPropertyName, ends in Enum- remove it
  if cleanPropertyName.endsWith("Enum"):
    cleanPropertyName = cleanPropertyName[0..^5]
  let REMOVE_CHARS = @[
    ":", "+", "*", "/", "\\", "(", ")", "[", "]", "{", "}", "<", ">", "=", "!", "@", "#", "$", "%", "^", "&", "|", "~", "`", ",", ".", "?", ":", ";", "'", "\""
  ]
  var cleanStr = enumValue
  for c in REMOVE_CHARS:
    cleanStr = cleanStr.replace(c, "")
  let UNDERSCORE_CHARS = @[
    " ", "-", "_"
  ]
  for c in UNDERSCORE_CHARS:
    cleanStr = cleanStr.replace(c, "_")
  result = cleanPropertyName.generateAcronym() & cleanStr.generateEnumName().replace("__", "_")

