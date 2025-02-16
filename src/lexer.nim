import std/[streams, tables, options]
from std/strformat import fmt
from std/strutils import isDigit, parseFloat, isAlphaNumeric, join

const 
    WHITESPACE* = ['\t', '\n', '\r', ' '] 
    SYMBOLS* = ['(', ')', '[', ']', '<', '>', ',', '*']

#----------------------------------------------------#
#                SourceLocation type                 #
#----------------------------------------------------#
type SourceLocation* = object
    filename*: string = ""
    lineNum*: int = 0
    colNum*: int = 0

proc newSourceLocation*(name = "", line: int = 0, col: int = 0): SourceLocation {.inline.} = 
    # SourceLocation variable constructor
    SourceLocation(filename: name, lineNum: line, colNum: col)


proc `$`*(location: SourceLocation): string {.inline.} =
    # Procedure that prints SourceLocation contents, useful for error signaling
    result = "File: " & location.filename & ", Line: " & $location.lineNum & ", Column: " & $location.colNum



#---------------------------------------------------#
#                    Token type                     #
#---------------------------------------------------#
type KeywordKind* = enum
    # Different kinds of key
    
    NEW = 1,
    TRANSLATION = 2,
    ROTATION_X = 3,
    ROTATION_Y = 4,
    ROTATION_Z = 5,
    SCALING = 6,
    COMPOSITION = 7,
    IDENTITY = 8,
    CAMERA = 9,
    ORTHOGONAL = 10,
    PERSPECTIVE = 11,
    PLANE = 12,
    SPHERE = 13,
    AABOX = 14,
    TRIANGLE = 15,
    CYLINDER = 16,
    ELLIPSOID = 17,
    TRIANGULARMESH = 18, 
    MATERIAL = 19,
    DIFFUSE = 20,
    SPECULAR = 21,
    UNIFORM = 22,
    CHECKERED = 23,
    TEXTURE = 24,
    FLOAT = 25,
    IMAGE = 26,
    BOX = 27,
    CSGUNION = 28


const KEYWORDS* = {
    "new": KeywordKind.NEW,
    "translation": KeywordKind.TRANSLATION,
    "rotationX": KeywordKind.ROTATION_X,    
    "rotationY": KeywordKind.ROTATION_Y,
    "rotationZ": KeywordKind.ROTATION_Z,
    "scaling": KeywordKind.SCALING,
    "composition": KeywordKind.COMPOSITION,
    "identity": KeywordKind.IDENTITY,
    "camera": KeywordKind.CAMERA,
    "orthogonal": KeywordKind.ORTHOGONAL,
    "perspective": KeywordKind.PERSPECTIVE,
    "plane": KeywordKind.PLANE,
    "sphere": KeywordKind.SPHERE,
    "aabox": KeywordKind.AABOX,
    "triangle": KeywordKind.TRIANGLE,
    "cylinder": KeywordKind.CYLINDER,
    "ellipsoid": KeywordKind.ELLIPSOID,
    "triangularMesh": KeywordKind.TRIANGULARMESH,
    "material": KeywordKind.MATERIAL,
    "diffuse": KeywordKind.DIFFUSE,
    "specular": KeywordKind.SPECULAR,
    "uniform": KeywordKind.UNIFORM,
    "checkered": KeywordKind.CHECKERED,
    "texture": KeywordKind.TEXTURE,
    "float": KeywordKind.FLOAT,
    "image": KeywordKind.IMAGE,
    "box": KeywordKind.BOX,
    "csgUnion": KeywordKind.CSGUNION
}.toTable


type 
    
    TokenKind* = enum
        # Defining possible token kinds

        KeywordToken,
        IdentifierToken,
        LiteralStringToken,
        LiteralNumberToken,
        SymbolToken,
        StopToken

    Token* = object
        # Token type 
        location*: SourceLocation

        case kind*: TokenKind
        of KeywordToken: 
            keyword*: KeywordKind
        of IdentifierToken:
            identifier*: string
        of LiteralStringToken:
            str*: string
        of LiteralNumberToken:
            value*: float32
        of SymbolToken: 
            symbol*: string
        of StopToken: 
            flag*: bool



                #       Token variables constructors      #

proc newKeywordToken*(location: SourceLocation, keyword: KeywordKind): Token {.inline.} =
    Token(kind: KeywordToken, location: location, keyword: keyword)

proc newIdentifierToken*(location: SourceLocation, identifier: string): Token {.inline.} =
    Token(kind: IdentifierToken, location: location, identifier: identifier)

proc newLiteralStringToken*(location: SourceLocation, str: string): Token {.inline.} =
    Token(kind: LiteralStringToken, location: location, str: str)

proc newLiteralNumberToken*(location: SourceLocation, value: float32): Token {.inline.} =
    Token(kind: LiteralNumberToken, location: location, value: value)

proc newSymbolToken*(location: SourceLocation, symbol: string): Token {.inline.} =
    Token(kind: SymbolToken, location: location, symbol: symbol)

proc newStopToken*(location: SourceLocation, flag = false): Token {.inline.} =
    Token(kind: StopToken, location: location, flag: flag)


#---------------------------------------------------#
#                InputStream type                   #
#---------------------------------------------------#
type 

    GrammarError* = object of CatchableError

    InputStream* = object
        # Necessary to parse scene files

        # Input stream variables
        tabs*: int
        stream*: FileStream
        location*: SourceLocation

        # Variables to be able to unread a character
        savedChar*: char
        savedToken*: Option[Token]
        savedLocation*: SourceLocation


proc newInputStream*(stream: FileStream, filename: string, tabs = 4): InputStream = 
    # InputStream variable constructor
    InputStream(
        tabs: tabs, stream: stream, 
        location: newSourceLocation(filename, 1, 1), savedChar: '\0', 
        savedToken: none Token, savedLocation: newSourceLocation(filename, 1, 1)
        )


proc updateLocation*(inStr: var InputStream, ch: char) = 
    # Procedure to update stream location whenever a character is ridden

    if ch == '\0': discard
    elif ch == '\n':
        # Starting to read a new line
        inStr.location.colNum = 1
        inStr.location.lineNum += 1
    elif ch == '\t':
        inStr.location.colNum += inStr.tabs
    else:
        inStr.location.colNum += 1


proc readChar*(inStr: var InputStream): char =
    # Procedure to read a new char from the stream

    # What if we have an unread character?
    if inStr.savedChar != '\0':
        result = inStr.savedChar
        inStr.savedChar = '\0'
    
    # Otherwise we read a new character from the stream
    else:
        result = inStr.stream.readChar()

        # What if we have a \r character? The problem is that 
        # we would like to know if the following char is a \n or not
        if result == '\r':

            # Reading the following character
            result = inStr.stream.readChar()

            if result != '\n':
                let msg = "PhotoNim doesn't run on old macOS versions."
                raise newException(CatchableError, msg)

    inStr.savedLocation = inStr.location
    inStr.updateLocation(result)


proc unreadChar*(inStr: var InputStream, ch: char) = 
    # Procedure to push a character back to the stream
   
    assert inStr.savedChar == '\0'
    inStr.savedChar = ch
    inStr.location = inStr.savedLocation


proc skipWhitespaceComments*(inStr: var InputStream) = 
    # We just want to avoid whitespace and comments 
    var ch: char

    ch = inStr.readChar()
    while (ch in WHITESPACE) or (ch == '#'):

        # Dealing with comments
        if ch == '#':
            while not (inStr.readChar() in ['\r','\n','\0']):
                discard
            
        ch = inStr.readChar()
        if ch == '\0':
            return

    # Unreading non whitespace or comment char read
    inStr.unreadChar(ch)


proc parseStringToken*(inStr: var InputStream, tokenLocation: SourceLocation): Token = 
    # Procedure to parse a string token
    var 
        ch: char
        str = ""
    
    # Here we just want to read a string (break condition will be an inverted comma ")
    while true:
        ch = inStr.readChar()
        if ch == '"': break

        if ch == '\0':
            let e = fmt"Unterminated string starting at (Line: {tokenLocation.lineNum}, Column: {tokenLocation.colNum}), missing closing inverted commas."
            raise newException(GrammarError, e)
        
        str = str & ch

    return newLiteralStringToken(tokenLocation, str)


proc parseNumberToken*(inStr: var InputStream, firstCh: char, tokenLocation: SourceLocation): Token = 
    # Procedure to parse a number, the output will be a LiteralNumberToken with value field float32
    var 
        ch: char
        numStr = ""
        val: float32
    numStr = numStr & firstCh
    
    # Number reading proc ends if we get a non-digit as char
    while true:
        ch = inStr.readChar()

        if not (ch.isDigit() or (ch == '.') or (ch in ['e', 'E'])):
            inStr.unreadChar(ch)
            break
        
        numStr = numStr & ch
    
    try:
        val = parseFloat(numStr)
    except ValueError:
        let e = fmt"{numStr} is an invalid floating-point number"
        raise newException(GrammarError, e)

    return newLiteralNumberToken(tokenLocation, val)


proc parseKeywordOrIdentifierToken*(inStr: var InputStream, firstCh: char, tokenLocation: SourceLocation): Token = 
    # Procedure to read wether a keyword token or an identifier token
    var
        ch: char
        tokStr = ""
    tokStr = tokStr & firstCh

    while true:
        ch = inStr.readChar()

        if not (ch.isAlphaNumeric or ch == '_'):
            inStr.unreadChar(ch)
            break
        
        tokStr = tokStr & ch
    
    try:
        return newKeywordToken(tokenLocation, KEYWORDS[tokStr])
    except KeyError:
        return newIdentifierToken(tokenLocation, tokStr)


proc readToken*(inStr: var InputStream): Token =
    # Procedure to read a token from input stream
    var
        ch: char
        tokenLocation: SourceLocation

    # Checking wether we already have a saved token or not
    if inStr.savedToken.isSome:
        result = inStr.savedToken.get
        inStr.savedToken = none Token
        return result

    inStr.skipWhitespaceComments()
    
    # Reading a char that we know is not a whitespace or part of a comment line
    # We first need to check wether we are in eof condition
    ch = inStr.readChar()
    if ch == '\0':
        return newStopToken(inStr.location, true)
    
    # We now have to chose between five possible different token
    tokenLocation = inStr.location

    if ch in SYMBOLS:
        # Symbol token
        return newSymbolToken(tokenLocation, $ch)

    elif ch == '"':
        # Literal string token
        return inStr.parseStringToken(tokenLocation)

    elif ch.isDigit or (ch in ['+', '-', '.']):
        # Literal number token
        return inStr.parseNumberToken(ch, tokenLocation)

    elif ch.isAlphaNumeric() or (ch == '_'):
        # Keyword or identifier token
        return inStr.parseKeywordOrIdentifierToken(ch, tokenLocation)
    
    else:
        # Error condition, something wrong is happening
        let msg = fmt"Invalid character: {ch} in: " & $inStr.location
        raise newException(GrammarError, msg)


proc unreadToken*(inStr: var InputStream, token: Token) =
    # Procedure to unread a whole token from stream file
    assert inStr.savedToken.isNone
    inStr.savedToken = some token


