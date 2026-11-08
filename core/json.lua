-- JSON estrito, puro (testavel fora do FiveM). Limites de profundidade/tamanho contra entrada maliciosa.
local M = {}
M.null = setmetatable({}, { __tostring = function() return 'json.null' end })
local MAX_DEPTH, MAX_LEN = 32, 200000

local esc = { ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }

local function encode_str(s)
    return '"' .. s:gsub('[%c"\\]', function(c) return esc[c] or ('\\u%04x'):format(c:byte()) end) .. '"'
end

local function encode(v, depth)
    if depth > MAX_DEPTH then error('json: profundidade excedida') end
    local t = type(v)
    if v == nil or v == M.null then return 'null'
    elseif t == 'boolean' then return tostring(v)
    elseif t == 'number' then
        if v ~= v or v == math.huge or v == -math.huge then error('json: numero invalido') end
        if math.type(v) == 'integer' then return tostring(v) end
        return ('%.14g'):format(v)
    elseif t == 'string' then return encode_str(v)
    elseif t == 'table' then
        local n = #v
        if n > 0 or next(v) == nil then
            local out = {}
            for i = 1, n do out[i] = encode(v[i], depth + 1) end
            return '[' .. table.concat(out, ',') .. ']'
        end
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        local out = {}
        for _, k in ipairs(keys) do out[#out + 1] = encode_str(k) .. ':' .. encode(v[k] ~= nil and v[k] or v[tonumber(k)], depth + 1) end
        return '{' .. table.concat(out, ',') .. '}'
    end
    error('json: tipo nao suportado ' .. t)
end

function M.encode(v) return encode(v, 0) end

function M.decode(s)
    if type(s) ~= 'string' then return nil, 'not_string' end
    if #s > MAX_LEN then return nil, 'too_long' end
    local pos = 1
    local function ws() pos = s:find('[^ \t\r\n]', pos) or (#s + 1) end
    local value
    local function fail(msg) error({ json = msg .. '@' .. pos }, 0) end

    local function str()
        pos = pos + 1
        local buf = {}
        while true do
            local c = s:sub(pos, pos)
            if c == '' then fail('unterminated_string') end
            if c == '"' then pos = pos + 1; return table.concat(buf) end
            if c == '\\' then
                local n = s:sub(pos + 1, pos + 1)
                local map = { ['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b', f = '\f', n = '\n', r = '\r', t = '\t' }
                if map[n] then buf[#buf + 1] = map[n]; pos = pos + 2
                elseif n == 'u' then
                    local hex = s:match('^%x%x%x%x', pos + 2)
                    if not hex then fail('bad_unicode') end
                    local cp = tonumber(hex, 16)
                    pos = pos + 6
                    if cp >= 0xD800 and cp <= 0xDBFF then
                        local lo = s:match('^\\u(%x%x%x%x)', pos)
                        if not lo then fail('bad_surrogate') end
                        local l = tonumber(lo, 16)
                        if l < 0xDC00 or l > 0xDFFF then fail('bad_surrogate') end
                        cp = 0x10000 + (cp - 0xD800) * 0x400 + (l - 0xDC00)
                        pos = pos + 6
                    elseif cp >= 0xDC00 and cp <= 0xDFFF then fail('bad_surrogate') end
                    buf[#buf + 1] = utf8.char(cp)
                else fail('bad_escape') end
            elseif c:byte() < 32 then fail('control_char')
            else buf[#buf + 1] = c; pos = pos + 1 end
        end
    end

    function value(depth)
        if depth > MAX_DEPTH then fail('too_deep') end
        ws()
        local c = s:sub(pos, pos)
        if c == '{' then
            pos = pos + 1; local o = {}
            ws()
            if s:sub(pos, pos) == '}' then pos = pos + 1; return o end
            while true do
                ws()
                if s:sub(pos, pos) ~= '"' then fail('expected_key') end
                local k = str(); ws()
                if s:sub(pos, pos) ~= ':' then fail('expected_colon') end
                pos = pos + 1
                o[k] = value(depth + 1); ws()
                local d = s:sub(pos, pos); pos = pos + 1
                if d == '}' then return o elseif d ~= ',' then fail('expected_comma') end
            end
        elseif c == '[' then
            pos = pos + 1; local a = {}
            ws()
            if s:sub(pos, pos) == ']' then pos = pos + 1; return a end
            while true do
                a[#a + 1] = value(depth + 1); ws()
                local d = s:sub(pos, pos); pos = pos + 1
                if d == ']' then return a elseif d ~= ',' then fail('expected_comma') end
            end
        elseif c == '"' then return str()
        elseif s:find('^true', pos) then pos = pos + 4; return true
        elseif s:find('^false', pos) then pos = pos + 5; return false
        elseif s:find('^null', pos) then pos = pos + 4; return M.null
        else
            local num = s:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
            if not num or num == '' or num == '-' then fail('unexpected') end
            local n = tonumber(num)
            if not n then fail('bad_number') end
            pos = pos + #num
            return n
        end
    end

    local ok, res = pcall(function()
        local v = value(0); ws()
        if pos <= #s then fail('trailing') end
        return v
    end)
    if ok then return res end
    if type(res) == 'table' and res.json then return nil, res.json end
    return nil, 'decode_error'
end

return M
