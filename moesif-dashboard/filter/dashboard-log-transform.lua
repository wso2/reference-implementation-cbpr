-- Remove leading and trailing quotes from a string
local function strip_quotes(s)
    if type(s) == "string" then
        return s:gsub('^"(.*)"$', '%1')
    end
    return s
end

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

function enc(data)
    return ((data:gsub('.', function(x)
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

local function detectXml(message)
    if not message or message == "" then
        return false
    end
    local msg = tostring(message)
    -- Pattern 1: Starts with < and contains >
    if msg:match("^%s*<[%s%S]*>") then
        return true
    end
    -- Pattern 2: Contains XML declaration
    if msg:find("<?xml", 1, true) then
        return true
    end
    -- Pattern 3: Contains SOAP Envelope
    if msg:find("<Envelope", 1, true) then
        return true
    end
    -- Pattern 4: Contains ISO 20022 Document
    if msg:find("<Document", 1, true) then
        return true
    end
    -- Pattern 5: Simple check - starts with <
    if msg:match("^%s*<") then
        return true
    end
    return false
end

local function getContentType(message)
    if detectXml(message) then
        return "application/xml"
    else
        return "text/plain"
    end
end

function moesif_transform(tag, timestamp, record)
    -- 1. Extract Raw Values
    local fileId = record["id"] or ""
    local refId = record["refId"] or ""
    local user_id = "UNKNOWN"
    if refId ~= "" then user_id = refId elseif fileId ~= "" then user_id = fileId end

    local mtType = record["mtMessageType"] or ""
    local mxType = record["mxMessageType"] or ""
    local currency = record["currency"] or ""
    local amount = tonumber(record["amount"]) or 0
    local direction = record["direction"] or ""
    local status = record["status"] or "unknown"
    local log_date = record["date"] or os.date("!%Y-%m-%dT%H:%M:%SZ", timestamp)

    local originalMsg = record["originalMessage"] or ""
    local translatedMsg = record["translatedMessage"] or "N/A"
    -- Remove extra quotes from translatedMsg if present
    translatedMsg = strip_quotes(translatedMsg)

    -- 2. Normalize Status
    local statusNorm = string.lower(status)
    local httpStatus = 400
    if statusNorm == "successful" then
        httpStatus = 200
    elseif statusNorm == "skipped" then
        httpStatus = 202
    end

    -- 3. Detect Message Content and Get Content-Type
    local reqContentType = getContentType(originalMsg)
    local resContentType = getContentType(translatedMsg)
    local reqEncoding = "base64"
    local resEncoding = "base64"

    -- 4. Encode Messages
    local reqBody = enc(originalMsg)
    local resBody = enc(translatedMsg)

    -- 5. Construct Metadata
    local metadata = {
        event_kind = "dashboard_log",
        source_file = fileId,
        date = log_date,
        transaction_id = refId,
        mt_type = mtType,
        mx_type = mxType,
        currency = currency,
        amount = amount,
        direction = direction,
        status_text = statusNorm,
        field_error = record["fieldError"] or "",
        not_supported_error = record["notSupportedError"] or "",
        invalid_error = record["invalidError"] or "",
        other_error = record["otherError"] or ""
    }

    -- 6. Build Final Moesif Record
    local moesif_record = {
        request = {
            time = log_date,
            uri = "/swift-translation",
            verb = "POST",
            headers = {
                ["Content-Type"] = reqContentType
            },
            body = reqBody,
            transfer_encoding = reqEncoding
        },
        response = {
            time = log_date,
            status = httpStatus,
            headers = {
                ["Content-Type"] = resContentType
            },
            body = resBody,
            transfer_encoding = resEncoding
        },
        user_id = user_id,
        metadata = metadata
    }

    -- Return: Code 2 (Replace Record), Timestamp, New Record
    return 2, timestamp, moesif_record
end