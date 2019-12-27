{%- set sw_proxy_version = salt['pkg.version']('spacewalk-proxy-salt') %}
{%- set broker_enabled = salt['service.enabled']('salt-broker.service') %}
{%- if sw_proxy_version == {} and not broker_enabled %}
smproxycl-bin:
  file.managed:
    - name: /usr/local/bin/smproxycl
    - source: salt://smproxycl/files/usr/local/bin/smproxycl
    - mode: 0755
    - user: root
    - group: root

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
{%- else %}
smproxycl can't be installed on SUSE Manager proxy server:
  test.succeed_without_changes
{%- endif %}
