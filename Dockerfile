FROM callysto/pims-minimal

MAINTAINER Arnav Sood <arnav.sood@ubc.ca>

USER root

# git lfs
RUN build_deps="curl" && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${build_deps} ca-certificates && \
    curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git-lfs && \
    git lfs install && \
    DEBIAN_FRONTEND=noninteractive apt-get purge -y --auto-remove ${build_deps} && \
    rm -r /var/lib/apt/lists/*

# Sundials, NLopt, MPI, Nemo, Cairo
RUN apt-get update && apt-get install -y --no-install-recommends \
    libsundials-dev \
    libnlopt0 \
    libnlopt-dev \
    openmpi-bin \
    libopenmpi-dev \
    m4 \
    yasm \
    libacl1-dev \
    gettext \
    zlib1g-dev \
    libffi-dev \
    libpng-dev \
    libpixman-1-dev \
    libpoppler-dev \
    librsvg2-dev \
    libcairo2-dev \
    libpango1.0-0 \
    tk-dev \
    pkg-config \
    curl \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# CBC
RUN mkdir -p /opt/cbc \
  && curl -s -L http://www.coin-or.org/download/source/Cbc/Cbc-2.9.9.tgz | \
     tar -C /opt/cbc -x -z --strip-components=1 -f - \
  && cd /opt/cbc \
  && ./configure --prefix=/usr/local \
    --enable-dependency-linking \
    --without-blas \
    --without-lapack \
    --enable-cbc-parallel \
  && make install && echo "/usr/local/lib" > /etc/ld.so.conf.d/cbc.conf \
  && ldconfig && rm -rf /opt/cbc

# Stan
RUN mkdir -p /opt/cmdstan \
  && curl -s -L https://github.com/stan-dev/cmdstan/releases/download/v2.18.0/cmdstan-2.18.0.tar.gz | \
     tar -C /opt/cmdstan -x -z --strip-components=1 -f - \
  && (cd /opt/cmdstan && echo "CC=g++" >> make/local && echo "CXX=g++" >> make/local && make build) \
  && echo "export CMDSTAN_HOME=/usr/share/cmdstan" > /etc/profile.d/cmdstan.sh \
  && chmod 755 /etc/profile.d/cmdstan.sh \
  && rm -rf /opt/stan

# MPIR
RUN mkdir -p /opt/mpir \
  && curl -s -L http://mpir.org/mpir-3.0.0.tar.bz2 | \
     tar -C /opt/mpir -x -j --strip-components=1 -f - \
  && cd /opt/mpir \
  && ./configure M4=/usr/bin/m4 --enable-gmpcompat --disable-static --enable-shared \
  && make && make install \
  && rm -rf /opt/mpir

# MPFR
RUN mkdir -p /opt/mpfr \
  && cd /opt/mpfr \
  && curl -s -L http://ftp.gnu.org/gnu/mpfr/mpfr-4.0.1.tar.bz2 | \
     tar -C /opt/mpfr -x -j --strip-components=1 -f - \
  && cd /opt/mpfr \
  && ./configure --with-gmp=/usr/local --disable-static --enable-shared \
  && make && make install \
  && rm -rf /opt/mpfr

# Flint2
RUN mkdir -p /opt/flint2 \
  && cd /opt/flint2 \
  && git clone https://github.com/fredrik-johansson/flint2 /opt/flint2 \
  && cd /opt/flint2 \
  && ./configure --disable-static --enable-shared --with-mpir --with-mpfr \
  && make && make install \
  &&  rm -rf /opt/flint2

# Julia
RUN mkdir -p /opt/julia-1.1.0 \
  # Download and unpack Julia binaries
  && curl -s -L https://julialang-s3.julialang.org/bin/linux/x64/1.1/julia-1.1.0-linux-x86_64.tar.gz | \
     tar -C /opt/julia-1.1.0 -x -z --strip-components=1 -f - \
  # Make 'julia-1.1' point to julia-1.1.0
  && ln -fs /opt/julia-1.1.0 /opt/julia-1.1 \
  # Make 'julia' point to julia-1.1.0
  && rm -rf /opt/julia && ln -fs /opt/julia-1.1.0 /opt/julia \
  # Make '/usr/bin/julia' point to our 'julia', which is 'julia-1.1.0'
  && ln -fs /opt/julia/bin/julia /usr/bin/julia \
  # Give ownership of that Julia install to 'jovyan', the "shared user."
  && chown -R jovyan /opt/julia-1.1.0

# Configure our shared environment
# Switch over to 'jovyan'
ENV NB_USER=jovyan
ENV HOME=/home/$NB_USER


USER $NB_USER

# Julia package stuff

# Prerequisites for AOT baking
RUN julia -e "using Pkg; pkg\"dev PackageCompiler\""
RUN julia -e "using Pkg; pkg\"add IJulia InstantiateFromURL Plots DiffEqBase DataFrames Parameters Distributions DualNumbers Expectations Unitful Compat NLsolve LaTeXStrings UnicodePlots DataValues IterativeSolvers Interpolations VisualRegressionTests\"" 

# Main packages 
USER root 
# QuantEcon packages 
RUN julia -e "using InstantiateFromURL; activate_github(\"QuantEcon/QuantEconLecturePackages\", add_default_environment = true)"
RUN julia -e "using InstantiateFromURL; activate_github(\"QuantEcon/QuantEconLectureAllPackages\", add_default_environment = true)"

# Bugfix packages
RUN julia -e "using Pkg; pkg\"add Images\""

# Prebake stuff
RUN julia -e "using PackageCompiler; compile_package(\"Plots\", \"NLsolve\", \"Interpolations\", \"Parameters\", force = true)"

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

