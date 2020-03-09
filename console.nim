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

let
  commandPattern = re"([^\s]+)"

var 
  currentInput = ">"
  lastInput = currentInput
  viableCommands : seq[StyledText]
  dropWidth : float32 = 0
  dropHeight : float32 = 0
  maxDrop : int = 20
  argWidth : float = 0
  selected = 0
  
  #Image variables
  imageID : ImTextureID
  imageAspect : float
  imagePath : string

proc getCommand():string=
  var found = currentInput.match(commandPattern)
  if(found.isSome()): 
    var bounds = found.get.captureBounds[-1]
    bounds.a += 1
    return currentInput[bounds]

proc isPath():bool = dirExists(getCommand().splitFile().dir)

proc getCommands(): string = 
  var command = getCommand()
  if(isPath()):
    var fileSplit = command.splitFile()
    return execCmdEx(fmt"ls {fileSplit.dir} | grep '^{fileSplit.name}' ").output
  return execCmdEx(fmt"ls /bin/ | grep '^{command}'").output

proc getInfo(): seq[string]=
  var tldr = execCmdEx(fmt"tldr {getCommand()}").output
  var splitTldr = tldr.split("\n")

  if(splitTldr.len > 1):
    result.add(splitTldr[1].replace("\e[0m"))


proc hasCommands():bool = viableCommands.len > 0

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
          else: currentInput = currentInput.substr(0,currentInput.high-1)

    of GLFWKey.Enter:
      if(hasCommands() and isPath()):
        var split = getCommand().splitFile()
        var dir = split.dir & "/"
        if(dir == "//"): dir = "/"
        currentInput = fmt">{dir}{viableCommands[selected].text}"
        if(dirExists(fmt"{dir}{viableCommands[selected].text}")): currentInput &= "/"

      elif(hasCommands()):currentInput = fmt">{viableCommands[selected].text}"
    of GLFWKey.Up:
      if(hasCommands()): selected = (selected - 1 + viableCommands.len) %% viableCommands.len

    of GLFWKey.Down:
      if(hasCommands()): selected = (selected + 1 + viableCommands.len) %% viableCommands.len

    else:discard

  #Update Text
  if(lastSelected != selected and hasCommands()):
    viableCommands[lastSelected].selected = false
    viableCommands[selected].selected = true

proc onChar(window: GLFWWindow, codepoint: uint32, mods: int32): void {.cdecl.}=
  var rune = Rune(codepoint)
  if((mods and GLFWModShift) == GLFWModShift): rune = rune.toUpper()
  currentInput.add(rune)


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

  igStyleColorsCherry()

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

    #TODO- Draw History

    igText(currentInput)
    if(currentInput.len > 1 and currentInput != lastInput):
      selected = 0
      dropWidth = 0
      dropHeight = 0
      viableCommands = parseAnsiText(getCommands())

      var height = (viableCommands.len.toFloat() + 1) * igGetFontSize()
      dropHeight = min(height,maxDrop.toFloat * igGetFontSize())

      #Get Max Width
      for x in viableCommands:
        dropWidth = max(x.text.len.toFloat * igGetFontSize() * 0.75,dropWidth)
    var currentCommand = getCommand()

    #Extension Stuff
    var selectedPath = currentCommand
    if(not fileExists(selectedPath) and hasCommands()): selectedPath = currentCommand.splitFile().dir & "/" & viableCommands[selected].text
    if(fileExists(selectedPath)):
      var ext = ""
      for x in countdown(selectedPath.high,0):
        if(selectedPath[x] == '.'): ext = selectedPath.substr(x+1,selectedPath.high)
      case ext:
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

    #Draw Binaries
    if(hasCommands() and currentInput.len > 1 and not currentCommand.contains(viableCommands[selected].text)):
      igSetNextWindowFocus()
      igSetNextWindowSize(ImVec2(x:dropWidth,y: dropHeight),ImGuiCond.Always)
      igSetNextWindowPos(ImVec2(x : igGetFontSize(),y:igGetFontSize() * 2),ImGuiCond.Always)
      igBegin("autofill",flags = flag)
      viableCommands[selected].selected = true
      #Get small segment to draw, else draw everything
      if(viableCommands.len > maxDrop):
        var toDraw : seq[StyledText]
        for x in 0..maxDrop:
          var index = (selected + x + viableCommands.len) %% viableCommands.len
          toDraw.add(viableCommands[index])
        drawAnsiText(toDraw,false)
      else: drawAnsiText(viableCommands)
      igEnd()

    #Draw Info
    if(currentInput.len > 1 and hasCommands() and currentCommand.contains(viableCommands[selected].text)):
      var args = getInfo()
      if(args.len > 0 and args[0] != ""):
        igSetNextWindowFocus()
        var desc = parseAnsiText(args[0])
        argWidth = min(args[0].len.toFloat * igGetFontSize(),width.toFloat * 0.90)
        var lastSpace = 0
        var lastNewLine = 0
        var lines = 2
        for x in 0..<desc[0].text.len:
          if(desc[0].text[x] == ' '): lastSpace = x
          if((x - lastNewline).toFloat * igGetFontSize() > argWidth):
            desc[0].text[lastSpace] = '\n'
            lastNewLine = lastSpace
            inc(lines)


        igSetNextWindowSize(ImVec2(x:argWidth,y: igGetFontSize() * lines.toFloat),ImGuiCond.Always)
        igSetNextWindowPos(ImVec2(x : igGetFontSize(),y:igGetFontSize() * 2),ImGuiCond.Always)
        igBegin("description",flags = flag)
        drawAnsiText(desc)
        igEnd()
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