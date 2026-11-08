-- Dispatch (R07.3): NAO ha dispatch universal. O administrador escolhe o modo conforme o recurso REAL instalado.
--   none   : so registra no log (padrao)
--   export : exports[resource][export](alert)    -> alert = { coords, code, message, src, zone }
--   event  : TriggerEvent(event, alert)          (evento de SERVIDOR)
-- Adapte o payload ao recurso escolhido (ps-dispatch, cd_dispatch, etc.): ver INTEGRACAO_QBOX.md.
local D = {}

function D.send(cfg, alert, log)
    local c = cfg.dispatch
    if c.mode == 'export' then
        if GetResourceState(c.resource) ~= 'started' then log('warn', 'dispatch: recurso nao iniciado', { resource = c.resource }); return false end
        local ok, err = pcall(function() exports[c.resource][c.export](exports[c.resource], alert) end)
        if not ok then log('warn', 'dispatch: export falhou', { err = tostring(err) }) end
        return ok
    elseif c.mode == 'event' then
        TriggerEvent(c.event, alert)
        return true
    end
    log('info', 'denuncia sem dispatch configurado', { zone = alert.zone })
    return false
end

return D
