import nimgl/imgui, nimgl/imgui/[impl_opengl, impl_glfw]
import nimgl/[opengl, glfw]
import ansidrawer
import osproc
import os
import strformat
import strutils
import unicode
import sdl2/image
import streams
import fontLoader
import times

var 
  currentInput = ">"
  lastInput = currentInput
  viableCommands : seq[StyleLine]
  dropWidth : float32 = 0
  dropHeight : float32 = 0
  maxDrop : int = 10
  argWidth : float = 0
  selected = 0
  cursor = 0
  
  #Image variables
  imageID : ImTextureID
  imageAspect : float
  imagePath : string


  showFontSelector = false
  showStyleSelector = false

  startedProcess : Process

  style : ptr ImGuiStyle
  readBuffer : string 
  readThread : Thread[void]




type
    History = object
      text : seq[StyleLine]
  
proc newHistory(input: seq[StyleLine]): History = History(text:input)

var
  history : seq[History] = @[]
  lastHistoryCount = 0
  historySelection = 0
  historyChanged = false

proc clearInput()= 
  currentInput = currentInput.substr(0,0)
  cursor = 0

proc getFullCommand():string= currentInput.substr(1,currentInput.high)

proc getCommand():string = currentInput.substr(1,currentInput.high).split(' ')[0]

proc commandHasPaths(): bool = 
  var split = getCommand().splitFile()
  var splitString = currentInput.substr(0,cursor).split(" ")
  result = dirExists(split.dir)
  if(splitString.len > 1): result = result or dirExists(splitString[splitString.high].splitFile().dir)

proc getPaths(): string = 
  var split = getFullCommand().splitFile()
  if(dirExists(split.dir)): result = getFullCommand()
  var splitString = getFullCommand().substr(0,cursor).split(" ")
  if(splitString.len > 1):
    var splitDir = splitString[splitString.high].splitFile()
    if(dirExists(splitDir.dir)): result = splitString[splitString.high]

proc getOptions(): string = 
  var command = getCommand()
  if(commandHasPaths()):
    var fileSplit = getPaths().splitFile()
    return execCmdEx(fmt"ls {fileSplit.dir} | grep '^{fileSplit.name}' ").output
  return execCmdEx(fmt"ls /bin/ | grep '^{command}'").output

proc appendSelection(): string = 
  var cmd = getFullCommand()
  var subSection = cmd.substr(0,cursor)
  var splitSubSect = subSection.split("/")
  if(splitSubSect.len > 1):
    splitSubSect[splitSubSect.high] = viableCommands[selected].words[0].text
    result = ">"
    for x in splitSubSect: result &= fmt"{x}/"
    result &= cmd.substr(cursor + 1,cmd.high)

proc getInfo(input : string): seq[StyleLine]=
  var tldr = execCmdEx(fmt"tldr {input}").output
  if(tldr.split("\n").len > 1):
    result.add(parseAnsiInteractText(tldr))

proc hasOptions():bool = viableCommands.len > 0

proc inputNotSelected : bool = hasOptions() and not getCommand().contains(viableCommands[selected].words[0].text)

proc processRunning : bool = startedProcess != nil and startedProcess.running

proc processStdout(){.thread.}=
  while processRunning():
    readBuffer = ""
    while not startedProcess.outputStream.atEnd:
      readBuffer &= startedProcess.outputStream.readChar()
proc run() : seq[StyleLine]=
  var baseCommand = getCommand()
  var fullCommand = getFullCommand()
  var commandStyled = StyleLine()
  commandStyled.words.add(newStyledText(currentInput,newStyle()))
  result.add(commandStyled)
  clearInput()
  case baseCommand:
  of "clear": 
    history = @[]
    return @[]
  of "cd":
    var split = fullCommand.split(" ",1)
    if(split.len > 0):
      var dir =  split[1].replace("~",getHomeDir())
      if(dirExists(dir)): setCurrentDir(dir)
    return

  startedProcess = startProcess(fullCommand, options = {poUsePath,poEvalCommand})
  createThread(readThread,processStdout)
  readBuffer = ""

proc onKeyChange(window: GLFWWindow, key: int32, scancode: int32, action: int32, mods: int32):void{.cdecl.}=
  if(action == GLFW_RELEASE): return
  let controlPressed : bool = (mods and GLFWModControl) == GLFWModControl
  let shiftPressed : bool = (mods and GLFWModShift) == GLFWModShift
  let lastSelected = selected
  
  if(processRunning()): startedProcess.inputStream.write(key)

  case(key.toGLFWKey()):
    of GLFWKey.Backspace:
      if(currentInput.len>1):
          #Word Deletion
          if(controlPressed):
            var lastIsLetter = Letters.contains(currentInput[cursor])
            for x in countdown(cursor-1,0):
              if(lastIsLetter != Letters.contains(currentInput[x])): 
                if(cursor < currentInput.high): currentInput = currentInput.substr(0,x) & currentInput.substr(cursor,currentInput.high)
                else:currentInput = currentInput.substr(0,x)
                cursor = x
                break
          else: 
            if(cursor < currentInput.high): currentInput = currentInput.substr(0,cursor-1) & currentInput.substr(cursor+1,currentInput.high)
            else:currentInput = currentInput.substr(0,cursor-1)
            cursor -= 1

    of GLFWKey.Enter:
      if(hasOptions() and commandHasPaths() and shiftPressed): 
        currentInput = appendSelection()
        cursor = currentInput.high
      elif(inputNotSelected() and not currentInput.contains(" ") and shiftPressed): 
        currentInput = fmt">{viableCommands[selected].words[0].text}"
        cursor = currentInput.high
      elif(currentInput.len > 1 and not processRunning()):
        historySelection = 0
        history.add(newHistory(run()))
        historyChanged = true
        clearInput()
        viableCommands = @[]

    of GLFWKey.Right:
      if(not shiftPressed and cursor < currentInput.high): cursor += 1
      if(hasOptions() and commandHasPaths() and shiftPressed): currentInput = appendSelection()
      elif(hasOptions() and shiftPressed): currentInput = fmt">{viableCommands[selected].words[0].text}"

    of GLFWKey.Left:
      if(not shiftPressed and cursor > 1):cursor -= 1

    of GLFWKey.Up:
      if(inputNotSelected() and shiftPressed): selected = (selected - 1 + viableCommands.len) %% viableCommands.len
      elif(history.len > 0 and history[history.high].text.len > 0 and not shiftPressed):
        currentInput = history[history.high - historySelection].text[0].words[0].text
        if(history.high - historySelection > 0): historySelection += 1

    of GLFWKey.Down:
      if(hasOptions() and shiftPressed): selected = (selected + 1 + viableCommands.len) %% viableCommands.len
      elif(historySelection > 0 and not shiftPressed):
        currentInput = history[history.high - historySelection].text[0].words[0].text
        historySelection -= 1
    
    of GLFWKey.C:
      if(controlPressed):
        if(processRunning()):
          startedProcess.terminate()
        else: quit(0)

    of GLFWKey.F1:
      showFontSelector = not showFontSelector
    
    of GLFWKey.F2:
      showStyleSelector = not showStyleSelector

    else:discard

  #Update Text
  if(lastSelected != selected and hasOptions()):
    viableCommands[lastSelected].words[0].selected = false
    viableCommands[selected].words[0].selected = true

proc onChar(window: GLFWWindow, codepoint: uint32, mods: int32): void {.cdecl.}=

  var rune = Rune(codepoint)
  if((mods and GLFWModShift) == GLFWModShift): rune = rune.toUpper()

  if(not processRunning()):
    var place = cursor + 1
    if(place < currentInput.len and place > 1):
      currentInput.insert($rune,place)
    else: currentInput &= rune
    cursor += 1

proc drawInfo(width : float32)=
  ##Draws information about the command to ease use
  if(currentInput.len > 1):
    var command = getCommand()
    if(hasOptions()): command = viableCommands[selected].words[0].text
    var args = getInfo(command)
    if(args.len > 1):
      igBeginChild("info",ImVec2(x: width - igGetFontSize(), y: (args.len + 1).toFloat * igGetTextLineHeightWithSpacing()),true)
      drawAnsiText(args[1..args.high])
      igEndChild()

proc drawOptions()=
  ##Draws path directiories, and auto complete
  if(hasOptions() and currentInput.len > 1):
    viableCommands[selected].words[0].selected = true
    dropHeight = min((viableCommands.len.toFloat + 1) * igGetTextLineHeightWithSpacing(), maxDrop.toFloat * igGetTextLineHeightWithSpacing())
    #Get Max Width
    for x in viableCommands:
        dropWidth = max(igCalcTextSize(x.words[0].text & "  ").x,dropWidth)
    #Get small segment to draw, else draw everything
    let pos = igGetCursorPos()
    var drawPos = pos
    drawPos.x = igCalcTextSize(getCurrentDir() & ">").x
    for x in countdown(cursor,1):
      if(currentInput[x] == ' ' or currentInput[x] == '/'):
        drawPos.x += igCalcTextSize(currentInput.substr(0,x-1)).x
        break
    igSetNextWindowPos(drawPos,ImGuiCond.Always)
    igBeginChild("autoComplete",size = ImVec2(x:dropWidth,y:dropHeight))
    if(viableCommands.len > maxDrop):
      var toDraw : seq[StyleLine]
      for x in 0..maxDrop:
        var index = (selected + x + viableCommands.len) %% viableCommands.len
        toDraw.add(viableCommands[index])
      drawAnsiText(toDraw)
    else: drawAnsiText(viableCommands)
    igEndChild()
    igSetCursorPos(pos)

proc drawImage(selectedPath : string, width : float32,flag : ImGuiWindowFlags)=
  ##Draws image and loads it if supposed to draw new
  #Load image if it changes
  if(imagePath != selectedPath):
    imagePath = selectedPath
    var dataPtr = load(imagePath)
    if(dataPtr != nil):
      var texture : GLuint
      glGenTextures(1, texture.addr)
      glBindTexture(GL_TEXTURE_2D,texture)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR.ord)
      glPixelStorei(GL_UNPACK_ROW_LENGTH, 0)
      imageAspect = dataPtr.w/dataPtr.h
      try:
        var format = GL_RGBA
        if(dataPtr.format[].BytesPerPixel == 3): format = GL_RGB
        glTexImage2D(GL_TEXTURE_2D, GLint(0), GLint(format), GLSizei(dataPtr.w), GLSizei(dataPtr.h), GLint(0), format, GL_UNSIGNED_BYTE, dataPtr.pixels)
      except:
        echo "Howst the fuck"
      imageID = cast[ImTextureID](texture)
  var imageSize = ImVec2()
  imageSize.x = min((300f * imageAspect),width-300f)
  imageSize.y = imageSize.x
  imageSize.x *= imageAspect
  var preDrawPos = igGetCursorPos()
  igBeginChild("Image Viewer", imageSize)
  igImage(imageID,imageSize)
  igEndChild()
  igSetCursorPos(preDrawPos)

proc drawExtensions(width : float32, flag: ImGuiWindowFlags)=
  ##Draws specific elements per type
  
  var selectedPath = getPaths()
  
  #Search all possible paths
  if(not fileExists(selectedPath) and hasOptions()):
    let selectionRelativeToCurrent = getCurrentDir() & "/" & viableCommands[selected].words[0].text
    let selectionAbsolute = fmt"{selectedPath.splitFile().dir}/{viableCommands[selected].words[0].text}"
    if(fileExists(selectionRelativeToCurrent)): selectedPath = selectionRelativeToCurrent
    elif(fileExists(selectionAbsolute)): selectedPath = selectionAbsolute

  if(not fileExists(selectedPath)): return
  
  var ext = ""
  for x in countdown(selectedPath.high,0):
    if(selectedPath[x] == '.'): ext = selectedPath.substr(x + 1,selectedPath.high)
  case ext.toLower():
  of "png","jpeg","jpg","tiff":
    drawImage(selectedPath,width,flag)
  else: discard

proc drawHistory()=
  ##Draw responses
  for ele in history:
    drawAnsiText(ele.text)
  if(historyChanged):
    igSetScrollY(igGetCursorPosY())
    historyChanged = false

proc drawRunningProcces()=
  var file = open("output",fmWrite)
  file.write(readBuffer)
  file.close()
  var size = igGetContentRegionAvail()
  igSetNextWindowPos(ImVec2(x:0,y:0),ImGuiCond.Always)
  igBeginChild("Terminal Emulation",size)
  drawAnsiText(parseAnsiDisplayText(readBuffer))
  igEndChild()

proc drawCurrentInput()=
  var styledLine : seq[StyleLine]
  var styleLine = StyleLine()
  var workingDir = newStyledText(getCurrentDir(),newStyle())
  workingDir.style.colourFG = newCol(0,1,1)
  var caret = newStyledText($currentInput[0],newStyle())
  caret.style.colourFG = newCol(1,1,0)
  var commandText = newStyledText(getFullCommand(),newStyle())

  styleLine.words.add(workingDir)
  styleLine.words.add(caret)
  styleLine.words.add(commandText)
  styledLine.add(styleLine)
  drawAnsiText(styledLine)
  igSameLine(0,0)
  var pos = igGetCursorPos()

  pos.x -= igCalcTextSize(currentInput[(cursor)..currentInput.high-1]).x
  igSetNextWindowPos(pos,ImGuiCond.Always)
  igBeginChild("cursor", ImVec2(x:igGetFontSize(),y:igGetTextLineHeight()))
  igTextColored(newCol(1,1,0),"_")
  igEndChild()

proc loadFonts()=
  var fonts = loadFontFile()
  var io = igGetIO()
  if(fonts.len == 0): io.fonts.addFontDefault()
  for x in fonts:
    io.fonts.addFontFromFileTTF(x.path,x.size.toFloat)
  io.fonts.build()

proc main() =
  assert glfwInit()

  glfwWindowHint(GLFWContextVersionMajor, 3)
  glfwWindowHint(GLFWContextVersionMinor, 3)
  glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE)
  glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
  glfwWindowHint(GLFWResizable, GLFW_TRUE)
  var w: GLFWWindow = glfwCreateWindow(1024, 768)
  if w == nil:
    quit(-1)
  
  discard setKeyCallback(w,onKeyChange)
  discard setCharModsCallback(w,onChar)
  w.makeContextCurrent()

  assert glInit()

  let context = igCreateContext()

  assert igGlfwInitForOpenGL(w, true)
  assert igOpenGL3Init()

  style = igGetStyle()

  igStyleColorsDark(style)
  loadFonts()
  var flag = ImGuiWindowFlags(ImGuiWindowFlags.NoDecoration.int or ImGuiWindowFlags.AlwaysAutoResize.int or ImGuiWindowFlags.NoMove.int)
  while not w.windowShouldClose:


    glfwPollEvents()
    igOpenGL3NewFrame()
    igGlfwNewFrame()
    igNewFrame()

    # Simple window
    var width,height : int32
    getWindowSize(w,addr width, addr height)
    igSetNextWindowSize(ImVec2(x:float32(width),y: float32(height)),ImGuiCond.Always)
    igSetNextWindowPos(ImVec2(x:0,y:0),ImGuiCond.Always)
    igBegin("Interactive Terminal", flags = flag)

    if(showFontSelector): igShowFontSelector("Choose a font")
    if(showStyleSelector): igShowStyleEditor()

    if(startedProcess == nil or not startedProcess.running):

      drawHistory()

      drawCurrentInput()

      if(currentInput.len > 1 and currentInput != lastInput):
        selected = 0
        dropWidth = 0
        dropHeight = 0
        viableCommands = parseAnsiInteractText(getOptions())

      drawExtensions(width.toFloat, flag)
      drawOptions()

      drawInfo(width.toFloat)    

    else:
        drawTerminal(readBuffer)

    igEnd()

    igRender()

    glClearColor(0f,0f,0f, 0.5f)
    glClear(GL_COLOR_BUFFER_BIT)

    igOpenGL3RenderDrawData(igGetDrawData())

    w.swapBuffers()
    lastInput = currentInput

  igOpenGL3Shutdown()
  igGlfwShutdown()
  context.igDestroyContext()

  w.destroyWindow()
  glfwTerminate()

main()