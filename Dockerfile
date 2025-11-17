FROM ppodgorsek/robot-framework:latest

USER root

RUN yum update -y && \
    rm -rf /var/cache/yum

RUN wget https://go.dev/dl/go1.25.1.linux-amd64.tar.gz
RUN tar -C /usr/local -xzf go1.25.1.linux-amd64.tar.gz
ENV PATH=$PATH:/usr/local/go/bin

RUN pip install robotframework-jsonlibrary PyJWT  oscar-python==1.3.3