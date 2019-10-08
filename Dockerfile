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
    pip install qeds fiona geopandas pyLDAvis gensim folium xgboost descartes pyarrow nbgitpuller --upgrade

