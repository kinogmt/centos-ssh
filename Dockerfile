FROM rockylinux:8.7.20221219

##########################################################################
# all yum installations here
# note: "screen", "ntp" and "pax" used to be installed for CentOS 7.
#       Those are not available on yum repository of Rocky 8.
#       "screen" will be installed below using EPEL for Rocky 8 below.
RUN yum install -y sudo passwd openssh-server openssh-clients tar crontabs strace telnet perl libpcap bc patch dnsmasq unzip which less \
                   rng-tools initscripts bind-utils net-tools libselinux-utils \
                   openssl


##########################################################################
# enable services
RUN systemctl enable dnsmasq sshd crond

##########################################################################
# add epel repository
RUN yum install -y epel-release

RUN yum install -y screen

RUN yum install -y ngrep lsyncd sshpass

# --- new packages for rocky ---
RUN yum install -y glibc-langpack-en cups-libs

# start sshd to generate host keys, patch sshd_config and enable yum repos
RUN (mkdir -p /var/run/sshd; \
     yes|ssh-keygen -f /etc/ssh/ssh_host_rsa_key -t rsa -N ''; \
     yes|ssh-keygen -f /etc/ssh/ssh_host_ecdsa_key -t ecdsa -N ''; \
     yes|ssh-keygen -f /etc/ssh/ssh_host_ed25519_key -t ed25519 -N ''; \
     sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config; \
     sed -i 's/enabled=0/enabled=1/' /etc/yum.repos.d/Rocky-BaseOS.repo)

RUN (mkdir -p /root/.ssh/; \
     rm -f /var/lib/rpm/.rpm.lock; \
     echo "StrictHostKeyChecking=no" > /root/.ssh/config; \
     echo "UserKnownHostsFile=/dev/null" >> /root/.ssh/config)

# --- workaround for agetty high cpu ---
RUN systemctl mask system-getty.slice; \
        systemctl mask getty.target; \
        systemctl mask serial-getty@ttyS0.service; \
        systemctl mask getty@tty1.service

# terminfo for screen.xterm-256color
ADD screen.xterm-256color /root/
RUN tic /root/screen.xterm-256color

##########################################################################
# passwords 
RUN echo "root:password" | chpasswd

##########################################################################
# Add following RPMs for 8.0 package.
# Those packages are not available anymore on the thirdparty repo.
# They are alrady added to 8.0.1 cloudianpkg but not to 8.0 cloudianpkg, which has been already relased. 
# So we need them to run the 8.0EA(RC9) installer(for example, to test 8.0.0.1 patches).
# --- install prereq first ---
RUN yum install -y  ebtables ipset python3-decorator python3-gobject-base python3-nftables python3-slip-dbus
# --- insall selinux-policy here to avoid enabling selinux-policy-mls later while running the cloudian pkg
RUN yum install -y  selinux-policy
# --- install firewall rpms ---
ADD rpm/firewalld-0.9.3-13.el8.noarch.rpm /root/
ADD rpm/firewalld-filesystem-0.9.3-13.el8.noarch.rpm /root/
ADD rpm/python3-firewall-0.9.3-13.el8.noarch.rpm /root/

RUN rpm -Uvh /root/firewalld-0.9.3-13.el8.noarch.rpm /root/firewalld-filesystem-0.9.3-13.el8.noarch.rpm /root/python3-firewall-0.9.3-13.el8.noarch.rpm

EXPOSE 22
CMD ["/sbin/init"]
