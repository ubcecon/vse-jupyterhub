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
    RUN julia -e "using Pkg; pkg\"add PackageCompiler\""
    RUN julia -e "using PackageCompiler; compile_package(\"Plots\")"

    RUN chown -R jupyter /home/jupyter/
    RUN chown -R jupyter /home/jovyan/
    RUN mv $HOME/.local/share/jupyter/kernels/julia-1.1 $CONDA_DIR/share/jupyter/kernels/ \
    && chmod -R go+rx $CONDA_DIR/share/jupyter \
    && rm -rf $HOME/.local \
    # Nuke the registry that came with Julia.
    && rm -rf /opt/julia-1.1.0/local/share/julia/registries \
    # Nuke the registry that Jovyan uses.
    && rm -rf $HOME/.julia/registries

    # Give the user read and execute permissions over /jovyan/.julia.
    RUN chmod -R go+rx /home/jovyan/.julia

    # Add a startup.jl to copy
    ADD startup.jl /opt/julia/etc/julia

    USER jupyter
    # Configure environment
    ENV NB_USER=jupyter \
        NB_UID=9999
    ENV HOME=/home/$NB_USER
    # Configure the JULIA_DEPOT_PATH
    ENV JULIA_DEPOT_PATH="/home/jupyter/.julia:/home/jovyan/.julia:/opt/julia"
    RUN rm -rf .projects


