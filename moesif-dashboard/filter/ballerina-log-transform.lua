function ballerina_transform(tag, timestamp, record)
    -- Extract fields from Ballerina log record
    local time = record["time"] or os.date("!%Y-%m-%dT%H:%M:%S.000Z")
    local level = record["level"] or "INFO"
    local module = record["module"] or "unknown"
    local message = record["message"] or ""

    -- Extract listener name from module
    local listenerName = extractListenerName(module)

    -- Build metadata object with Ballerina-specific fields
    local metadata = {
        event_kind = "ballerina_log",
        log_level = level,
        module = module,
        listener_name = listenerName,
        log_message = message,
        timestamp = time
    }

    -- Build Moesif event for Ballerina log
    local moesif_record = {
        timestamp = time,
        request = {
            time = time,
            uri = "/ballerina/logs",
            verb = "LOG",
            headers = {
                ["Content-Type"] = "text/plain"
            },
            body = ""
        },
        response = {
            time = time,
            status = 200,
            headers = {},
            body = {}
        },
        metadata = metadata
    }

    -- Return: code 2 (modify record), timestamp, moesif_record
    return 2, timestamp, moesif_record
end

-- Extract listener name from module string
function extractListenerName(module)
    if module == nil or module == "" then
        return "Unknown"
    end

    -- If it contains "Listener", return as-is
    if string.find(module, "Listener") then
        return module
    end

    -- Otherwise return module name
    return module
end