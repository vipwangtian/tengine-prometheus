local Prometheus = {}
local mt = { __index = Prometheus }

local TYPE_COUNTER    = 0x1
local TYPE_GAUGE      = 0x2
local TYPE_HISTOGRAM  = 0x4
local TYPE_LITERAL = {
  [TYPE_COUNTER]   = "counter",
  [TYPE_GAUGE]     = "gauge",
  [TYPE_HISTOGRAM] = "histogram",
}

local function check_metric_and_label_names(metric_name, labels)
    if not metric_name:match("^[a-zA-Z_:][a-zA-Z0-9_:]*$") then
      return "Metric name '" .. metric_name .. "' is invalid"
    end
    local label_names = {}
    for k, _ in pairs(labels) do
        table.insert(label_names, k)
    end
    for _, label_name in ipairs(label_names) do
      if label_name == "le" then
        return "Invalid label name 'le' in " .. metric_name
      end
      if not label_name:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
        return "Metric '" .. metric_name .. "' label name '" .. label_name ..
               "' is invalid"
      end
    end
end

local function set(self, value)
    self.value = value
    return self
end

local function label(self, label_values)
    local label_count = 0
    for _,_ in pairs(label_values) do
        label_count = label_count + 1
    end
    if label_count > 0 then
        self.label_count = label_count
        self.label_values = label_values
    end
    return self
end

function Prometheus.init()
    local self = setmetatable({}, mt)
    self.registry = {}
    return self
end

function Prometheus:gauge(name, help)
    local metric = {
        name = name,
        typ = TYPE_GAUGE,
        help = help,
        label = label,
        label_count = 0,
        value = 0,
        label_values = {},
        set = set
    }
    -- self.registry[name] = metric
    table.insert(self.registry, metric)
    return metric
end

function Prometheus:collect()
    local output = {}
    for _,v in pairs(self.registry) do
        local err = check_metric_and_label_names(v["name"], v["label_values"])
        if err then
            return nil, err
        end
        table.insert(output, string.format("# TYPE %s %s\n", v["name"], TYPE_LITERAL[v["typ"]]))
        table.insert(output, string.format("# HELP %s %s\n", v["name"], v["help"]))
        local label_str = ""
        if v["label_count"] > 0 then
            label_str = label_str .. "{"
            local pos = 0
            for lk,lv in pairs(v["label_values"]) do
                pos = pos + 1
                label_str = label_str .. lk .. string.format("=\"%s\"", lv)
                if pos < v["label_count"] then
                    label_str = label_str .. ","
                end
            end
            label_str = label_str .. "}"
        end
        table.insert(output, string.format("%s%s %d\n", v["name"], label_str, v["value"]))
    end
    return output
end

return Prometheus