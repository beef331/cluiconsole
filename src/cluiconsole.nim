import nimgl/[imgui, glfw, opengl], nimgl/imgui/[impl_opengl, impl_glfw]
import osproc
import os
import strformat
import strutils
import unicode
import sdl2/image
import streams
import fontLoader
import times
import posix
import nim_pty

converter toImVec2(a: (int32, int32)): ImVec2 = ImVec2(x: a[0].float32, y: a[1].float32)

const TIOCSCTTY: uint = 0x540E

type
    ModsDown = enum
        mdControl,
        mdSuper,
        mdAlt,
        mdShift,
        mdCapsLock,
        mdNumLock
    Input = object
        leadingSymbol, writtenInput: string
        position : int
    Pty = object
        master,slave : cint

proc `$`(i : Input):string = i.leadingSymbol & i.writtenInput


proc `+=`(a: var set[ModsDown], b: ModsDown) = a = a + {b}

var
    currentInput = Input(leadingSymbol : ">")
    wSize: (int32, int32)

let 
    wflags = ImGuiWindowFlags(ImGuiWindowFlags.NoDecoration.int or
                ImGuiWindowFlags.AlwaysAutoResize.int or
                ImGuiWindowFlags.NoMove.int)
var pty = Pty()
pty.master = openPt(O_RDRW)        
if(unlockPt(pty.master) == -1): quit "pt not unlocked"
if(grantPt(pty.master) == -1): quit "pt not granted"
pty.slave = open($ptsName(pty.master)).getFileHandle()

proc updateFrameSize(w: GlfwWindow) =
    getWindowSize(w, wSize[0].addr, wSize[1].addr)
    igSetNextWindowSize(wSize, ImGuiCond.Always)

proc modsHeld(mods: int32): set[ModsDown] =
    if((mods and GLFWModControl) == 0): result += mdControl
    if((mods and GLFWModShift) == 0): result += mdShift
    if((mods and GLFWModSuper) == 0): result += mdSuper
    if((mods and GLFWModAlt) == 0): result += mdAlt
    if((mods and GLFWModCapsLock) == 0): result += mdCapsLock
    if((mods and GLFWModNumLock) == 0): result += mdNumLock

proc intializePty()=
    echo "Forking"
    case fork():
    of 0:
        echo "Forked Succesfully"
        discard close(pty.master)
        discard ioctl(pty.slave, TIOCSCTTY)
        discard setsid()
        discard dup2(pty.slave,0)
        discard dup2(pty.slave,1)
        discard dup2(pty.slave,2)
        discard close(pty.slave)
        discard execle("/bin/bash","bash",nil)
    of -1:
        echo "Forking failed, time to use a spoon."
    else:
        discard close(pty.slave)
        echo "Master initalized"
    currentInput.writtenInput = ""

intializePty()

proc onKeyInput(window: GLFWWindow, key: int32, scancode: int32, action: int32,
        mods: int32): void {.cdecl.} =
    let modsPressed = modsHeld(mods)
    if(GLFWKey.Backspace == key and currentInput.writtenInput.len > 0 and (action and (
            GLFWRepeat or GLFWPress)) > 0):
        currentInput.writtenInput = currentInput.writtenInput[0..currentInput.writtenInput.high-1]
    if(GLFWKey.Enter == key and (action and GLFWPress) > 0 ):
        
        currentInput.writtenInput = ""
        discard


proc onCharInput(window: GLFWWindow, codepoint: uint32): void{.cdecl.} =
    currentInput.writtenInput &= Rune(codepoint)

proc registerEvents(w: var GlfwWindow) =
    discard setCharCallback(w, onCharInput)
    discard setKeyCallback(w, onKeyInput)

proc drawDirDropDown(basePath : string)=
    var
        path = basePath
        files : seq[string]


    for x in basePath.split(" "):
        let head = splitPath(x).head
        if(dirExists(head)):
            path = head
            break
    var textSize : ImVec2
    igCalcTextSizeNonUDT(textSize.addr,getCurrentDir() & currentInput.leadingSymbol)
    igSetCursorPosX(textSize.x)
    igSetCursorPosY(igGetCursorPosY() + igGetTextLineHeight())
    igBeginChild("dropDown")
    var filesGot = 0
    let dirToDraw = 10
    for dir in walkDir(path):
        files.add(dir.path)
        inc filesGot
        if(filesGot >= dirToDraw): break
    for file in files:
        if(igButton(file) and dirExists(file)):
            setCurrentDir(file)
            currentInput.writtenInput = ""
    igEndChild()


proc drawTerminal() =
    igBegin("Terminal", flags = wflags)
    igText(getCurrentDir() & $currentInput)
    drawDirDropDown(currentInput.writtenInput)
    igEnd()


proc main() =
    assert glfwInit()

    glfwWindowHint(GLFWContextVersionMajor, 3)
    glfwWindowHint(GLFWContextVersionMinor, 3)
    glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE)
    glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
    glfwWindowHint(GLFWResizable, GLFW_TRUE)
    var w = glfwCreateWindow(1024, 768)
    if w == nil:
        quit(-1)

    w.makeContextCurrent()

    assert glInit()

    let context = igCreateContext()

    assert igGlfwInitForOpenGL(w, true)
    assert igOpenGL3Init()
    registerEvents(w)

    while not w.windowShouldClose:
        glfwPollEvents()
        igOpenGL3NewFrame()
        igGlfwNewFrame()
        igNewFrame()
        updateFrameSize(w)
        drawTerminal()

        igRender()

        glClearColor(0f, 0f, 0f, 0.5f)
        glClear(GL_COLOR_BUFFER_BIT)

        igOpenGL3RenderDrawData(igGetDrawData())

        w.swapBuffers()

    igOpenGL3Shutdown()
    igGlfwShutdown()
    context.igDestroyContext()

    w.destroyWindow()
    glfwTerminate()

main()
