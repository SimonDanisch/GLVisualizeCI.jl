using GLVisualize
include(GLVisualize.dir("examples", "ExampleRunner.jl"))
using ExampleRunner
importall ExampleRunner

using GLAbstraction, GLWindow, GLVisualize, Colors
using FileIO, GeometryTypes, Reactive, Images


files = [
    "introduction/rotate_robj.jl",
    "introduction/screens.jl",
    "plots/3dplots.jl",
    "plots/lines_scatter.jl",
    "plots/hybrid.jl",
    "camera/camera.jl",
    "gui/color_chooser.jl",
    "gui/image_processing.jl",
    "gui/buttons.jl",
    "gui/fractal_lines.jl",
    "gui/mandalas.jl",
    "plots/drawing.jl",
    "interactive/graph_editing.jl",
    "interactive/mario_game.jl",
    "text/text_particle.jl",
]

map!(x-> GLVisualize.dir("examples", x), files, files)
files = union(files, ExampleRunner.flatten_paths(GLVisualize.dir("examples")))
push!(files, GLVisualize.dir("test", "summary.jl"))
files = unique(normpath.(files))
# Create an examplerunner, that displays all examples in the example folder, plus
# a runtest specific summary.
ENV["GLVISUALIZE_SCREENCAST_FOLDER"] = joinpath(homedir(), "Desktop", "test")
config = ExampleRunner.RunnerConfig(
    record = false,
    record_image = true,
    files = files,
    thumbnail = false,
    screencast_folder = ENV["GLVISUALIZE_SCREENCAST_FOLDER"],
    resolution = (200, 200)
)
window = config.window
for path in config.files
    isopen(config.rootscreen) || break
    try
        test_module = ExampleRunner._test_include(path, config)
        ExampleRunner.display_msg(test_module, config)
        GLWindow.poll_glfw()
        GLWindow.poll_reactive()
        yield()
        render_frame(config.rootscreen)
        swapbuffers(config.rootscreen)
        name = basename(path)[1:end-3]
        name = joinpath(config.screencast_folder, name * ".png")
        GLWindow.screenshot(config.rootscreen, path = name)
    catch e
        #failed[i] = true
        bt = catch_backtrace()
        ex = CapturedException(e, bt)
        showerror(STDERR, ex)
        config[:success] = false
        config[:exception] = ex
    finally
        empty!(window)
        empty!(config.buttons[:timesignal].actions)
        window.color = RGBA{Float32}(1,1,1,1)
        window.clear = true
        GLVisualize.empty_screens!()
        GLVisualize.add_screen(window) # make window default again!
        for (k, s) in window.inputs
            empty!(s.actions)
        end
        empty!(window.cameras)
        gc()
    end
    yield()
end
