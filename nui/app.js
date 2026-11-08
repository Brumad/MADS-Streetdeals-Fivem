/* MADS StreetDeals - NUI. Toda decisao/valor final vem do servidor; aqui so ha apresentacao e intencoes. */
(() => {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const S = { open: false, view: null, step: 0, qty: 1, goods: null, busy: false, over: false, ttlTimer: null, closeTimer: null, errTimer: null };
  const OUTCOME_TEXT = {
    refuse: ['O comprador recusou e foi embora.', 'bad'],
    refuse_report: ['O comprador recusou e ameaçou chamar a polícia!', 'bad'],
    fight: ['O comprador partiu pra cima de você!', 'bad'],
    walked: ['O comprador foi embora.', 'bad'],
  };

  const money = (n) => '$' + Number(n || 0).toLocaleString('pt-BR');
  const timeoutMs = () => (typeof window.MADS_TIMEOUT_MS === 'number' ? window.MADS_TIMEOUT_MS : 10000);

  // Transporte: FiveM (fetch para o resource) ou substituido em testes via window.__MADS_TRANSPORT__.
  function transport(name, data) {
    if (typeof window.__MADS_TRANSPORT__ === 'function') return window.__MADS_TRANSPORT__(name, data);
    const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mads_streetdeals';
    return fetch(`https://${res}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data || {}) })
      .then((r) => r.json());
  }
  // Sempre resolve ou rejeita em ate timeoutMs: a UI nunca fica presa.
  function post(name, data) {
    let t;
    const timer = new Promise((_, rej) => { t = setTimeout(() => rej(new Error('timeout')), timeoutMs()); });
    return Promise.race([Promise.resolve().then(() => transport(name, data)), timer]).finally(() => clearTimeout(t));
  }

  // ---- calculo SOMENTE de exibicao (o servidor recalcula tudo) ----
  function goodsInfo() { return (S.view.goods || []).find((g) => g.key === S.goods) || (S.view.goods || [])[0] || { stock: 0, priceMult: 1 }; }
  function unitFor(step) {
    const v = S.view; const g = goodsInfo();
    const ref = Math.floor(v.refPrice * (g.priceMult || 1) + 0.5);
    const rt = v.roundTo || 10;
    return Math.max(1, Math.floor((ref * (1 + (step * v.scroll.stepPct) / 100)) / rt + 0.5) * rt);
  }
  function maxQty() { return Math.max(1, Math.min(S.view.maxQty || 1, goodsInfo().stock || 0)); }

  // ---- renderizacao ----
  function setBusy(b) { S.busy = b; render(); }
  function showError(msg) {
    $('errorText').textContent = msg; $('error').classList.remove('hidden');
    clearTimeout(S.errTimer); S.errTimer = setTimeout(() => $('error').classList.add('hidden'), 7000);
  }
  function chat() {
    const el = $('chat'); const near = el.scrollHeight - el.scrollTop - el.clientHeight < 80;
    el.textContent = '';
    for (const m of S.view.messages || []) {
      const d = document.createElement('div'); d.className = 'msg ' + (m.who === 'player' ? 'player' : 'npc');
      d.appendChild(document.createTextNode(String(m.text))); // textContent: sem injecao de HTML
      if (m.who === 'npc' && m.source) { const s = document.createElement('span'); s.className = 'src'; s.textContent = m.source === 'ai' ? 'IA' : 'local'; d.appendChild(s); }
      el.appendChild(d);
    }
    if (near || el.childElementCount <= 2) el.scrollTop = el.scrollHeight;
  }
  function render() {
    if (!S.view) return;
    const v = S.view; const mode = v.mode;
    const locked = S.busy || S.over;
    $('buyerName').textContent = (v.npc && v.npc.archetype) || 'Comprador';
    const mood = (v.npc && v.npc.mood) || 'neutro';
    const mb = $('moodBadge'); mb.textContent = mood; mb.className = 'badge mood-' + mood;
    const modeTxt = { simple: 'negociação', combo: 'combo', rare: 'oferta especial' }[mode] || '';
    $('modeBadge').textContent = modeTxt; $('modeBadge').classList.toggle('hidden', !modeTxt);
    const last = [...(v.messages || [])].reverse().find((m) => m.who === 'npc');
    const ai = $('aiBadge'); const isAi = !!(last && last.source === 'ai');
    ai.textContent = isAi ? 'IA' : 'local'; ai.className = 'badge ' + (isAi ? 'ai' : 'ghost');
    ai.title = isAi ? 'Fala gerada por IA externa' : 'Fala do motor local (IA indisponível ou desativada)';
    $('ttl').textContent = v.ttl > 0 ? v.ttl + 's' : '--'; $('ttl').classList.toggle('low', v.ttl > 0 && v.ttl <= 15);

    const rare = mode === 'rare';
    const price = $('priceCard'); price.classList.toggle('hidden', rare);
    $('qtyCard').classList.toggle('hidden', rare || (v.maxQty || 1) <= 1);
    $('goodsCard').classList.toggle('hidden', (v.goods || []).length <= 1);
    $('btnOffer').classList.toggle('hidden', rare || !!v.deal);
    if (!rare) {
      const unit = unitFor(S.step);
      $('unitPrice').textContent = money(unit);
      const pct = S.step * v.scroll.stepPct;
      const pe = $('pct'); pe.textContent = pct === 0 ? 'na referência' : (pct > 0 ? '+' : '') + pct + '% da referência';
      pe.className = 'pct ' + (pct < 0 ? 'down' : pct > 0 ? 'up' : '');
      $('hint').textContent = pct < 0 ? 'Desconto: mais chance de aceitar, menor risco de denúncia'
        : pct > 0 ? 'Sobrepreço: mais difícil de aceitar, maior risco de denúncia' : 'Role o mouse para ajustar a oferta';
      $('refPrice').textContent = money(v.refPrice);
      const mq = maxQty(); if (S.qty > mq) S.qty = mq; if (S.qty < 1) S.qty = 1;
      $('qty').textContent = S.qty; $('maxQty').textContent = v.maxQty || 1; $('stock').textContent = goodsInfo().stock || 0;
      $('total').textContent = money(unit * S.qty);
    }
    const gs = $('goodsSel');
    if (gs.options.length !== (v.goods || []).length) {
      gs.textContent = '';
      for (const g of v.goods || []) { const o = document.createElement('option'); o.value = g.key; o.textContent = `${g.label} (${g.stock})`; gs.appendChild(o); }
    }
    gs.value = S.goods;

    const cb = $('counterBox'); cb.classList.toggle('hidden', !v.counter || !!v.deal);
    if (v.counter) $('counterText').textContent = `${money(v.counter.unitPrice)} por pacote`;
    const db = $('dealBox'); db.classList.toggle('hidden', !v.deal);
    if (v.deal) {
      $('dealLabel').textContent = v.deal.rare || rare ? 'Oferta especial' : 'Acordo fechado';
      $('dealText').textContent = `${v.deal.qty}× ${money(v.deal.unitPrice)} = ${money(v.deal.total)}`;
    }
    chat();

    for (const id of ['btnOffer', 'btnSend', 'btnMinus', 'btnPlus', 'qMinus', 'qPlus', 'btnConfirm', 'btnCounter', 'goodsSel', 'chatInput']) $(id).disabled = locked;
    $('btnClose').disabled = false; // cancelar sempre disponivel
    $('qMinus').disabled = locked || S.qty <= 1; $('qPlus').disabled = locked || S.qty >= maxQty();
    $('btnMinus').disabled = locked || S.step <= v.scroll.lo; $('btnPlus').disabled = locked || S.step >= v.scroll.hi;
    $('loading').classList.toggle('hidden', !S.busy);
    $('typing').classList.toggle('hidden', !S.busy);
  }

  function changeStep(d) {
    if (!S.view || S.busy || S.over || S.view.mode === 'rare') return;
    S.step = Math.max(S.view.scroll.lo, Math.min(S.view.scroll.hi, S.step + d)); render();
  }

  // ---- ciclo de vida ----
  function startTtl() {
    clearInterval(S.ttlTimer);
    S.ttlTimer = setInterval(() => {
      if (!S.view || S.over) return;
      S.view.ttl = Math.max(0, (S.view.ttl || 0) - 1); render();
      if (S.view.ttl === 0) finish('A negociação expirou.', 'bad');
    }, 1000);
  }
  function hide() {
    clearInterval(S.ttlTimer); clearTimeout(S.closeTimer); clearTimeout(S.errTimer);
    S.open = false; S.view = null; S.over = false; S.busy = false;
    $('app').classList.add('hidden'); $('result').classList.add('hidden'); $('error').classList.add('hidden');
  }
  function open(view) {
    hide();
    S.view = view; S.open = true; S.step = 0; S.qty = 1;
    const g = (view.goods || []).find((x) => x.stock > 0) || (view.goods || [])[0]; S.goods = g ? g.key : null;
    $('app').classList.remove('hidden'); $('chatInput').value = '';
    render(); startTtl();
    if (view.state === 'terminal') return finishOutcome(view.outcome);
    setTimeout(() => $('chatInput').focus(), 30);
  }
  function finish(text, kind) {
    S.over = true; const r = $('result'); r.textContent = text; r.className = 'result ' + (kind || '');
    render();
    clearTimeout(S.closeTimer);
    S.closeTimer = setTimeout(() => { hide(); post('close', {}).catch(() => {}); }, 2400);
  }
  function finishOutcome(outcome, res) {
    if (outcome === 'sold') return finish(`Venda concluída: ${money(res && res.total)}`, 'good');
    const t = OUTCOME_TEXT[outcome];
    return finish(t ? t[0] : ((res && res.message) || 'Negociação encerrada.'), t ? t[1] : 'bad');
  }
  function cancel() {
    if (!S.open) return;
    clearTimeout(S.closeTimer);
    hide(); // fecha NA HORA (nunca espera o servidor); o client libera o foco ao receber 'close'
    post('close', {}).catch(() => post('close', {}).catch(() => {})); // 1 nova tentativa se falhar
  }

  function apply(res, kind) {
    if (!res || typeof res !== 'object') { showError('Resposta inválida do servidor.'); return; }
    if (res.ok === false) {
      showError(res.message || 'Não foi possível concluir a ação.');
      if (res.closed) return finishOutcome(res.outcome, res);
      return;
    }
    if (res.messages) {
      const keep = { step: S.step, qty: S.qty, goods: S.goods };
      S.view = Object.assign({}, S.view, res); S.step = keep.step; S.qty = keep.qty; S.goods = keep.goods;
    }
    if (res.closed || res.outcome === 'sold') return finishOutcome(res.outcome, res);
    if (res.state === 'terminal') { render(); return finishOutcome(res.outcome, res); }
    render();
  }

  async function send(kind, extra) {
    if (S.busy || S.over || !S.open) return;
    setBusy(true);
    try {
      const res = await post('act', Object.assign({ kind }, extra || {}));
      apply(res, kind);
    } catch (e) {
      showError(e && e.message === 'timeout' ? 'O servidor demorou a responder. Tente novamente.' : 'Falha de comunicação. Tente novamente.');
    } finally {
      if (S.open) { S.busy = false; render(); if (kind === 'say' && !S.over) $('chatInput').focus(); }
    }
  }

  // ---- eventos ----
  window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'open' && d.data) open(d.data); else if (d.action === 'close') hide();
  });
  $('priceCard').addEventListener('wheel', (e) => { e.preventDefault(); changeStep(e.deltaY < 0 ? 1 : -1); }, { passive: false });
  $('panel').addEventListener('wheel', (e) => { if (e.target.closest('#priceCard')) return; if (e.target.closest('#qtyCard')) { e.preventDefault(); stepQty(e.deltaY < 0 ? 1 : -1); } }, { passive: false });
  function stepQty(d) { if (S.busy || S.over || !S.view) return; S.qty = Math.max(1, Math.min(maxQty(), S.qty + d)); render(); }
  $('btnMinus').onclick = () => changeStep(-1); $('btnPlus').onclick = () => changeStep(1);
  $('qMinus').onclick = () => stepQty(-1); $('qPlus').onclick = () => stepQty(1);
  $('goodsSel').onchange = (e) => { S.goods = e.target.value; render(); };
  $('btnOffer').onclick = () => send('offer', { step: S.step, qty: S.qty, goods: S.goods });
  $('btnCounter').onclick = () => send('accept_counter');
  $('btnConfirm').onclick = () => send('confirm');
  $('btnClose').onclick = cancel;
  $('errorX').onclick = () => $('error').classList.add('hidden');
  $('chatForm').addEventListener('submit', (e) => {
    e.preventDefault();
    const t = $('chatInput').value.trim();
    if (!t || S.busy || S.over) return;
    $('chatInput').value = '';
    S.view.messages = (S.view.messages || []).concat([{ who: 'player', text: t }]); // eco local; o servidor reenvia o historico oficial
    send('say', { text: t });
  });
  document.addEventListener('keydown', (e) => {
    if (!S.open) return;
    if (e.key === 'Escape') { e.preventDefault(); return cancel(); }
    const tag = (e.target && e.target.tagName) || '';
    if (tag === 'SELECT') return;
    if (tag === 'INPUT' && !e.ctrlKey) return; // digitando: setas so com Ctrl
    if (e.key === 'ArrowUp') { e.preventDefault(); changeStep(1); } else if (e.key === 'ArrowDown') { e.preventDefault(); changeStep(-1); }
    else if (e.key === 'ArrowRight') stepQty(1); else if (e.key === 'ArrowLeft') stepQty(-1);
  });

  window.MadsNui = { open, hide, state: () => S };
})();
