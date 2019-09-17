FROM jupyter/scipy-notebook:latest
ARG OPENBLAS_CORETYPE=HASWELL
ENV NB_USER=jovyan
ENV HOME=/home/$NB_USER
USER root

# R pre-requisites
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    fonts-dejavu \
    gfortran \
    gcc && \
    rm -rf /var/lib/apt/lists/*

# Julia dependencies
# install Julia packages in /opt/julia instead of $HOME
ENV JULIA_DEPOT_PATH=/opt/julia
ENV JULIA_PKGDIR=/opt/julia
ENV JULIA_VERSION=1.2.0

RUN mkdir /opt/julia-${JULIA_VERSION} && \
    cd /tmp && \
    wget -q https://julialang-s3.julialang.org/bin/linux/x64/`echo ${JULIA_VERSION} | cut -d. -f 1,2`/julia-${JULIA_VERSION}-linux-x86_64.tar.gz && \
    echo "926ced5dec5d726ed0d2919e849ff084a320882fb67ab048385849f9483afc47 *julia-${JULIA_VERSION}-linux-x86_64.tar.gz" | sha256sum -c - && \
    tar xzf julia-${JULIA_VERSION}-linux-x86_64.tar.gz -C /opt/julia-${JULIA_VERSION} --strip-components=1 && \
    rm /tmp/julia-${JULIA_VERSION}-linux-x86_64.tar.gz
RUN ln -fs /opt/julia-*/bin/julia /usr/local/bin/julia

# Show Julia where conda libraries are \
RUN mkdir /etc/julia && \
    echo "push!(Libdl.DL_LOAD_PATH, \"$CONDA_DIR/lib\")" >> /etc/julia/juliarc.jl && \
    # Create JULIA_PKGDIR \
    mkdir $JULIA_PKGDIR && \
    chown $NB_USER $JULIA_PKGDIR && \
    fix-permissions $JULIA_PKGDIR

USER $NB_UID
# R packages including IRKernel which gets installed globally.
RUN conda install --quiet --yes \
    'r-base=3.6.1' \
    'r-caret=6.0*' \
    'r-crayon=1.3*' \
    'r-devtools=2.1*' \
    'r-forecast=8.7*' \
    'r-hexbin=1.27*' \
    'r-htmltools=0.3*' \
    'r-htmlwidgets=1.3*' \
    'r-irkernel=1.0*' \
    'r-nycflights13=1.0*' \
    'r-plyr=1.8*' \
    'r-randomforest=4.6*' \
    'r-rcurl=1.95*' \
    'r-reshape2=1.4*' \
    'r-rmarkdown=1.14*' \
    'r-rsqlite=2.1*' \
    'r-shiny=1.3*' \
    'r-sparklyr=1.0*' \
    'r-tidyverse=1.2*' \
    'rpy2=2.9*' \
    && \
    conda clean --all -f -y && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Add Julia packages. Only add HDF5 if this is not a test-only build since
# it takes roughly half the entire build time of all of the images on Travis
# to add this one package and often causes Travis to timeout.
#
# Install IJulia as jovyan and then move the kernelspec out
# to the system share location. Avoids problems with runtime UID change not
# taking effect properly on the .local folder in the jovyan home dir.
RUN julia -e 'import Pkg; Pkg.update()' && \
    (test $TEST_ONLY_BUILD || julia -e 'import Pkg; Pkg.add("HDF5")') && \
    julia -e "using Pkg; pkg\"add IJulia\"; pkg\"precompile\"" && \ 
    # move kernelspec out of home \
    mv $HOME/.local/share/jupyter/kernels/julia* $CONDA_DIR/share/jupyter/kernels/ && \
    chmod -R go+rx $CONDA_DIR/share/jupyter && \
    rm -rf $HOME/.local && \
    fix-permissions $JULIA_PKGDIR $CONDA_DIR/share/jupyter

# Julia packages    
RUN julia -e "using Pkg; pkg\"add InstantiateFromURL\""
# QuantEcon stuff
RUN julia -e "using InstantiateFromURL; using Pkg; github_project(\"QuantEcon/quantecon-notebooks-julia\", version = \"0.3.0\"); pkg\"activate \""
# PackageCompiler 
RUN julia -e "using Pkg; pkg\"add PackageCompiler#sd-notomls\""
RUN julia -e "using Pkg; pkg\"add GR Plots\""    
RUN julia -e "using Pkg; pkg\"add IJulia Images DualNumbers Unitful Compat LaTeXStrings UnicodePlots DataValues IterativeSolvers VisualRegressionTests GeometryTypes\"" 


USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    sagemath \
    sagemath-jupyter \ 
    subversion \ 
    python-pandas

# Fix SageMath Kernel
ENV CPATH=$CONDA_DIR/include
RUN sed -i 's/"\/usr\/bin\/sage"/"env", "PATH=\/usr\/local\/sbin:\/usr\/local\/bin:\/usr\/sbin:\/usr\/bin:\/sbin:\/bin", "\/usr\/bin\/sage"/' /usr/share/jupyter/kernels/sagemath/kernel.json

# PackageCompiler step 
RUN julia -e "using PackageCompiler; syso, sysold = PackageCompiler.compile_incremental(:Plots, install = true); cp(syso, sysold, force = true)" 
RUN julia -e "using Pkg; pkg\"precompile\""
RUN julia -e "using Pkg; pkg\"rm PackageCompiler\"; pkg\"gc\""    

# Jupyter user setup 
RUN useradd -m -s /bin/bash -N -u 9999 jupyter
RUN chown -R jupyter /home/jupyter/
RUN chown -R jupyter /opt/julia/
RUN chown -R jupyter /opt/julia-1.2.0/
RUN chown -R jupyter /home/jovyan/ && \ 
chmod -R go+rx $CONDA_DIR/share/jupyter && \
rm -rf $HOME/.local && \
# Nuke the registry that came with Julia.
rm -rf /opt/julia-1.2.0/local/share/julia/registries 

USER jupyter
# Python extras 
RUN conda install python-graphviz && \ 
    pip install qeds fiona geopandas pyLDAvis gensim folium xgboost descartes pyarrow nbgitpuller --upgrade

# JupyterLab Extensions
RUN conda install -c conda-forge nodejs && \ 
    jupyter labextension install @jupyterlab/toc  --no-build && \ 
    jupyter labextension install @jupyter-widgets/jupyterlab-manager --no-build && \ 
    jupyter labextension install plotlywidget@1.1.1 --no-build && \ 
    jupyter labextension install jupyterlab-plotly@1.1.2 --no-build && \ 
    jupyter lab build --dev-build=False && \ 
    npm cache clean --force
        
# Configure environment
ENV NB_USER=jupyter \
    NB_UID=9999
ENV HOME=/home/$NB_USER

# Julia DEPOT fudging
ENV JULIA_DEPOT_PATH="/home/jupyter/.julia:/opt/julia"
ADD startup.jl /opt/julia-1.2.0/etc/julia/startup.jl    
RUN julia /opt/julia-1.2.0/etc/julia/startup.jl
ENV XDG_CACHE_HOME=/home/$NB_USER/.cache/ \
HOME=/home/$NB_USER
WORKDIR $HOME
USER jupyter
RUN julia -e "using Pkg; pkg\"add OffsetArrays DiffEqBase DiffEqCallbacks DiffEqJump DifferentialEquations StochasticDiffEq IteratorInterfaceExtensions DiffEqOperators\""
RUN julia -e "using InstantiateFromURL; using Pkg; github_project(\"QuantEcon/quantecon-notebooks-julia\", version = \"0.3.0\"); packages_to_default_environment()"
