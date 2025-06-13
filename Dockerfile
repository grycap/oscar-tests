FROM ppodgorsek/robot-framework:latest

USER root

RUN yum update -y && \
    yum install -y \
    golang \
    && rm -rf /var/cache/yum

RUN pip install robotframework-jsonlibrary PyJWT oscar-python==1.3.1