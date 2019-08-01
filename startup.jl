envpath = joinpath(ENV["HOME"], ".julia/environments")
if ispath(envpath) == false
mkpath(envpath)
cp("/opt/julia/environments", envpath, force = true)
end

using Pkg
pkg"activate ~/.julia/environments/v1.1" 
