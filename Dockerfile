FROM jupyter/datascience-notebook:latest
ARG OPENBLAS_CORETYPE=HASWELL
ENV NB_USER=jovyan
ENV HOME=/home/$NB_USER

USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    sagemath \
    sagemath-jupyter

#RUN conda install --quiet --yes \
#    'r-base=3.4.1' \
#    'r-irkernel=0.8*' \
#    'julia=1.0*' && \
#    conda clean -tipsy

ENV CPATH=$CONDA_DIR/include

# Fix SageMath kernel
USER root
RUN sed -i 's/"\/usr\/bin\/sage"/"env", "PATH=\/usr\/local\/sbin:\/usr\/local\/bin:\/usr\/sbin:\/usr\/bin:\/sbin:\/bin", "\/usr\/bin\/sage"/' /usr/share/jupyter/kernels/sagemath/kernel.json

# Fix Julia kernel  
    # QuantEcon packages 
    RUN julia -e "using InstantiateFromURL; activate_github(\"QuantEcon/QuantEconLecturePackages\", add_default_environment = true)"
    RUN julia -e "using InstantiateFromURL; activate_github(\"QuantEcon/QuantEconLectureAllPackages\", add_default_environment = true)"

    # PackageCompiler 
    RUN julia -e "using Pkg; pkg\"add IJulia InstantiateFromURL Plots Images DiffEqBase DataFrames Parameters Distributions DualNumbers Expectations Unitful Compat NLsolve LaTeXStrings UnicodePlots DataValues IterativeSolvers Interpolations VisualRegressionTests\"" 
    RUN julia -e "using Pkg; pkg\"dev PackageCompiler\""
    RUN julia -e "using PackageCompiler; compile_package(\"Plots\", force = true)"

    # Jupyter user setup 
    RUN useradd -m -s /bin/bash -N -u 9999 jupyter
    RUN chown -R jupyter /home/jupyter/
    RUN chown -R jupyter /home/jovyan/ && \ 
    chmod -R go+rx $CONDA_DIR/share/jupyter && \
    rm -rf $HOME/.local && \
    # Nuke the registry that came with Julia.
    rm -rf /opt/julia-1.1.0/local/share/julia/registries 
    # Nuke the registry that Jovyan uses.

    # Give the user read and execute permissions over /jovyan/.julia.
    RUN chmod -R go+rx /opt/julia
    # Add a startup.jl to copy
    USER jupyter
     
    # Configure environment
    ENV NB_USER=jupyter \
        NB_UID=9999
    ENV HOME=/home/$NB_USER
    
    # Configure the JULIA_DEPOT_PATH
    ENV JULIA_DEPOT_PATH="/home/jupyter/.julia:/opt/julia"
    ADD startup.jl /opt/julia-1.1.0/etc/julia/startup.jl    
    RUN julia /opt/julia-1.1.0/etc/julia/startup.jl
    ENV XDG_CACHE_HOME=/home/$NB_USER/.cache/ \
    HOME=/home/$NB_USER
    WORKDIR $HOME
    USER root
    RUN chown -R jupyter /home/jupyter/.julia
    USER jupyter
