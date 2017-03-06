module GLVisualizeCI

import GitHub

dir(paths...) = joinpath(dirname(@__FILE__), "..", paths...)

function push_status(pr)
    cd(dir()) do
        run(`git add -A`)
        run(`git commit -m $("data for $pr")`)
        run(`git push origin HEAD`)
    end
end

function image_url(path)
    path, name = splitdir(path)
    path, dir = splitdir(path)
    "https://github.com/SimiDCI/GLVisualizeCI.jl/blob/master/reports/$(joinpath(dir, name))?raw=true"
end

function report_url(repo, pr)
    string(
        "https://github.com/SimiDCI/GLVisualizeCI.jl/blob/master/reports/",
        repo, pr
    )
end
function report_folder(repo, pr)
    dir("reports", repo, pr)
end

gitclone!(repo, path) = run(`git clone https://github.com/$(repo).git $(path)`)


function test_pr(repo, pr)
    mktempdir() do path
        cd(homedir()) # make sure, we're in a concrete folder
        # init a new julia package repository
        ENV["JULIA_PKGDIR"] = path
        Pkg.init()
        package, jl = splitext(get(repo.name))
        builddir = Pkg.dir(package)
        gitclone!(repo, builddir)
        cd(builddir)
        # Fetch current PR
        try
           run(`git fetch --quiet origin +refs/pull/$(pr)/merge:`)
        catch
           # if there's not a merge commit on the remote (likely due to
           # merge conflicts) then fetch the head commit instead.
           run(`git fetch --quiet origin +refs/pull/$(pr)/head:`)
        end
        run(`git checkout --quiet --force FETCH_HEAD`)
        Pkg.add("GLVisualize") # this checks out the dependencies after a fetch
        Pkg.build("GLVisualize")
        Pkg.test(package, coverage = true)
        julia_exe = Base.julia_cmd()
        run(`$julia_exe $(dir("src", "submit_coverage.jl"))`)
    end
end


function handle_event(name, event)
    kind, payload, repo = event.kind, event.payload, event.repository
    sha = if event.kind == "push"
        event.payload["after"]
    elseif event.kind == "pull_request"
        event.payload["pull_request"]["head"]["sha"]
    else
        return HttpCommon.Response(500)
    end

    target_url = report_url(repo, pr)
    path = report_folder(repo, pr)
    isdir(path) || mkdir(path)
    push_status(pr)

    GitHub.create_status(repo, sha; auth = myauth, params = Dict(
        "state" => "pending",
        "context" => ci_name,
        "description" => "Running CI...",
        "target_url" => target_url
    ))

    try
        ORIGINAL_STDOUT = STDOUT
        out_rd, out_wr = redirect_stdout()


        ORIGINAL_STDERR = STDERR
        err_rd, err_wr = redirect_stderr()
        err_reader = @async readstring(err_rd)

        ENV["CI_REPORT_DIR"] = path
        ENV["CI"] = "true"
        test_pr(repo, pr)
        log_stdio = readstring(out_rd)
        log_errsdio = readstring(err_rd)
        close(out_rd); close(err_rd)
        open(joinpath(path, "stdiolog.txt"), "w") do io
            println(io, log_stdio)
        end
        open(joinpath(path, "errorlog.txt"), "w") do io
            println(io, log_errsdio)
        end

        @async wait(out_reader)
        REDIRECTED_STDOUT = STDOUT
        out_stream = redirect_stdout(ORIGINAL_STDOUT)
        @async wait(err_reader)
        REDIRECTED_STDERR = STDERR
        err_stream = redirect_stderr(ORIGINAL_STDERR)
    catch err
        GitHub.create_status(repo, sha; auth = myauth, params = Dict(
            "state" => "error",
            "context" => ci_name,
            "description" => "Error: $err",
            "target_url" => target_url
        ))
        return HttpCommon.Response(500)
    end

    GitHub.create_status(repo, sha; auth = myauth, params = Dict(
        "state" => "success",
        "context" => "CIer",
        "description" => "CI complete!",
        "target_url" => url
    ))
    return HttpCommon.Response(202, "ci request job submission")
end

# We can use Julia's `do` notation to set up the listener's handler function
function start(name, func = handle_event;
        host = IPv4(128, 30, 87, 54),
        port = 8000,
        myrepos = [GitHub.Repo("JuliaGL/GLVisualize.jl")],
        myauth = GitHub.authenticate(ENV["GITHUB_AUTH"])
        mysecret = ENV["GITHUB_SECRET"]
        myevents = ["pull_request"]
    )

    listener = GitHub.EventListener(
        event-> handle_event(name, event),
        auth = myauth,
        secret = mysecret,
        repos = myrepos,
        events = myevents
    )
    # Start the listener on localhost at port 8000
    GitHub.run(listener, host = host, port = port)
end

end # module
