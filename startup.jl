using Pkg 
pkg"activate"

envpath = joinpath(ENV["HOME"], ".julia/environments")
if isdir(envpath) == false 
	mkpath(envpath) # Make the environment directory 
	cp("/home/jovyan/.julia/environments", envpath, force = true)
end 
