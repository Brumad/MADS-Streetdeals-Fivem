-- Store duravel do ledger em oxmysql (INSERT atomico por registro). Falhas retornam (nil, erro):
-- o ledger entao NAO executa a acao externa correspondente.
local json = require 'core.json'
local S = {}
S.__index = S

local DDL = [[
CREATE TABLE IF NOT EXISTS `mads_sd_journal` (
  `rid` BIGINT NOT NULL AUTO_INCREMENT,
  `tx_id` VARCHAR(96) NOT NULL,
  `seq` BIGINT NOT NULL,
  `state` VARCHAR(24) NOT NULL,
  `ts` BIGINT NOT NULL,
  `data` MEDIUMTEXT NULL,
  `note` VARCHAR(160) NULL,
  `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`rid`),
  KEY `idx_tx` (`tx_id`),
  KEY `idx_created` (`created`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]]

function S.new() return setmetatable({}, S) end

function S:init()
    local ok, err = pcall(function() MySQL.query.await(DDL) end)
    if not ok then return nil, 'ddl_failed:' .. tostring(err) end
    return true
end

function S:append(rec)
    local data = rec.data and json.encode(rec.data) or nil
    local ok, id = pcall(function()
        return MySQL.insert.await(
            'INSERT INTO mads_sd_journal (tx_id, seq, state, ts, data, note) VALUES (?, ?, ?, ?, ?, ?)',
            { rec.id, rec.seq, rec.state, rec.ts, data, rec.note })
    end)
    if not ok or not id then return nil, 'insert_failed' end
    return true
end

-- Carrega todas as transacoes com atividade nos ultimos 60 dias (registros completos de cada uma).
function S:load()
    local ok, rows = pcall(function()
        return MySQL.query.await([[SELECT j.tx_id, j.seq, j.state, j.ts, j.data, j.note FROM mads_sd_journal j
            JOIN (SELECT DISTINCT tx_id FROM mads_sd_journal WHERE created > (NOW() - INTERVAL 60 DAY)) r
            ON r.tx_id = j.tx_id ORDER BY j.rid]])
    end)
    if not ok or type(rows) ~= 'table' then return nil, 'query_failed' end
    local out = {}
    for _, r in ipairs(rows) do
        local data
        if r.data then
            data = json.decode(r.data)
            if type(data) ~= 'table' then return nil, 'corrupt_row' end
        end
        out[#out + 1] = { id = r.tx_id, seq = r.seq, state = r.state, ts = r.ts, data = data, note = r.note }
    end
    return out
end

return S
