smproxycl-bin:
  file.absent:
    - name: /usr/local/bin/smproxycl

smproxycl-sysconfig:
  file.absent:
    - name: /etc/sysconfig/smproxycl

smproxycl-remove:
  cmd.run:
    - name: rm -rf /etc/systemd/system/salt-minion.service ; systemctl reenable salt-minion.service
    - onlyif:
      - test -f /etc/systemd/system/salt-minion.service
    - onchanges:
      - file: smproxycl-bin
      - file: smproxycl-sysconfig
