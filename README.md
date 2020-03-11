# SUSE Manager Proxies as load balancers
# Basic description
The described configuration requires one extra host with Nginx installed. It could be registered as a minion in SUSE Manager.
There are two independant parts of implementation:
1. Load balancing of repositories access
2. Load balancing salt minions within the proxies
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
There are two separated upstream lists *suse-manager-squid* and *suse-manager-proxies*.
*suse-manager-squid* is managing the repositories data itself and do the trick with internal servers to handle redirects to exact internal proxy.
But *suse-manager-proxies* handles all other requests as a reverse proxy and handles the connections with the clients itself without redirecting.
*suse-manager-squid* requires additional modification on all of the proxies.

The following lines should be included in the squid.conf:
```
http_port 8081 accel defaultsite=smgr4-pxy1.demo.lab no-vhost ignore-cc allow-direct
https_port 8443 cert=/etc/apache2/ssl.crt/server.crt key=/etc/apache2/ssl.key/server.key accel defaultsite=smgr4-pxy1.demo.lab no-vhost ignore-cc allow-direct

...

http_access allow all
```

Port **8443** should be open of Nginx server for the managed systems.
Please note that squid will use SSL certificate and key from Apache configuration made during SUSE Manager Proxy configuration with **configure-proxy.sh**.
Nginx should be configured with SSL certificate and key generated for Nginx server. It could be done with **mgr-ssl-tool** or **rhn-ssl-tool**
and files should be placed to **/etc/nginx/ssl/server.crt** and **/etc/nginx/ssl/server.key** on Nginx server.

All the steps above are not affecting the managed systems and server, but please check the changes on SUSE Manager Proxies by refreshing repos with `zypper ref -f`.
