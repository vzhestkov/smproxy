check-not-proxy:
  cmd.run:
    - name: (! (rpm -q spacewalk-proxy-salt || systemctl is-enabled salt-broker.service)) > /dev/null 2>&1;

smproxycl-bin:
  file.managed:
    - name: /usr/local/bin/smproxycl
    - source: salt://smproxycl/files/usr/local/bin/smproxycl
    - mode: 0755
    - user: root
    - group: root
    - require:
      - cmd: check-not-proxy

smproxycl-sysconfig:
  file.managed:
    - name: /etc/sysconfig/smproxycl
    - source: salt://smproxycl/files/etc/sysconfig/smproxycl
    - mode: 0644
    - user: root
    - group: root
    - require:
      - file: smproxycl-bin

smproxycl-install:
  cmd.wait:
    - name: /usr/local/bin/smproxycl install
    - require:
      - file: smproxycl-bin
    - watch:
      - file: smproxycl-bin
      - file: smproxycl-sysconfig
