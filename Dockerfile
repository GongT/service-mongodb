FROM mongo:latest
MAINTAINER GongT <gongteng524702837@gmail.com>

ENV AUTH yes
ENV STORAGE_ENGINE wiredTiger
ENV JOURNALING yes

LABEL org.nsg.alias='["mongodb"]'

ADD run.sh /run.sh
ADD set_mongodb_password.sh /set_mongodb_password.sh

EXPOSE 27017 28017

ENTRYPOINT "/run.sh"
CMD ["/run.sh"]

ARG SAFE_STRING
ARG VERSION_STRING
LABEL com.github.GongT.safe=$SAFE_STRING
LABEL com.github.GongT.version=$VERSION_STRING
