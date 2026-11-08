-- Copie as ENTRADAS abaixo para dentro da tabela retornada por data/items.lua do ox_inventory
-- (os nomes devem coincidir com config.goods). Arquivo valido em Lua para evitar erro de sintaxe.
return {
    ['streetdeal_pacote'] = {
        label = 'Pacote StreetDeals',
        weight = 500,
        stack = true,
        close = true,
        description = 'Pacote com 5 unidades (item ficticio de RP).',
    },
    ['streetdeal_unidade'] = {
        label = 'Unidade StreetDeals',
        weight = 100,
        stack = true,
        close = true,
        description = 'Unidade avulsa (item ficticio de RP). Usada apenas se goods[].mode = "units".',
    },
}
