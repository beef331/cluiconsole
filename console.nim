import nimgl/imgui, nimgl/imgui/[impl_opengl, impl_glfw]
import nimgl/[opengl, glfw]
import ansidrawer
import osproc
import os
import strformat
import strutils
import nre
import unicode
import sdl2/image


var 
  currentInput = ">"
  lastInput = currentInput
  viableCommands : seq[StyledText]
  dropWidth : float32 = 0
  dropHeight : float32 = 0
  maxDrop : int = 20
  argWidth : float = 0
  selected = 0
  cursor = 0
  
  #Image variables
  imageID : ImTextureID
  imageAspect : float
  imagePath : string

  style : ptr ImGuiStyle


type
    History = object
      text : seq[StyledText]
  
proc newHistory(input: seq[StyledText]): History = History(text:input)

var
  history : seq[History] = @[]
  lastHistoryCount = 0
  historySelection = 0

proc clearInput()= currentInput = currentInput.substr(0,0)

proc getFullCommand():string= currentInput.substr(1,currentInput.high)

proc getCommand():string = currentInput.substr(1,currentInput.high).split(' ')[0]

proc isPath():bool = dirExists(getCommand().splitFile().dir)

proc getOptions(): string = 
  var command = getCommand()
  if(isPath()):
    var fileSplit = command.splitFile()
    return execCmdEx(fmt"ls {fileSplit.dir} | grep '^{fileSplit.name}' ").output
  return execCmdEx(fmt"ls /bin/ | grep '^{command}'").output

proc appendSelection(): string = 
  var split = getCommand().splitFile()
  var dir = split.dir & "/"
  if(dir == "//"): dir = "/"
  result = fmt">{dir}{viableCommands[selected].text}"
  if(dirExists(fmt"{dir}{viableCommands[selected].text}")): result &= "/"

proc getInfo(input : string): seq[StyledText]=
  var tldr = execCmdEx(fmt"tldr {input}").output
  if(tldr.split("\n").len > 2):
    result.add(parseAnsiInteractText(tldr))

proc hasOptions():bool = viableCommands.len > 0

proc inputNotSelected : bool = hasOptions() and not getCommand().contains(viableCommands[selected].text)

proc run() : seq[StyledText]=
  var command = getFullCommand()
  var commandStyled = newStyledText(currentInput,newStyle())
  result.add(commandStyled)
  clearInput()
  case command:
  of "clear": 
    history = @[]
    return @[]
  var output = execCmdEx(command).output
  result.add(parseAnsiDisplayText(output))

proc onKeyChange(window: GLFWWindow, key: int32, scancode: int32, action: int32, mods: int32):void{.cdecl.}=
  if(action == GLFW_RELEASE): return
  let controlPressed : bool = (mods and GLFWModControl) == GLFWModControl
  let shiftPressed : bool = (mods and GLFWModShift) == GLFWModShift

  let lastSelected = selected
  case(key.toGLFWKey()):
    of GLFWKey.Backspace:
      if(currentInput.len>1):
          #Word Deletion
          if(controlPressed):
            var lastIsLetter = Letters.contains(currentInput[currentInput.high])
            for x in countdown(currentInput.high-1,0):
              if(lastIsLetter != Letters.contains(currentInput[x])): 
                currentInput = currentInput.substr(0,x)
                break
          else: 
            currentInput = currentInput.substr(0,currentInput.high - 1)
            cursor -= 1

    of GLFWKey.Enter:
      if(hasOptions() and isPath()): 
        currentInput = appendSelection()
        cursor = currentInput.high
      elif(inputNotSelected()): 
        currentInput = fmt">{viableCommands[selected].text}"
        cursor = currentInput.high
      elif(currentInput.len > 1):
        historySelection = 0
        history.add(newHistory(run()))
        clearInput()
        viableCommands = @[]

    of GLFWKey.Right:
      if(not shiftPressed and cursor < currentInput.high): cursor += 1
      if(hasOptions() and isPath() and shiftPressed): currentInput = appendSelection()
      elif(hasOptions() and shiftPressed): currentInput = fmt">{viableCommands[selected].text}"

    of GLFWKey.Left:
      if(not shiftPressed and cursor > 1):cursor -= 1

    of GLFWKey.Up:
      if(inputNotSelected()): selected = (selected - 1 + viableCommands.len) %% viableCommands.len
      elif(history.len > 0 and history[history.high].text.len > 0 and shiftPressed):
        currentInput = history[history.high - historySelection].text[0].text
        if(history.high - historySelection > 0): historySelection += 1

    of GLFWKey.Down:
      if(hasOptions() and not shiftPressed): selected = (selected + 1 + viableCommands.len) %% viableCommands.len
      elif(historySelection > 0 and shiftPressed):
        currentInput = history[history.high - historySelection].text[0].text
        historySelection -= 1
    else:discard

  #Update Text
  if(lastSelected != selected and hasOptions()):
    viableCommands[lastSelected].selected = false
    viableCommands[selected].selected = true

proc onChar(window: GLFWWindow, codepoint: uint32, mods: int32): void {.cdecl.}=
  var rune = Rune(codepoint)
  if((mods and GLFWModShift) == GLFWModShift): rune = rune.toUpper()
  currentInput.add(rune)
  cursor += 1


proc main() =
  assert glfwInit()

  glfwWindowHint(GLFWContextVersionMajor, 3)
  glfwWindowHint(GLFWContextVersionMinor, 3)
  glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE)
  glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
  glfwWindowHint(GLFWResizable, GLFW_TRUE)
  var w: GLFWWindow = glfwCreateWindow(800, 600)
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

    #Draw responses
    for ele in history:
      drawAnsiText(ele.text)
    if(lastHistoryCount != history.len):
      igSetScrollY(100000000)
      lastHistoryCount = history.len

    igText(currentInput)
    igSameLine(0,0)
    igTextColored(ImVec4(x:1,y:1,z:0,w:1),"_")

    if(currentInput.len > 1 and currentInput != lastInput):
      selected = 0
      dropWidth = 0
      dropHeight = 0
      viableCommands = parseAnsiInteractText(getOptions())
      var height = (viableCommands.len.toFloat() + 1) * igGetFontSize() + igGetFontSize() / 2
      dropHeight = min(height,maxDrop.toFloat * igGetFontSize() + igGetFontSize() / 2)

      #Get Max Width
      for x in viableCommands:
        for y in x.text.split("\n"):
          dropWidth = max(y.len.toFloat * igGetFontSize() * 0.75,dropWidth)

    var currentCommand = getCommand()

    #Extension Stuff
    var selectedPath = currentCommand
    if(not fileExists(selectedPath) and hasOptions()): selectedPath = currentCommand.splitFile().dir & "/" & viableCommands[selected].text
    if(fileExists(selectedPath)):
      var ext = ""
      for x in countdown(selectedPath.high,0):
        if(selectedPath[x] == '.'): ext = selectedPath.substr(x+1,selectedPath.high)
      case ext.toLower():
      of "png","jpeg","jpg","tiff":
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
        imageSize.x = min((300f * imageAspect),width.toFloat-300f)
        imageSize.y = imageSize.x
        imageSize.x *= imageAspect

        igSetNextWindowFocus()
        igSetNextWindowSize(imageSize,ImGuiCond.Always)
        igSetNextWindowPos(ImVec2(x:(dropWidth + igGetFontSize()),y : (igGetFontSize() * 2f)),ImGuiCond.Always)
        igBegin("Image Viewer",flags = flag)
        igImage(imageID,imageSize)
        igEnd()

      else: discard

    #Draw Options
    if(hasOptions() and currentInput.len > 1):
      viableCommands[selected].selected = true
      #Get small segment to draw, else draw everything
      if(viableCommands.len > maxDrop):
        var toDraw : seq[StyledText]
        for x in 0..maxDrop:
          var index = (selected + x + viableCommands.len) %% viableCommands.len
          toDraw.add(viableCommands[index])
        drawAnsiText(toDraw)
      else: drawAnsiText(viableCommands)
    #Draw Info
    if(currentInput.len > 1):
      var command = getCommand()
      if(hasOptions()): command = viableCommands[selected].text
      var args = getInfo(command)
      if(args.len > 1):
        drawAnsiText(args[1..args.high])
    igEnd()

    # End simple window

    igRender()

    glClearColor(0f,0f,0f, 1f)
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