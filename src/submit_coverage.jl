try
    Pkg.add("Coverage")
    using Coverage
    Coveralls.submit_token(Coveralls.process_folder())
    Codecov.submit_local(Codecov.process_folder())
catch e
    println(STDERR, e)
end
