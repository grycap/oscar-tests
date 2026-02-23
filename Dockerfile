FROM ppodgorsek/robot-framework:latest

USER root

RUN yum update -y && \
    rm -rf /var/cache/yum

RUN wget https://go.dev/dl/go1.25.1.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.25.1.linux-amd64.tar.gz && \
    rm -f go1.25.1.linux-amd64.tar.gz
ENV PATH=$PATH:/usr/local/go/bin

RUN pip install --no-cache-dir robotframework-jsonlibrary PyJWT
RUN pip install --no-cache-dir oscar-python==1.3.3
