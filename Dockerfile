FROM buildpack-deps:21.10

RUN apt-get -y update && \
    apt-get -y install \
        apt-transport-https \
        ca-certificates \
        software-properties-common && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    apt-key fingerprint 0EBFCD88 && \
    add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
       $(lsb_release -cs) \
       stable" && \
    export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" && \
    echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    apt-get -y update && \
    apt-get -y install \
      docker-ce \
      google-cloud-sdk \
    && rm -rf /var/lib/apt/lists/*

RUN echo "Europe/Copenhagen" > /etc/timezone 

ADD src /build

WORKDIR /build

ENTRYPOINT [ "/build/build-datadir-image.sh" ]
