FROM jupyter/scipy-notebook:latest
# For building on Xeon processors
ARG OPENBLAS_CORETYPE=HASWELL

# Core dependencies
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    fonts-dejavu \
    gfortran \
    gcc && \
    rm -rf /var/lib/apt/lists/*
USER jovyan 

# R Stuff
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

# Sage stuff
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    sagemath \
    sagemath-jupyter \ 
    subversion \ 
    python-pandas

# Fix SageMath Kernel
USER jovyan 
ENV CPATH=$CONDA_DIR/include
RUN sed -i 's/"\/usr\/bin\/sage"/"env", "PATH=\/usr\/local\/sbin:\/usr\/local\/bin:\/usr\/sbin:\/usr\/bin:\/sbin:\/bin", "\/usr\/bin\/sage"/' /usr/share/jupyter/kernels/sagemath/kernel.json

# Python extras 
RUN conda install python-graphviz && \ 
    pip install qeds fiona geopandas pyLDAvis gensim folium xgboost descartes pyarrow nbgitpuller nltk --upgrade

# JupyterLab extensions
RUN conda install -c conda-forge nodejs && \ 
    jupyter labextension install @jupyterlab/toc  --no-build && \ 
    jupyter labextension install @jupyter-widgets/jupyterlab-manager --no-build && \ 
    jupyter labextension install plotlywidget@1.1.1 --no-build && \ 
    jupyter labextension install jupyterlab-plotly@1.1.2 --no-build && \ 
    jupyter lab build --dev-build=False && \ 
    npm cache clean --force
    
# Julia install 
ENV JULIA_DEPOT_PATH=/opt/julia
ENV JULIA_PKGDIR=/opt/julia
ENV JULIA_VERSION=1.2.0
RUN mkdir $HOME/opt/julia-${JULIA_VERSION} && \
    cd /tmp && \
    wget -q https://julialang-s3.julialang.org/bin/linux/x64/`echo ${JULIA_VERSION} | cut -d. -f 1,2`/julia-${JULIA_VERSION}-linux-x86_64.tar.gz && \
    echo "926ced5dec5d726ed0d2919e849ff084a320882fb67ab048385849f9483afc47 *julia-${JULIA_VERSION}-linux-x86_64.tar.gz" | sha256sum -c - && \
    tar xzf julia-${JULIA_VERSION}-linux-x86_64.tar.gz -C $HOME/opt/julia-${JULIA_VERSION} --strip-components=1 && \
    rm /tmp/julia-${JULIA_VERSION}-linux-x86_64.tar.gz

# Julia install setup stuff
USER root 
RUN sudo ln -fs $HOME/opt/julia-*/bin/julia /usr/local/bin/julia
# Show Julia where conda libraries are 
RUN mkdir /etc/julia && \
    echo "push!(Libdl.DL_LOAD_PATH, \"$CONDA_DIR/lib\")" >> /etc/julia/juliarc.jl && \
    # Create JULIA_PKGDIR \
    mkdir $JULIA_PKGDIR && \
    chown $NB_USER $JULIA_PKGDIR && \
    fix-permissions $JULIA_PKGDIR

# Julia packages
USER jovyan 

# PackageCompiler step 
RUN julia -e "using Pkg; pkg\"add InstantiateFromURL\""
RUN julia -e "using Pkg; pkg\"add PackageCompiler#sd-notomls\""
RUN julia -e "using Pkg; pkg\"add GR Plots\""    
RUN julia -e "using Pkg; pkg\"add IJulia Images DualNumbers Unitful Compat LaTeXStrings UnicodePlots DataValues IterativeSolvers VisualRegressionTests GeometryTypes\"" 
RUN julia -e "using PackageCompiler; syso, sysold = PackageCompiler.compile_incremental(:Plots, install = true); cp(syso, sysold, force = true)" 
RUN julia -e "using Pkg; pkg\"precompile\""
RUN julia -e "using Pkg; pkg\"rm PackageCompiler\"; pkg\"gc\""    

# Other packages
RUN julia -e "using Pkg; pkg\"add InstantiateFromURL\""
RUN julia -e "using InstantiateFromURL; using Pkg; github_project(\"QuantEcon/quantecon-notebooks-julia\", version = \"0.3.0\"); packages_to_default_environment()"
RUN julia -e "using Pkg; pkg\"add OffsetArrays DiffEqBase DiffEqCallbacks DiffEqJump DifferentialEquations StochasticDiffEq IteratorInterfaceExtensions DiffEqOperators\""
RUN julia -e "using Pkg; pkg\"up Optim\"; pkg\"add ApproxFun BlockBandedMatrices Convex ECOS\""

# Knitro
RUN mkdir ~/.knitro && cd ~/.knitro && pwd && wget -qO- https://s3-us-west-2.amazonaws.com/jesseperla.com/knitro/knitro-12.0.0-z-Linux-64.tar.gz | tar -xzv
ENV KNITRODIR="/home/jupyter/.knitro/knitro-12.0.0-z-Linux-64"
ENV ARTELYS_LICENSE_NETWORK_ADDR="turtle.econ.ubc.ca:8349"
ENV LD_LIBRARY_PATH="$KNITRODIR/lib"
RUN julia -e "using Pkg; pkg\"add KNITRO\"; pkg\"test KNITRO\""
