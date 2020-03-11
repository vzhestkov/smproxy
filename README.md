# SUSE Manager Proxies as load balancers
# Basic description
The described configuration requires one extra host with Nginx installed. It could be registered as a minion in SUSE Manager.
There are two independant parts of implementation:
1. [Load balancing of repositories access](#1-load-balancing-of-repositories-access)
2. [Load balancing salt minions within the proxies](#2-load-balancing-salt-minions-within-the-proxies)

These two parts are totally independant and could be implemented in any order and alone from the other one.

# 1. Load balancing of repositories access
Load balancing of repositories access is made with Nginx host. The sample configuration is the following:
**[/etc/nginx/conf.d/susemanager-proxy.conf](etc/nginx/conf.d/susemanager-proxy.conf)**:
```
upstream suse-manager-proxies {
  server smgr4-pxy1.demo.lab:443;
  server smgr4-pxy2.demo.lab:443;
}
server {
  listen 127.0.0.1:9001;
  location / {
    return 301 https://smgr4-pxy1.demo.lab:8443$request_uri;
  }
}
server {
  listen 127.0.0.1:9002;
  location / {
    return 301 https://smgr4-pxy2.demo.lab:8443$request_uri;
  }
}
upstream suse-manager-squid {
  server 127.0.0.1:9001;
  server 127.0.0.1:9002;
}
server {
  listen                80;
  listen                443 ssl;
  server_name           smgr4-nginx.demo.lab;
  ssl_certificate       /etc/nginx/ssl/server.crt;
  ssl_certificate_key   /etc/nginx/ssl/server.key;
  ssl_verify_client     off;
  location /rhn/manager/download/ {
    proxy_pass                http://suse-manager-squid;
    proxy_buffer_size         128k;
    proxy_buffers             4 256k;
    proxy_busy_buffers_size   256k;
  }
  location / {
    proxy_pass                https://suse-manager-proxies;
    proxy_buffer_size         128k;
    proxy_buffers             4 256k;
    proxy_busy_buffers_size   256k;
  }
}
```
There are two separated upstream lists **suse-manager-squid** and **suse-manager-proxies**.
**suse-manager-squid** is managing the repositories data itself and do the trick with internal servers to handle redirects to exact internal proxy.
But **suse-manager-proxies** handles all other requests as a reverse proxy and handles the connections with the clients itself without redirecting.
**suse-manager-squid** requires additional modification on all of the proxies.

The following lines should be included in the **[/etc/squid/squid.conf}(etc/squid/squid.conf)**:
```
http_port 8081 accel defaultsite=smgr4-pxy1.demo.lab no-vhost ignore-cc allow-direct
https_port 8443 cert=/etc/apache2/ssl.crt/server.crt key=/etc/apache2/ssl.key/server.key accel defaultsite=smgr4-pxy1.demo.lab no-vhost ignore-cc allow-direct

...

http_access allow all
```

Port **8443** should be open of Nginx server for the managed systems.
Please note that squid will use SSL certificate and key from Apache configuration made during SUSE Manager Proxy configuration with `configure-proxy.sh`.
Nginx should be configured with SSL certificate and key generated for Nginx server. It could be done with `mgr-ssl-tool` or `rhn-ssl-tool`
and files should be placed to **/etc/nginx/ssl/server.crt** and **/etc/nginx/ssl/server.key** on Nginx server.

All the steps above are not affecting the managed systems and server, but please check the changes on SUSE Manager Proxies by refreshing repos with `zypper ref -f`.

To switch all the minions to use Nginx server as a load balancer it's required to change **pkg_download_point_host** pillar value to the Nginx host name.
It could be done with **[/srv/pillar/top.sls](srv/pillar/top.sls)**:
```
base:
  '*':
    - pkg_download_points
```
and **[/srv/pillar/pkg_download_points.sls](srv/pillar/pkg_download_points.sls)**
```
pkg_download_point_host: smgr4-nginx.demo.lab
```
Please not that in this case download point will be changed for all of the minions. Probably you don't really need it.

Repositories configuratio on the minion can be updated with `salt MINION state.apply channels`.
But please check it the repos accessible with Nginx server first. For example you may check the repo assigned to any minion:
```
cat /etc/zypp/repos.d/susemanager\:channels.repo | grep baseurl
```
Choose any URL related to the proxy and replace the host name of the proxy with the host name of Nginx server. Also add `/repodata/repomd.xml` before the `?TOKEN`.
For example we can see something like the following:
```
baseurl=https://smgr4-pxy1.demo.lab:443/rhn/manager/download/sle-manager-tools15-pool-x86_64-sp1?eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MDc0OTUwNTUsImlhdCI6MTU3NTk1OTA1NSwibmJmIjoxNTc1OTU4OTM1LCJqdGkiOiItcFY3c2puV0NRVTl4ejVveFBhX2VnIiwib3JnIjoxLCJvbmx5Q2hhbm5lbHMiOlsic2xlLW1hbmFnZXItdG9vbHMxNS1wb29sLXg4Nl82NC1zcDEiXX0.H_LCIR6INZi6P_WMkcAozNEuHUmaZq3R0WZ3u2Y4trE
```
We need to get the URL part and modify it the following way:
```
https://smgr4-nginx.demo.lab:443/rhn/manager/download/sle-manager-tools15-pool-x86_64-sp1/repodata/repomd.xml?eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MDc0OTUwNTUsImlhdCI6MTU3NTk1OTA1NSwibmJmIjoxNTc1OTU4OTM1LCJqdGkiOiItcFY3c2puV0NRVTl4ejVveFBhX2VnIiwib3JnIjoxLCJvbmx5Q2hhbm5lbHMiOlsic2xlLW1hbmFnZXItdG9vbHMxNS1wb29sLXg4Nl82NC1zcDEiXX0.H_LCIR6INZi6P_WMkcAozNEuHUmaZq3R0WZ3u2Y4trE
```
And then use it with `curl -i URL` command. Replace the URL with the value you get as the resould of the modifications.
You sould get the redirect message to the particular proxy, like this:
```
HTTP/1.1 301 Moved Permanently
Server: nginx/1.14.2
Date: Wed, 11 Mar 2020 12:46:47 GMT
Content-Type: text/html
Content-Length: 185
Connection: keep-alive
Location: https://smgr4-pxy2.demo.lab:8443/rhn/manager/download/sle-manager-tools15-pool-x86_64-sp1/repodata/repomd.xml?https://smgr4-nginx.demo.lab:443/rhn/manager/download/sle-manager-tools15-pool-x86_64-sp1?eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MDc0OTUwNTUsImlhdCI6MTU3NTk1OTA1NSwibmJmIjoxNTc1OTU4OTM1LCJqdGkiOiItcFY3c2puV0NRVTl4ejVveFBhX2VnIiwib3JnIjoxLCJvbmx5Q2hhbm5lbHMiOlsic2xlLW1hbmFnZXItdG9vbHMxNS1wb29sLXg4Nl82NC1zcDEiXX0.H_LCIR6INZi6P_WMkcAozNEuHUmaZq3R0WZ3u2Y4trE

<html>
<head><title>301 Moved Permanently</title></head>
<body bgcolor="white">
<center><h1>301 Moved Permanently</h1></center>
<hr><center>nginx/1.14.2</center>
</body>
</html>
```
You may use URL from **Location** header value with `curl -i URL` and should get the content of **repomd.xml**:
```
HTTP/1.1 200 OK
Date: Wed, 11 Mar 2020 12:48:22 GMT
Server: Apache
X-Frame-Options: SAMEORIGIN
Content-Disposition: attachment; filename=repomd.xml
Content-Security-Policy: default-src 'self' https: wss: ; script-src 'self' https: 'unsafe-inline' 'unsafe-eval'; img-src 'self' https: data: ;style-src 'self' https: 'unsafe-inline'
X-XSS-Protection: 1; mode=block
X-Content-Type-Options: nosniff
X-Permitted-Cross-Domain-Policies: master-only
Last-Modified: Thu, 08 Aug 2019 10:25:54 GMT
Content-Length: 1346
X-Cache: MISS from smgr4-pxy1
X-Cache: HIT from smgr4-pxy1
X-Cache-Lookup: MISS from smgr4-pxy1:8080
X-Cache-Lookup: HIT from smgr4-pxy1:8080
ETag: "58f987b8a5ea0"
Age: 1
Content-Type: application/octet-stream
X-Cache: MISS from smgr4-pxy2
X-Cache-Lookup: MISS from smgr4-pxy2:8080
Via: 1.1 smgr4-pxy1 (squid/4.8), 1.1 smgr4-pxy1 (squid/4.10), 1.1 smgr4-pxy2 (squid/4.10)
Connection: keep-alive

<?xml version="1.0" encoding="UTF-8"?>
<repomd xmlns="http://linux.duke.edu/metadata/repo"><data type="primary"><location href="repodata/primary.xml.gz"/><checksum type="sha256">136ac211d4f3ff55781399ece458b4531151e4410c290f8f194f4f459236ce8a</checksum><open-checksum type="sha256">72b6a5f0b745c2a18091f97cb625b6d5e76d8a4964be3cb3b6bd8a5f55868e31</open-checksum><timestamp>1565259954</timestamp></data><data type="filelists"><location href="repodata/filelists.xml.gz"/><checksum type="sha256">a2b650c760cc6f8d02bcab0354c2a9f1777a10b4657c6b17a4c16fa085792179</checksum><open-checksum type="sha256">6e3ac26b04c973b572e7efaf6c8d1d3f14e535a363f64e61e29aa757a5fe6b62</open-checksum><timestamp>1565259954</timestamp></data><data type="other"><location href="repodata/other.xml.gz"/><checksum type="sha256">00c608b411f60afa38eb4590082e37716d0684c10edc1a9b1c386ffd8369eb91</checksum><open-checksum type="sha256">b004bd7241d2e7e92afbb6a28b6b527ecc03b3b9c16a06a567e7573c5e19eede</open-checksum><timestamp>1565259954</timestamp></data><data type="susedata"><location href="repodata/susedata.xml.gz"/><checksum type="sha256">57ae935d887a69ee8dc31f85162c2d4ebec085fa8306b9e4aaff55bc59581517</checksum><open-checksum type="sha256">e9a85ce71550b1d03cae7aa2380bfee73da0fc10af01e5d345e6bfef95b949a1</open-checksum><timestamp>1565259954</timestamp></data></repomd>
```

# 2. Load balancing salt minions within the proxies
**TBD**
