envpath = joinpath(ENV["HOME"], ".julia/environments")
using Pkg
pkg"activate"

if ispath(envpath) == envpath
   mkpath(envpath)
   cp("/opt/julia/environments", envpath, force = true)
end 
