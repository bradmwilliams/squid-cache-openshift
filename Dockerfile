FROM registry.ci.openshift.org/openshift/centos:stream9
LABEL maintainer="brawilli@redhat.com"

ENV SQUID_CONFIG_FILE=/etc/squid/squid.conf \
    SQUID_CACHE_DIR=/var/spool/squid \
    SQUID_LOG_DIR=/var/log/squid

RUN dnf install --nodocs -y squid which && dnf clean all && rm -rf /var/cache/dnf

RUN chgrp -R 0 /etc/squid && chmod -R g+rwX /etc/squid

RUN chgrp -R 0 /var/run/squid && chmod -R g+rwX /var/run/squid

RUN mkdir -p ${SQUID_CACHE_DIR} && chgrp -R 0 ${SQUID_CACHE_DIR} && chmod -R g+rwX ${SQUID_CACHE_DIR}

RUN mkdir -p ${SQUID_LOG_DIR} && chgrp -R 0 ${SQUID_LOG_DIR} && chmod -R g+rwX ${SQUID_LOG_DIR}

COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod 775 /sbin/entrypoint.sh

COPY squid.conf /etc/squid/squid.conf

USER 1001

EXPOSE 3128/tcp
ENTRYPOINT ["/sbin/entrypoint.sh"]
