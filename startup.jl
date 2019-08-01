envpath = joinpath(ENV["HOME"], ".julia/environments")
using Pkg
pkg"activate"

if ispath(envpath) == false
   mkpath(envpath)
   cp("/opt/julia/environments", envpath, force = true)
   println("seeded")
end 
