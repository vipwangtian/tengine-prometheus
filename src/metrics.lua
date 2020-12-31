local prometheus = require("prometheus")

local server_name = ngx.var.hostname
local switch_req_status = true
local function split(str, sep)
	local fields = {}
	str:gsub(string.format("[^%s]+", sep), function(c) fields[#fields+1] = c end)
	return fields
end

local function capture_stub_stat()
    local res = ngx.location.capture("/stub_status")
    if res.status == 200 then
        local prom = prometheus.init()
        local pattern = "Active connections: (%d*) \nserver accepts handled requests request_time\n (%d*) (%d*) (%d*) (%d*)\nReading: (%d*) Writing: (%d*) Waiting: (%d*) "
        local active_conns, accepts, handled, requests, request_time, reading, writing, waiting = string.match(res.body, pattern)
        local label = {server=server_name, module="stub_stat"}
        prom:gauge("stub_stat_active_conns", "Active connections"):label(label):set(active_conns)
        prom:gauge("stub_stat_accepts", "accepts"):label(label):set(accepts)
        prom:gauge("stub_stat_handled", "handled"):label(label):set(handled)
        prom:gauge("stub_stat_requests", "requests"):label(label):set(requests)
        prom:gauge("stub_stat_Reading", "Reading"):label(label):set(reading)
        prom:gauge("stub_stat_Writing", "Writing"):label(label):set(writing)
        prom:gauge("stub_stat_Waiting", "Waiting"):label(label):set(waiting)
        return prom:collect()
    else
        return nil, "capture nginx_status failed"
    end
end

local function capture_req_status()
    local res = ngx.location.capture("/req_status")
    if res.status == 200 then
        local prom = prometheus.init()
        local hosts = split(res.body, "\n")
        for hk,hv in ipairs(hosts) do
            local items = split(hv, ",")
            local label = {server=server_name, module="req_status", host=items[1]}
            prom:gauge("req_status_bytes_in", "bytes_in"):label(label):set(items[2])
            prom:gauge("req_status_bytes_out", "bytes_out"):label(label):set(items[3])
            prom:gauge("req_status_conn_total", "conn_total"):label(label):set(items[4])
            prom:gauge("req_status_req_total", "req_total"):label(label):set(items[5])
            prom:gauge("req_status_http_2xx", "http_2xx"):label(label):set(items[6])
            prom:gauge("req_status_http_3xx", "http_3xx"):label(label):set(items[7])
            prom:gauge("req_status_http_4xx", "http_4xx"):label(label):set(items[8])
            prom:gauge("req_status_http_5xx", "http_5xx"):label(label):set(items[9])
            prom:gauge("req_status_http_other_status", "http_other_status"):label(label):set(items[10])
            prom:gauge("req_status_rt", "rt"):label(label):set(items[11])
            prom:gauge("req_status_ups_req", "ups_req"):label(label):set(items[12])
            prom:gauge("req_status_ups_rt", "ups_rt"):label(label):set(items[13])
            prom:gauge("req_status_ups_tries", "ups_tries"):label(label):set(items[14])
            prom:gauge("req_status_http_200", "http_200"):label(label):set(items[15])
            prom:gauge("req_status_http_206", "http_206"):label(label):set(items[16])
            prom:gauge("req_status_http_302", "http_302"):label(label):set(items[17])
            prom:gauge("req_status_http_304", "http_304"):label(label):set(items[18])
            prom:gauge("req_status_http_403", "http_403"):label(label):set(items[19])
            prom:gauge("req_status_http_404", "http_404"):label(label):set(items[20])
            prom:gauge("req_status_http_416", "http_416"):label(label):set(items[21])
            prom:gauge("req_status_http_499", "http_499"):label(label):set(items[22])
            prom:gauge("req_status_http_500", "http_500"):label(label):set(items[23])
            prom:gauge("req_status_http_502", "http_502"):label(label):set(items[24])
            prom:gauge("req_status_http_503", "http_503"):label(label):set(items[25])
            prom:gauge("req_status_http_504", "http_504"):label(label):set(items[26])
            prom:gauge("req_status_http_508", "http_508"):label(label):set(items[27])
            prom:gauge("req_status_http_other_detail_status", "http_other_detail_status"):label(label):set(items[27])
            prom:gauge("req_status_http_ups_4xx", "http_ups_4xx"):label(label):set(items[28])
            prom:gauge("req_status_http_ups_5xx", "http_ups_5xx"):label(label):set(items[29])
        end
        return prom:collect()
    else
        return nil, "capture req_status failed"
    end
end

local code = ngx.OK
local result_body = ""
local stub_stat, err = capture_stub_stat()
if err then
    code = ngx.HTTP_INTERNAL_SERVER_ERROR
    ngx.log(ngx.ERR, err)
else
    result_body = table.concat(stub_stat)
end

if switch_req_status then
    local req_status, err1 = capture_req_status()
    if err1 then
        code = ngx.HTTP_INTERNAL_SERVER_ERROR
        ngx.log(ngx.ERR, err1)
    else
        result_body = result_body .. table.concat(req_status)
    end
end

if code == ngx.OK then
    ngx.header["Content-Type"] = "text/plan; charset=utf-8"
    ngx.print(result_body)
    return
else
    ngx.exit(code)
end