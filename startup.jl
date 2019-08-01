using Pkg 
pkg"activate"

envpath = joinpath(ENV["HOME"], ".julia/environments")
if isdir(envpath) == false 
	mkpath(envpath) # Make the environment directory 
	cp("/opt/julia/environments", envpath, force = true)
end 
