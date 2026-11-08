// Testes da NUI em Chromium REAL (Playwright). Nao testa FiveM/CEF: so HTML/CSS/JS da interface.
// Uso: node tests/nui/run.js
const path = require('path');
const { chromium } = require('playwright');
const URL = 'file://' + path.resolve(__dirname, '../../nui/index.html');

const baseView = () => ({
  ok: true, sessionId: 's1', state: 'negotiating', mode: 'combo', npc: { archetype: 'Empresario', mood: 'neutro' },
  scroll: { lo: -10, hi: 10, stepPct: 5 }, refPrice: 2000, roundTo: 10, maxQty: 3,
  goods: [{ key: 'pacote_rua', label: 'Pacote StreetDeals', stock: 5, priceMult: 1 }], deal: null, counter: null,
  messages: [{ who: 'npc', text: 'Fala <b>aí</b>', source: 'local' }], ttl: 120,
});

let passed = 0, failed = 0; const failures = [];
async function test(name, fn) {
  try { await fn(); passed++; } catch (e) { failed++; failures.push(name + '\n      ' + (e && e.message)); }
}
const ok = (c, m) => { if (!c) throw new Error(m || 'asserção falhou'); };
const eq = (a, b, m) => { if (a !== b) throw new Error(`${m || 'eq'}: esperado ${JSON.stringify(b)}, obtido ${JSON.stringify(a)}`); };

async function newPage(browser, vp = { width: 1366, height: 768 }, view = baseView()) {
  const ctx = await browser.newContext({ viewport: vp });
  const page = await ctx.newPage();
  const errors = []; page.on('pageerror', (e) => errors.push(String(e)));
  await page.addInitScript(() => {
    window.__calls = []; window.__handler = async () => ({ ok: true });
    window.__MADS_TRANSPORT__ = (name, data) => { window.__calls.push({ name, data }); return window.__handler(name, data); };
  });
  await page.goto(URL);
  await page.evaluate((v) => window.postMessage({ action: 'open', data: v }, '*'), view);
  await page.waitForSelector('#app:not(.hidden)');
  page.errors = errors; page.ctx = ctx;
  return page;
}
const setHandler = (page, src) => page.evaluate((s) => { window.__handler = eval('(' + s + ')'); }, src);
const calls = (page, name) => page.evaluate((n) => window.__calls.filter((c) => c.name === n), name);
const txt = (page, sel) => page.locator(sel).innerText();
const visible = (page, sel) => page.locator(sel).isVisible();
const wheel = async (page, dy, n = 1) => { const b = await page.locator('#priceCard').boundingBox(); await page.mouse.move(b.x + b.width / 2, b.y + b.height / 2); for (let i = 0; i < n; i++) await page.mouse.wheel(0, dy); };

(async () => {
  const browser = await chromium.launch();

  await test('abre: comprador, humor, modo e chat sem injecao de HTML', async () => {
    const p = await newPage(browser);
    eq(await txt(p, '#buyerName'), 'Empresario'); eq(await p.locator('#moodBadge').textContent(), 'neutro');
    ok((await txt(p, '#modeBadge')).toUpperCase().includes('COMBO'));
    eq(await p.locator('#chat b').count(), 0, 'texto do NPC nao vira HTML');
    ok((await txt(p, '#chat')).includes('<b>aí</b>'));
    eq(p.errors.length, 0, 'sem erros JS'); await p.ctx.close();
  });

  await test('scroll do mouse ajusta o preco (5%/passo) e respeita limites 50%..150%', async () => {
    const p = await newPage(browser);
    eq(await txt(p, '#unitPrice'), '$2.000');
    await wheel(p, -100); eq(await txt(p, '#unitPrice'), '$2.100');
    await wheel(p, 100, 3); eq(await txt(p, '#unitPrice'), '$1.800');
    ok((await txt(p, '#hint')).includes('Desconto'), 'dica de desconto');
    await wheel(p, 100, 30); eq(await txt(p, '#unitPrice'), '$1.000'); ok((await txt(p, '#pct')).includes('-50%'));
    await wheel(p, -100, 40); eq(await txt(p, '#unitPrice'), '$3.000'); ok((await txt(p, '#hint')).includes('Sobrepre'));
    await p.ctx.close();
  });

  await test('teclado: setas ajustam preco e quantidade; Esc cancela', async () => {
    const p = await newPage(browser);
    await p.locator('#priceCard').focus();
    await p.keyboard.press('ArrowUp'); eq(await txt(p, '#unitPrice'), '$2.100');
    await p.keyboard.press('ArrowDown'); await p.keyboard.press('ArrowDown'); eq(await txt(p, '#unitPrice'), '$1.900');
    await p.keyboard.press('ArrowRight'); eq(await txt(p, '#qty'), '2');
    await p.locator('#chatInput').focus(); await p.keyboard.press('ArrowUp');
    eq(await txt(p, '#unitPrice'), '$1.900', 'seta sozinha no campo de texto nao mexe no preco');
    await p.keyboard.press('Control+ArrowUp'); eq(await txt(p, '#unitPrice'), '$2.000', 'Ctrl+seta ajusta mesmo no campo');
    await p.keyboard.press('Escape');
    await p.waitForSelector('#app.hidden', { state: 'attached' }); eq((await calls(p, 'close')).length, 1); await p.ctx.close();
  });

  await test('quantidade limitada por maximo/estoque e total estimado coerente', async () => {
    const v = baseView(); v.goods[0].stock = 2;
    const p = await newPage(browser, undefined, v);
    await p.click('#qPlus'); await p.locator('#qPlus').click({ force: true }); await p.locator('#qPlus').click({ force: true });
    eq(await txt(p, '#qty'), '2', 'limitado pelo estoque'); eq(await txt(p, '#total'), '$4.000');
    ok(await p.locator('#qPlus').isDisabled(), 'botao + desabilitado no limite');
    await p.click('#qMinus'); await p.locator('#qMinus').click({ force: true }); eq(await txt(p, '#qty'), '1'); ok(await p.locator('#qMinus').isDisabled());
    await p.ctx.close();
  });

  await test('oferta envia SO intencao (passo/qtd/mercadoria), nunca preco ou total', async () => {
    const p = await newPage(browser);
    await setHandler(p, 'async()=>({ok:true,messages:[{who:"npc",text:"ok",source:"local"}]})');
    await wheel(p, 100, 2); await p.click('#qPlus'); await p.click('#btnOffer');
    await p.waitForFunction(() => window.__calls.some((c) => c.name === 'act'));
    const c = (await calls(p, 'act'))[0].data;
    eq(c.kind, 'offer'); eq(c.step, -2); eq(c.qty, 2); eq(c.goods, 'pacote_rua');
    ok(!('price' in c) && !('total' in c) && !('unitPrice' in c), 'sem campos financeiros'); await p.ctx.close();
  });

  await test('loading: controles travam, clique duplo envia 1 vez, destrava ao responder', async () => {
    const p = await newPage(browser);
    await setHandler(p, '()=>new Promise(r=>{window.__release=()=>r({ok:true,messages:[{who:"npc",text:"resp",source:"local"}]})})');
    await p.click('#btnOffer'); await p.locator('#btnOffer').click({ force: true, timeout: 500 }).catch(() => {});
    ok(await visible(p, '#loading'), 'loading visivel'); ok(await p.locator('#btnOffer').isDisabled());
    ok(await p.locator('#btnSend').isDisabled() && await p.locator('#chatInput').isDisabled());
    eq((await calls(p, 'act')).length, 1, 'apenas 1 requisicao');
    await p.evaluate(() => window.__release());
    await p.waitForSelector('#loading.hidden', { state: 'attached' }); ok(!(await p.locator('#btnOffer').isDisabled()), 'destravou'); await p.ctx.close();
  });

  await test('falha de rede (rejeicao): erro mostrado e controles liberados', async () => {
    const p = await newPage(browser);
    await setHandler(p, 'async()=>{throw new Error("net")}');
    await p.click('#btnOffer'); await p.waitForSelector('#error:not(.hidden)');
    ok((await txt(p, '#errorText')).includes('Falha')); ok(!(await p.locator('#btnOffer').isDisabled()));
    ok(!(await p.locator('#chatInput').isDisabled())); eq(p.errors.length, 0); await p.ctx.close();
  });

  await test('timeout do callback: erro e destrava (UI nunca presa)', async () => {
    const p = await newPage(browser);
    await p.evaluate(() => { window.MADS_TIMEOUT_MS = 300; });
    await setHandler(p, '()=>new Promise(()=>{})');
    await p.click('#btnOffer'); ok(await visible(p, '#loading'));
    await p.waitForSelector('#error:not(.hidden)', { timeout: 3000 });
    ok((await txt(p, '#errorText')).includes('demorou')); ok(!(await p.locator('#btnOffer').isDisabled()));
    await p.waitForSelector('#loading.hidden', { state: 'attached' }); await p.ctx.close();
  });

  await test('erro autoritativo do servidor (ok:false) e exibido e nao trava', async () => {
    const p = await newPage(browser);
    await setHandler(p, 'async()=>({ok:false,err:"no_stock",message:"Voce nao tem mercadoria suficiente."})');
    await p.click('#btnOffer'); await p.waitForSelector('#error:not(.hidden)');
    eq(await txt(p, '#errorText'), 'Voce nao tem mercadoria suficiente.'); ok(!(await p.locator('#btnOffer').isDisabled()));
    await p.click('#errorX'); await p.waitForSelector('#error.hidden', { state: 'attached' }); await p.ctx.close();
  });

  await test('resposta malformada nao quebra a interface', async () => {
    const p = await newPage(browser);
    await setHandler(p, 'async()=>null'); await p.click('#btnOffer'); await p.waitForSelector('#error:not(.hidden)');
    await setHandler(p, 'async()=>"texto"'); await p.click('#btnOffer');
    ok(!(await p.locator('#btnOffer').isDisabled())); eq(p.errors.length, 0); await p.ctx.close();
  });

  await test('chat: Enter envia texto livre, eco local, historico do servidor, foco volta ao input', async () => {
    const p = await newPage(browser);
    await setHandler(p, 'async(n,d)=>({ok:true,messages:[{who:"npc",text:"Fala",source:"local"},{who:"player",text:d.text},{who:"npc",text:"Resposta IA",source:"ai"}]})');
    await p.fill('#chatInput', 'oi, tudo bem?'); await p.keyboard.press('Enter');
    await p.waitForFunction(() => document.querySelector('#chat').innerText.includes('Resposta IA'));
    const c = (await calls(p, 'act'))[0].data; eq(c.kind, 'say'); eq(c.text, 'oi, tudo bem?');
    eq(await p.locator('#aiBadge').textContent(), 'IA'); eq(await p.evaluate(() => document.activeElement.id), 'chatInput', 'foco no input');
    eq(await p.inputValue('#chatInput'), ''); await p.fill('#chatInput', '   '); await p.keyboard.press('Enter');
    eq((await calls(p, 'act')).length, 1, 'texto vazio nao envia'); await p.ctx.close();
  });

  await test('mensagem do jogador com HTML e escapada', async () => {
    const p = await newPage(browser);
    await setHandler(p, 'async(n,d)=>({ok:true,messages:[{who:"player",text:d.text}]})');
    await p.fill('#chatInput', '<img src=x onerror=alert(1)>'); await p.keyboard.press('Enter');
    await p.waitForFunction(() => document.querySelector('#chat').innerText.includes('<img')); eq(await p.locator('#chat img').count(), 0);
    await p.ctx.close();
  });

  await test('acordo: botao confirmar envia 1x mesmo com cliques repetidos; venda mostra resultado e fecha', async () => {
    const p = await newPage(browser);
    await setHandler(p, 'async(n,d)=>({ok:true,state:"deal_ready",messages:[{who:"npc",text:"Fechado!",source:"local"}],deal:{id:"1",qty:2,unitPrice:1900,total:3800,goods:"pacote_rua"}})');
    await p.click('#btnOffer'); await p.waitForSelector('#dealBox:not(.hidden)');
    ok((await txt(p, '#dealText')).includes('3.800')); ok(!(await visible(p, '#btnOffer')));
    await setHandler(p, 'async(n,d)=>(d.kind==="confirm"?{ok:true,closed:true,outcome:"sold",total:3800}:{ok:true})');
    await p.locator('#btnConfirm').dblclick({ force: true }).catch(() => {});
    await p.waitForSelector('#result:not(.hidden)');
    ok((await txt(p, '#result')).includes('3.800')); eq((await calls(p, 'act')).filter((c) => c.data.kind === 'confirm').length, 1, 'confirm 1x');
    await p.waitForSelector('#app.hidden', { state: 'attached', timeout: 4000 }); eq((await calls(p, 'close')).length, 1); await p.ctx.close();
  });

  await test('contraproposta: caixa visivel e aceitar chama accept_counter', async () => {
    const p = await newPage(browser);
    await setHandler(p, 'async()=>({ok:true,messages:[{who:"npc",text:"Faço por 1700",source:"local"}],counter:{unitPrice:1700,step:-3,qty:1}})');
    await p.click('#btnOffer'); await p.waitForSelector('#counterBox:not(.hidden)'); ok((await txt(p, '#counterText')).includes('1.700'));
    await setHandler(p, 'async()=>({ok:true})'); await p.click('#btnCounter');
    await p.waitForFunction(() => window.__calls.some((c) => c.data && c.data.kind === 'accept_counter')); await p.ctx.close();
  });

  await test('Plus rara: sem scroll/preco; so oferta especial e confirmar', async () => {
    const v = baseView(); v.mode = 'rare'; v.maxQty = 1; v.state = 'deal_ready';
    v.deal = { id: '1', qty: 1, unitPrice: 15000, total: 15000, goods: 'pacote_rua', rare: true };
    const p = await newPage(browser, undefined, v);
    ok(!(await visible(p, '#priceCard'))); ok(!(await visible(p, '#btnOffer'))); ok(await visible(p, '#dealBox'));
    eq(await p.locator('#dealLabel').textContent(), 'Oferta especial');
    ok((await txt(p, '#dealText')).includes('15.000')); await p.ctx.close();
  });

  await test('desfecho terminal na abertura (denuncia) mostra resultado e fecha sozinho', async () => {
    const v = baseView(); v.state = 'terminal'; v.outcome = 'refuse_report'; v.mode = 'simple';
    const p = await newPage(browser, undefined, v);
    await p.waitForSelector('#result:not(.hidden)'); ok((await txt(p, '#result')).includes('polícia'));
    await p.waitForSelector('#app.hidden', { state: 'attached', timeout: 4000 }); await p.ctx.close();
  });

  await test('cancelar: fecha mesmo se o callback close falhar', async () => {
    const p = await newPage(browser);
    await setHandler(p, 'async()=>{throw new Error("x")}'); await p.click('#btnClose');
    await p.waitForSelector('#app.hidden', { state: 'attached' }); await p.ctx.close();
  });

  await test('cancelar durante o loading ainda e possivel', async () => {
    const p = await newPage(browser);
    await setHandler(p, '()=>new Promise(()=>{})'); await p.click('#btnOffer'); ok(await visible(p, '#loading'));
    await p.keyboard.press('Escape'); await p.waitForSelector('#app.hidden', { state: 'attached', timeout: 3000 }); await p.ctx.close();
  });

  await test('mensagem de fechamento do servidor (close) esconde a interface', async () => {
    const p = await newPage(browser);
    await p.evaluate(() => window.postMessage({ action: 'close' }, '*')); await p.waitForSelector('#app.hidden', { state: 'attached' }); await p.ctx.close();
  });

  for (const vp of [{ width: 375, height: 667 }, { width: 768, height: 1024 }, { width: 1366, height: 768 }, { width: 1920, height: 1080 }, { width: 800, height: 450 }]) {
    await test(`responsivo ${vp.width}x${vp.height}: sem rolagem horizontal; controles alcancaveis`, async () => {
      const v = baseView(); v.goods.push({ key: 'g2', label: 'Outra', stock: 1, priceMult: 1.2 });
      v.counter = { unitPrice: 1700, step: -3, qty: 1 };
      for (let i = 0; i < 12; i++) v.messages.push({ who: i % 2 ? 'player' : 'npc', text: 'mensagem longa de teste '.repeat(6), source: 'local' });
      const p = await newPage(browser, vp, v);
      const m = await p.evaluate(() => ({ sw: document.documentElement.scrollWidth, iw: innerWidth, app: document.getElementById('app').getBoundingClientRect().toJSON() }));
      ok(m.sw <= m.iw, `overflow horizontal ${m.sw}>${m.iw}`); ok(m.app.width <= m.iw + 1 && m.app.left >= -1, 'app dentro da tela');
      for (const sel of ['#chatInput', '#btnSend', '#btnOffer', '#btnClose', '#priceCard']) {
        await p.locator(sel).scrollIntoViewIfNeeded();
        const b = await p.locator(sel).boundingBox(); ok(b && b.width > 20 && b.height > 20, sel + ' visivel');
        ok(b.x >= -1 && b.x + b.width <= vp.width + 1, `${sel} dentro da largura`);
      }
      await p.click('#btnOffer', { trial: true }); await p.ctx.close();
    });
  }

  await test('ttl chega a zero: mostra expirou e libera foco', async () => {
    const v = baseView(); v.ttl = 2;
    const p = await newPage(browser, undefined, v);
    await p.waitForSelector('#result:not(.hidden)', { timeout: 4000 }); ok((await txt(p, '#result')).includes('expirou'));
    await p.waitForSelector('#app.hidden', { state: 'attached', timeout: 4000 }); ok((await calls(p, 'close')).length >= 1); await p.ctx.close();
  });

  await browser.close();
  console.log(`\nNUI (Chromium/Playwright) | ${passed} passou, ${failed} falhou`);
  for (const f of failures) console.log('  FALHA: ' + f);
  process.exit(failed === 0 ? 0 : 1);
})().catch((e) => { console.error(e); process.exit(2); });
