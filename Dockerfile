FROM jupyter/scipy-notebook:latest
# For building on Xeon processors
ARG OPENBLAS_CORETYPE=HASWELL
USER root
RUN useradd -m -s /bin/bash -N -u 9999 jupyter
USER jupyter
# Configure environment
ENV NB_USER=jupyter \
    NB_UID=9999
ENV XDG_CACHE_HOME=/home/$NB_USER/.cache/ \
    HOME=/home/$NB_USER
WORKDIR $HOME

# Core dependencies
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    fonts-dejavu \
    gfortran \
    gcc && \
    rm -rf /var/lib/apt/lists/*
USER jupyter 

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

# Sudo setup 
ADD /sudoers.txt /etc/sudoers
RUN chmod 440 /etc/sudoers


# Fix SageMath Kernel
USER jupyter 
ENV CPATH=$CONDA_DIR/include
RUN sudo sed -i 's/"\/usr\/bin\/sage"/"env", "PATH=\/usr\/local\/sbin:\/usr\/local\/bin:\/usr\/sbin:\/usr\/bin:\/sbin:\/bin", "\/usr\/bin\/sage"/' /usr/share/jupyter/kernels/sagemath/kernel.json

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
RUN sudo mkdir -p /opt/julia-${JULIA_VERSION} && \
    cd /tmp && \
    wget -q https://julialang-s3.julialang.org/bin/linux/x64/`echo ${JULIA_VERSION} | cut -d. -f 1,2`/julia-${JULIA_VERSION}-linux-x86_64.tar.gz && \
    echo "926ced5dec5d726ed0d2919e849ff084a320882fb67ab048385849f9483afc47 *julia-${JULIA_VERSION}-linux-x86_64.tar.gz" | sha256sum -c - && \
    sudo tar xzf julia-${JULIA_VERSION}-linux-x86_64.tar.gz -C /opt/julia-${JULIA_VERSION} --strip-components=1 && \
    rm /tmp/julia-${JULIA_VERSION}-linux-x86_64.tar.gz

# Julia install setup stuff
RUN sudo ln -fs /opt/julia-*/bin/julia /usr/local/bin/julia
# Show Julia where conda libraries are 
USER root
RUN mkdir /etc/julia && \
    echo "push!(Libdl.DL_LOAD_PATH, \"$CONDA_DIR/lib\")" >> /etc/julia/juliarc.jl && \
    # Create JULIA_PKGDIR \
    mkdir $JULIA_PKGDIR && \
    chown $NB_USER $JULIA_PKGDIR && \
    fix-permissions $JULIA_PKGDIR

# Julia packages
USER jupyter 

# PackageCompiler step 
RUN sudo apt-get install -y gettext
RUN julia -e "using Pkg; pkg\"add InstantiateFromURL\""
RUN julia -e "using Pkg; pkg\"add PackageCompiler\""
RUN julia -e "using Pkg; pkg\"add GR Plots StatsPlots\""    
RUN sudo apt-get update && sudo apt-get install -y --no-install-recommends unzip \
    gettext \
    zlib1g-dev \
    libffi-dev \
    libpng-dev \
    libpixman-1-dev \
    libpoppler-dev \
    librsvg2-dev \
    libcairo2-dev \
    libpango1.0-0 \
    xvfb xserver-xephyr vnc4server \ 
    && sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/*
# RUN julia -e "using Pkg; using PackageCompiler; cp(joinpath(dirname(Pkg.Types.find_project_file()), \"Manifest.toml\"), PackageCompiler.sysimg_folder(\"Manifest.toml\"), force = true); PackageCompiler.compile_incremental(:Plots, force = true)"
# RUN julia -e "using Pkg; pkg\"precompile\""
# RUN julia -e "using Pkg; pkg\"rm PackageCompiler\"; pkg\"gc\""    

# Other packages
RUN julia -e "using InstantiateFromURL; using Pkg; github_project(\"QuantEcon/quantecon-notebooks-julia\", version = \"0.4.0\"); packages_to_default_environment()"
RUN julia -e "using Pkg; pkg\"up Optim\"; pkg\"add ApproxFun IJulia BlockBandedMatrices Convex ECOS\""
RUN julia -e "using Pkg; pkg\"pin IJulia\""

# Knitro
RUN sudo mkdir /opt/knitro && cd /opt/knitro && pwd && wget -qO- https://s3-us-west-2.amazonaws.com/jesseperla.com/knitro/knitro-12.0.0-z-Linux-64.tar.gz | sudo tar -xzv
ENV KNITRODIR="/opt/knitro/knitro-12.0.0-z-Linux-64"
ENV ARTELYS_LICENSE_NETWORK_ADDR="turtle.econ.ubc.ca:8349"
ENV LD_LIBRARY_PATH="$KNITRODIR/lib"
RUN julia -e "using Pkg; pkg\"add KNITRO\""

RUN julia -e "using Pkg; pkg\"up Compat\"; pkg\"precompile\""
# Last-minute setup 
RUN rm ~/Project.toml ~/Manifest.toml

        RUN sudo  mv $HOME/.local/share/jupyter/kernels/julia* $CONDA_DIR/share/jupyter/kernels/ 
            RUN  sudo chmod -R go+rx $CONDA_DIR/share/jupyter 
                RUN  sudo rm -rf $HOME/.local 

ENV ARTELYS_LICENSE "/opt/knitro-license"
