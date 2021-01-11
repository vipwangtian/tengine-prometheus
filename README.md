# Prometheus metric module for [Tengine](http://tengine.taobao.org/)
This is a lua module expose prometheus metrics api via subrequest instead of c library.

* 100% compatibility with nginx
* support [ngx_http_stub_status_module](http://nginx.org/en/docs/http/ngx_http_stub_status_module.html) and [ngx_http_reqstat_module metrics](http://tengine.taobao.org/document/http_reqstat.html)
* lua only do not need recompile
* no effects on performance
* only implement gauge item for above modules

## requirements
* [lua-nginx-module](https://github.com/openresty/lua-nginx-module)
* ensure configure [ngx_http_stub_status_module](http://nginx.org/en/docs/http/ngx_http_stub_status_module.html) and [ngx_http_reqstat_module](http://tengine.taobao.org/document/http_reqstat.html) correctly

## configuration sample
```text
# set search paths for pure Lua external libraries (';;' is the default path):
lua_package_path '/path/to/prometheus-tengine/?.lua;;';

# set a specific config block for prometheus
http{
    ...
    req_status_zone server "$host" 10M;
    req_status_zone_add_indicator server $host;
    req_status_zone_recycle server 10 60;
    server {
        listen 80 default_server;
        access_log off;

        location = /stub_status {
            stub_status;
        }

        location /req_status {
            req_status_show;
            req_status_show_field bytes_in bytes_out conn_total req_total http_2xx http_3xx http_4xx http_5xx http_other_status rt ups_req ups_rt ups_tries http_200 http_206 http_302 http_304 http_403 http_404 http_416 http_499 http_500 http_502 http_503 http_504 http_508 http_other_detail_status http_ups_4xx http_ups_5xx;
        }

        location /metrics {
            content_by_lua_file "/path/to/prometheus-tengine/metrics.lua";
        }

    }
}

```