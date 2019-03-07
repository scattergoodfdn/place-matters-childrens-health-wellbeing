
# Adapted from https://towardsdatascience.com/how-docker-can-help-you-become-a-more-effective-data-scientist-7fc048ef91d5
FROM ubuntu:16.04

# Adds metadata to the image as a key value pair example LABEL 
LABEL maintainer="Simon Kassel <skassel@azavea.com>"

RUN apt-get update --fix-missing && apt-get install -y wget bzip2 ca-certificates \
    build-essential \
    byobu \
    curl \
    git-core \
    htop \
    libxrender1 \
    pkg-config \
    python3-dev \
    python-pip \
    python-setuptools \
    python-virtualenv \
    unzip \
    nano \
    gdal-bin \
    python-gdal \
    xvfb \
    && \
apt-get clean && \
rm -rf /var/lib/apt/lists/*

RUN wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.4/wkhtmltox-0.12.4_linux-generic-amd64.tar.xz && \
    tar -xvf wkhtmltox-0.12.4_linux-generic-amd64.tar.xz && \
    cd wkhtmltox/bin/ && \
    mv wkhtmltopdf /usr/bin/wkhtmltopdf && \
    mv wkhtmltoimage /usr/bin/wkhtmltoimage && \
    chmod a+x /usr/bin/wkhtmltopdf && \
    chmod a+x /usr/bin/wkhtmltoimage

RUN echo 'export PATH=/opt/conda/bin:$PATH' > /etc/profile.d/conda.sh && \
    wget --quiet https://repo.continuum.io/archive/Anaconda3-5.0.0.1-Linux-x86_64.sh -O ~/anaconda.sh && \
    /bin/bash ~/anaconda.sh -b -p /opt/conda && \
    rm ~/anaconda.sh

RUN wget http://download.osgeo.org/libspatialindex/spatialindex-src-1.8.5.tar.gz && \
    tar xvzf spatialindex-src-1.8.5.tar.gz && \
    cd spatialindex-src-1.8.5 && \
    ./configure; make; make install && \
    ldconfig && \
    easy_install Rtree

ENV PATH /opt/conda/bin:$PATH

# Copying requirements.txt file
COPY requirements.txt requirements.txt

# pip install 
RUN pip install --upgrade pip
RUN pip install --no-cache -r requirements.txt &&\
    rm requirements.txt

RUN pip install requests==2.18.4
RUN conda install gdal==2.2.2
RUN conda install rasterio==0.36.0

# Open Ports for Jupyter
EXPOSE 8888

#Setup File System
RUN mkdir project
ENV HOME=/project
ENV SHELL=/bin/bash
VOLUME /project
WORKDIR /project

RUN rm -rf .bash_history
RUN rm -rf .python_history

RUN apt-get update
RUN apt-get -y install libgdal-dev libproj-dev libgeos-dev libudunits2-dev libv8-dev libcairo2-dev libnetcdf-dev

RUN apt-get update
RUN apt-get install -y software-properties-common

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9 

RUN add-apt-repository 'deb http://cloud.r-project.org/bin/linux/ubuntu xenial-cran35/' && \
apt-get update && \
apt-get remove r-base-core -y && apt-get install r-base-core  -y

# Run a shell script
CMD ["/bin/bash"]
