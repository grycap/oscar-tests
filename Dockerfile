FROM ppodgorsek/robot-framework:latest

USER root

RUN yum update -y && \
    yum install -y wget && \
    rm -rf /var/cache/yum

RUN wget -q https://go.dev/dl/go1.25.1.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.25.1.linux-amd64.tar.gz && \
    rm -f go1.25.1.linux-amd64.tar.gz

ENV PATH=$PATH:/usr/local/go/bin

RUN pip install --no-cache-dir \
    robotframework-jsonlibrary \
    PyJWT \
    locust
