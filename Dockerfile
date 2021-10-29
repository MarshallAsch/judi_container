FROM ubuntu:focal

LABEL org.opencontainers.version="v1.0.0"

LABEL org.opencontainers.image.authors="Marshall Asch <masch@uoguelph.ca> (https://marshallasch.ca)"
LABEL org.opencontainers.image.url="https://github.com/MarshallAsch/judi_container.git"
LABEL org.opencontainers.image.source="https://github.com/MarshallAsch/oo-resources.git"
LABEL org.opencontainers.image.vendor="University of Guelph School of Computer Science"
LABEL org.opencontainers.image.licenses="GPL-3.0-only"
LABEL org.opencontainers.image.title="Offline Course Resouce"
LABEL org.opencontainers.image.description="This image is a base that can be used to act as an offline resource for students to contain all the instructional matrial and tools needed to do the course content"

ARG VERSION=v1.0.0
LABEL org.opencontainers.image.version="$VERSION"


ARG GRADLE_VERSION=7.2
ARG WIKI_VERSION=2.5.219
ARG NODE_VERSION=14

ENV DEBIAN_FRONTEND=noninteractive  \
    TERM=xterm-256color \
    UID=1000 \
    UNAME=student

# create a 'normal' user so everything does not need to be run as root
RUN useradd -m -s /bin/bash -u "${UID}" "${UNAME}" && \
    echo "${UNAME}:password" | chpasswd

# setup the man pages
RUN yes | unminimize

RUN apt-get update -y && apt-get install -y --no-install-recommends \
    wget \
    curl \
    git \
    vim \
    nano \
    openssh-server \
    nginx \
    openjdk-11-jdk \
    man \
    unzip \
    gcc \
    g++ \
    make \
    build-essential \
    sqlite3 \
    python3 \
    pip \
    tini \
    sudo \
&& rm -rf /var/lib/apt/lists/*

RUN echo "${UNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${UNAME} && \
    chmod 0440 /etc/sudoers.d/${UNAME}

# install gradle
RUN wget https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -P /tmp && \
    unzip -d /opt/gradle /tmp/gradle-${GRADLE_VERSION}-bin.zip && \
    ln -s /opt/gradle/gradle-${GRADLE_VERSION} /opt/gradle/latest && \
    echo -e 'export GRADLE_HOME=/opt/gradle/latest\nexport PATH=${GRADLE_HOME}/bin:${PATH}\n' >> /etc/profile.d/02-gradle.sh


# install node 14
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g npm


# install wikijs
RUN wget https://github.com/Requarks/wiki/releases/download/${WIKI_VERSION}/wiki-js.tar.gz -P /tmp && \
    mkdir /opt/wiki && \
    tar xzf /tmp/wiki-js.tar.gz -C /opt/wiki

COPY wiki_config.yml /opt/wiki/config.yml
RUN cd /opt/wiki && \
    npm rebuild sqlite3
COPY database.sqlite /opt/wiki/database.sqlite
EXPOSE 3000


# install jupyter
RUN pip3 install \
    jupyter \
    jupyterlab \
    ipykernel \
    beakerx-kernel-java \
    beakerx && \
    beakerx install && \
    beakerx_kernel_java install && \
    jupyter lab --generate-config && \
    echo "c.NotebookApp.password='$(python3 -c "from notebook.auth import passwd; print(passwd('password'))")'" >> /root/.jupyter/jupyter_notebook_config.py

EXPOSE 8888

EXPOSE 22

# Configure environment
#ENV SHELL=/bin/bash

COPY motd.txt wiki.sh jupyter.sh entrypoint.sh /

# copy all the builtin jupyter notebooks
COPY builtinNotebooks /jupyter/builtin

WORKDIR /course
VOLUME ["/course"]

CMD ["/entrypoint.sh"]

# these two labels will change every time the container is built
# put them at the end because of layer caching
ARG GIT_COMMIT
LABEL org.opencontainers.image.revision="${GIT_COMMIT}"

ARG BUILD_DATE
LABEL org.opencontainers.image.created="${BUILD_DATE}"
