module GLVisualizeCI

import GitHub

# EventListener settings
myauth = GitHub.authenticate(ENV["SIM_GITHUBAUTH"])
mysecret = ENV["SIM_SECRET"]
myevents = ["pull_request"]
myrepos = [GitHub.Repo("JuliaGL/GLVisualize.jl")] # can be Repos or repo names

# Set up Status parameters
pending_params = Dict(
    "state" => "pending",
    "context" => "CIer",
    "description" => "Running CI..."
)

success_params = Dict(
    "state" => "success",
    "context" => "CIer",
    "description" => "CI complete!"
)

error_params(err) = Dict(
    "state" => "error",
    "context" => "CIer",
    "description" => "Error: $err"
)
function handle_event(event)
    kind, payload, repo = event.kind, event.payload, event.repository
    if kind == "pull_request" && payload["action"] == "open"
        println("sweeeeeeet!")
    end
end
# We can use Julia's `do` notation to set up the listener's handler function
function start(func = handle_event)
    listener = GitHub.EventListener(
        func,
        auth = myauth,
        secret = mysecret,
        repos = myrepos,
        events = myevents
    )
    # Start the listener on localhost at port 8000
    GitHub.run(listener, host = IPv4(128, 30, 87, 54), port = 8000)
end

end # module
