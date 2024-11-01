FROM debian:bullseye-20241016-slim

ENV CLAMAV_CLAMDCONF_FILE="/usr/local/etc/clamd.conf" \
    CLAMAV_FRESHCLAMCONF_FILE="/usr/local/etc/freshclam.conf" \
    CLAMAV_LATEST_STABLE_SOURCE_URL="https://www.clamav.net/downloads/production/clamav-1.1.0.tar.gz" \
    CLAMAV_LATEST_STABLE_SOURCE_SIG_URL="https://www.clamav.net/downloads/production/clamav-1.1.0.tar.gz.sig" \
    CLAMAV_MILTERCONF_FILE="/usr/local/etc/clamav-milter.conf" \
    ENABLE_OPENDKIM="false" \
    POSTFIX_CHECK_RECIPIENT_ACCESS_FINAL_ACTION="defer" \
    POSTFIX_REJECT_INVALID_HELO_HOSTNAME="true" \
    POSTFIX_REJECT_NON_FQDN_HELO_HOSTNAME="true" \
    POSTFIX_REJECT_UNKNOWN_SENDER_DOMAIN="true" \
    POSTFIX_LDAP_DEBUG_LEVEL=0 \
    POSTFIX_LDAP_QUERY_FILTER="(&(|(objectclass=person)(objectclass=group))(proxyAddresses=smtp:%s))" \
    POSTFIX_LDAP_VERSION=3 \
    POSTFIX_LDAP_RECIPIENT_ACCESS_CONF_FILE="/etc/postfix/ldap_recipient_access.cf" \
    POSTFIX_RELAYHOST_PORT=25 \
    POSTGREY_SYSTEM_WHITELIST_FILE=/opt/postgrey/postgrey_whitelist_clients \
    POSTGREY_WHITELIST_URL=https://postgrey.schweikert.ch/pub/postgrey_whitelist_clients \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    SYSLOG_PRIORITY=6 \
    WIETSE_PGP_KEY_URL=http://ftp.porcupine.org/mirrors/postfix-release/wietse.pgp

COPY rootfs/ /

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -x && \
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    # Packages to keep
    KEPT_PACKAGES+=(busybox-syslogd) && \
    KEPT_PACKAGES+=(bzip2) && \
    KEPT_PACKAGES+=(ca-certificates) && \
    KEPT_PACKAGES+=(curl) && \
    KEPT_PACKAGES+=(gnupg2) && \
    KEPT_PACKAGES+=(libberkeleydb-perl) && \
    KEPT_PACKAGES+=(libicu-dev) && \
    KEPT_PACKAGES+=(libjson-c5) && \
    KEPT_PACKAGES+=(libldap-2.4-2) && \
    KEPT_PACKAGES+=(libmail-spf-perl) && \
    KEPT_PACKAGES+=(libmilter1.0.1) && \
    KEPT_PACKAGES+=(libncurses6) && \
    KEPT_PACKAGES+=(libnet-server-perl) && \
    KEPT_PACKAGES+=(libnetaddr-ip-perl) && \
    KEPT_PACKAGES+=(libpcre2-posix2) && \
    KEPT_PACKAGES+=(libpcre3) && \
    KEPT_PACKAGES+=(libsasl2-2) && \
    KEPT_PACKAGES+=(libsys-hostname-long-perl) && \
    KEPT_PACKAGES+=(libxml2) && \
    KEPT_PACKAGES+=(net-tools) && \
    KEPT_PACKAGES+=(opendkim-tools) && \
    KEPT_PACKAGES+=(opendkim) && \
    KEPT_PACKAGES+=(miltertest) && \
    KEPT_PACKAGES+=(procps) && \
    KEPT_PACKAGES+=(python3) && \
    KEPT_PACKAGES+=(socat) && \
    KEPT_PACKAGES+=(zlib1g) && \
    # Packages to remove after image build
    TEMP_PACKAGES+=(autoconf) && \
    TEMP_PACKAGES+=(automake) && \
    TEMP_PACKAGES+=(build-essential) && \
    TEMP_PACKAGES+=(check) && \
    TEMP_PACKAGES+=(cmake) && \
    TEMP_PACKAGES+=(git) && \
    TEMP_PACKAGES+=(libbz2-dev) && \
    TEMP_PACKAGES+=(libcurl4-openssl-dev) && \
    TEMP_PACKAGES+=(libdb5.3-dev) && \
    TEMP_PACKAGES+=(libjson-c-dev) && \
    TEMP_PACKAGES+=(libldap2-dev) && \
    TEMP_PACKAGES+=(libmilter-dev) && \
    TEMP_PACKAGES+=(libncurses5-dev) && \
    TEMP_PACKAGES+=(libpcre2-dev) && \
    TEMP_PACKAGES+=(libpcre3-dev) && \
    TEMP_PACKAGES+=(libsasl2-dev) && \
    TEMP_PACKAGES+=(libssl-dev) && \
    TEMP_PACKAGES+=(libtool-bin) && \
    TEMP_PACKAGES+=(libtool) && \
    TEMP_PACKAGES+=(libxml2-dev) && \
    TEMP_PACKAGES+=(pkg-config) && \
    TEMP_PACKAGES+=(python3-pip) && \
    TEMP_PACKAGES+=(python3-pytest) && \
    TEMP_PACKAGES+=(texinfo) && \
    TEMP_PACKAGES+=(valgrind) && \
    TEMP_PACKAGES+=(zlib1g-dev) && \
    # Install packages.
    apt-get update && \
    apt-get install -o Dpkg::Options::="--force-confold" --force-yes -y --no-install-recommends \
        ${KEPT_PACKAGES[@]} \
        ${TEMP_PACKAGES[@]} \
        && \
    # Create groups & users & dirs
    mkdir -p /etc/mail/dkim && \
    groupadd --system postdrop && \
    groupadd --system clamav && \
    groupadd --system postgrey && \
    useradd \
        --groups postdrop \
        --no-create-home \
        --no-user-group \
        --system \
        --shell=/usr/sbin/nologin \
        postfix \
        && \
    useradd \
        --groups clamav \
        --no-create-home \
        --no-user-group \
        --system \
        --shell=/usr/sbin/nologin \
        clamav \
        && \
    useradd \
        --groups postgrey \
        --no-create-home \
        --no-user-group \
        --system \
        --shell=/usr/sbin/nologin \
        postgrey \
        && \
    # Install postgrey
    mkdir -p /src/postgrey && \
    curl --location --output /src/postgrey.tar.gz https://postgrey.schweikert.ch/pub/postgrey-latest.tar.gz && \
    tar xf /src/postgrey.tar.gz -C /src/postgrey && \
    pushd "$(find /src/postgrey -maxdepth 1 -type d | tail -1)" && \
    mkdir -p /opt/postgrey && \
    cp -Rv ./* /opt/postgrey && \
    mkdir -p /etc/postgrey && \
    touch /etc/postgrey/postgrey_whitelist_clients.local && \
    touch /etc/postgrey/postgrey_whitelist_recipients.local && \
    ln -s /opt/postgrey/postgrey /usr/local/bin/postgrey && \
    mkdir -p /var/spool/postfix/postgrey && \
    popd && \
    # Install rust
    curl --location --output /src/rustup.sh https://sh.rustup.rs && \
    chmod a+x /src/rustup.sh && \
    /src/rustup.sh -y && \
    source "$HOME/.cargo/env" && \
    # Install clamav
    mkdir -p /src/clamav && \
    curl --location --output /src/clamav.tar.gz "${CLAMAV_LATEST_STABLE_SOURCE_URL}" && \
    curl --location --output /src/clamav.tar.gz.sig "${CLAMAV_LATEST_STABLE_SOURCE_SIG_URL}" && \
    # /talos.gpg is from clamav downloads > talos pgp public key
    gpg2 --import /talos.gpg && \
    gpg2 --verify /src/clamav.tar.gz.sig /src/clamav.tar.gz || exit 1 && \
    tar xf /src/clamav.tar.gz -C /src/clamav && \
    pushd "$(find /src/clamav -maxdepth 1 -type d | tail -1)" && \
    mkdir -p ./build && \
    pushd ./build && \
    cmake .. && \
    cmake --build . && \
    ctest && \
    cmake --build . --target install && \
    ldconfig && \
    mkdir -p /var/lib/clamav && \
    mkdir -p /run/freshclam && \
    mkdir -p /run/clamav-milter && \
    mkdir -p /run/clamd && \
    popd && \
    popd && \
    # Get postfix-policyd-spf-perl
    mkdir -p /src/postfix-policyd-spf-perl && \
    git clone git://git.launchpad.net/postfix-policyd-spf-perl /src/postfix-policyd-spf-perl && \
    pushd /src/postfix-policyd-spf-perl && \
    BRANCH_POSTFIX_POLICYD_SPF_PERL="$(git tag --sort='-creatordate' | head -1)" && \
    git checkout "${BRANCH_POSTFIX_POLICYD_SPF_PERL}" && \
    cp -v /src/postfix-policyd-spf-perl/postfix-policyd-spf-perl /usr/local/lib/policyd-spf-perl && \
    popd && \
    # Get postfix source & signature & author key
    mkdir -p /src/postfix && \
    POSTFIX_STABLE_FAMILY="$(curl http://ftp.porcupine.org/mirrors/postfix-release/index.html | grep -oP 'Postfix [\d.]+ stable release' | grep -v candidate | head -1 | grep -oP '[\d.]+')" && \
    POSTFIX_STABLE_DOWNLOAD_SOURCE_FILE="$(curl http://ftp.porcupine.org/mirrors/postfix-release/index.html | grep -P '<a href=\"official/postfix-' | grep "$POSTFIX_STABLE_FAMILY" | grep '.tar.gz\">Source code</a>' | head -1 | cut -d \" -f 2)" && \
    POSTFIX_STABLE_DOWNLOAD_SOURCE_GPG2="$(curl http://ftp.porcupine.org/mirrors/postfix-release/index.html | grep -P '<a href=\"official/postfix-' | grep "$POSTFIX_STABLE_FAMILY" | grep '.tar.gz.gpg2\">GPG signature</a>' | head -1 | cut -d \" -f 2)" && \
    curl --location --output /src/postfix.tar.gz "http://ftp.porcupine.org/mirrors/postfix-release/${POSTFIX_STABLE_DOWNLOAD_SOURCE_FILE}" && \
    curl --location --output /src/postfix.tar.gz.gpg2 "http://ftp.porcupine.org/mirrors/postfix-release/${POSTFIX_STABLE_DOWNLOAD_SOURCE_GPG2}" && \
    curl --location --output /src/wietse.pgp "${WIETSE_PGP_KEY_URL}" && \
    gpg2 --import /src/wietse.pgp && \
    gpg2 --verify /src/postfix.tar.gz.gpg2 /src/postfix.tar.gz || exit 1 && \
    tar xf /src/postfix.tar.gz -C /src/postfix && \
    # Build postfix
    pushd "$(find /src/postfix -maxdepth 1 -type d | tail -1)" && \
    make \
      makefiles \
      pie=yes \
      shared=yes \
      dynamicmaps=yes \
      CCARGS="-DUSE_TLS \
              -DHAS_PCRE $(pcre-config --cflags) \
              -DHAS_LDAP \
              -I/usr/include/sasl \
              -DUSE_LDAP_SASL \
              " \
      AUXLIBS="-lssl -lcrypto -lsasl2" \
      AUXLIBS_PCRE="$(pcre-config --libs)" \
      AUXLIBS_LDAP="-lldap -llber" \
      && \
    make && \
    # Install postfix
    POSTFIX_INSTALL_OPTS="" && \
    POSTFIX_INSTALL_OPTS="${POSTFIX_INSTALL_OPTS} -non-interactive" && \
    POSTFIX_INSTALL_OPTS="${POSTFIX_INSTALL_OPTS} install_root=/" && \
    POSTFIX_INSTALL_OPTS="${POSTFIX_INSTALL_OPTS} tempdir=/tmp" && \
    POSTFIX_INSTALL_OPTS="${POSTFIX_INSTALL_OPTS} config_directory=/etc/postfix" && \
    POSTFIX_INSTALL_OPTS="${POSTFIX_INSTALL_OPTS} data_directory=/var/lib/postfix" && \
    POSTFIX_INSTALL_OPTS="${POSTFIX_INSTALL_OPTS} daemon_directory=/usr/libexec/postfix" && \
    POSTFIX_INSTALL_OPTS="${POSTFIX_INSTALL_OPTS} command_directory=/usr/sbin" && \
    POSTFIX_INSTALL_OPTS="${POSTFIX_INSTALL_OPTS} html_directory=/opt/postfix_html" && \
    POSTFIX_INSTALL_OPTS="${POSTFIX_INSTALL_OPTS} queue_directory=/var/spool/postfix" && \
    POSTFIX_INSTALL_OPTS="${POSTFIX_INSTALL_OPTS} sendmail_path=/usr/sbin/sendmail" && \
    POSTFIX_INSTALL_OPTS="${POSTFIX_INSTALL_OPTS} newaliases_path=/usr/sbin/newaliases" && \
    POSTFIX_INSTALL_OPTS="${POSTFIX_INSTALL_OPTS} mailq_path=/usr/sbin/mailq" && \
    POSTFIX_INSTALL_OPTS="${POSTFIX_INSTALL_OPTS} mail_owner=postfix" && \
    POSTFIX_INSTALL_OPTS="${POSTFIX_INSTALL_OPTS} setgid_group=postdrop" && \
    POSTFIX_INSTALL_OPTS="${POSTFIX_INSTALL_OPTS} manpage_directory=/usr/share/man" && \
    POSTFIX_INSTALL_OPTS="${POSTFIX_INSTALL_OPTS} meta_directory=/etc/postfix" && \
    POSTFIX_INSTALL_OPTS="${POSTFIX_INSTALL_OPTS} readme_directory=/opt/postfix_readme" && \
    make install POSTFIX_INSTALL_OPTS="${POSTFIX_INSTALL_OPTS}" && \
    cp /etc/postfix/master.cf /etc/postfix/master.cf.original && \
    mkdir -p /etc/postfix/tables && \
    mkdir -p /etc/postfix/local_aliases && \
    popd && \
    # Install s6-overlay
    curl --location --output /src/deploy-s6-overlay.sh https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh && \
    chmod a+x /src/deploy-s6-overlay.sh && \
    /src/deploy-s6-overlay.sh && \
    # Clean up
    rustup self uninstall -y && \
    apt-get remove -y ${TEMP_PACKAGES[@]} && \
    apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /src /tmp/* /var/lib/apt/lists/* && \
    find /var/log -type f -iname "*log" -exec truncate --size 0 {} \; && \
    # Document versions
    opendkim -V | grep OpenDKIM | sed "s/OpenDKIM Filter //g" >> /VERSIONS && \
    postgrey --version >> /VERSIONS && \
    echo "ClamAV $(clamconf --version | tr -s ' ' | cut -d ' ' -f 5)" >> /VERSIONS && \
    echo "postfix-policyd-spf-perl $BRANCH_POSTFIX_POLICYD_SPF_PERL" >> /VERSIONS && \
    echo "postfix $(postconf mail_version | cut -d '=' -f 2 | tr -d ' ')" >> /VERSIONS && \
    echo "$(postconf mail_version | cut -d '=' -f 2 | tr -d ' ')" >> /CONTAINER_VERSION && \
    # fail2ban-client --version >> /VERSIONS && \
    cat /VERSIONS

EXPOSE 25/tcp

ENTRYPOINT [ "/init" ]
