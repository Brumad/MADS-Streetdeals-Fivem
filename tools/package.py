#!/usr/bin/env python3
"""Gera os dois pacotes em dist/ (ignorado pelo git) e verifica integridade:
  MADS_StreetDeals_Qbox.zip              -> resource instalavel (pasta mads_streetdeals/)
  MADS_StreetDeals_Projeto_Completo.zip  -> codigo + testes + ferramentas + documentacao
Sem segredos: varre os arquivos por padroes de chave antes de empacotar."""
import hashlib, os, re, sys, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIST = os.path.join(ROOT, "dist")
os.makedirs(DIST, exist_ok=True)

RESOURCE = ["fxmanifest.lua", "config", "core", "server", "client", "nui", "sql", "install", "INSTALACAO.md", "CONFIGURACAO.md",
            "IA_E_SEGURANCA.md", "INTEGRACAO_QBOX.md", "HOMOLOGACAO_FXSERVER.md"]
SKIP_DIRS = {".git", "dist", "node_modules", "__pycache__", "test-results", "playwright-report"}
SKIP_EXT = {".zip", ".log", ".pyc"}
SECRET = re.compile(r"(sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|api[_-]?key\s*[:=]\s*['\"][A-Za-z0-9_-]{16,})", re.I)

def walk(paths):
    for p in paths:
        full = os.path.join(ROOT, p)
        if os.path.isfile(full):
            yield p
        else:
            for d, dirs, files in os.walk(full):
                dirs[:] = [x for x in dirs if x not in SKIP_DIRS]
                for f in sorted(files):
                    if os.path.splitext(f)[1] in SKIP_EXT: continue
                    yield os.path.relpath(os.path.join(d, f), ROOT)

def scan(rel):
    try:
        txt = open(os.path.join(ROOT, rel), encoding="utf-8").read()
    except UnicodeDecodeError:
        return
    m = SECRET.search(txt)
    if m: sys.exit(f"ABORTADO: possivel segredo em {rel}: {m.group(0)[:12]}...")

def build(name, files, prefix):
    out = os.path.join(DIST, name)
    if os.path.exists(out): os.remove(out)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for rel in files:
            scan(rel)
            z.write(os.path.join(ROOT, rel), os.path.join(prefix, rel).replace(os.sep, "/"))
    with zipfile.ZipFile(out) as z:
        bad = z.testzip()
        if bad: sys.exit(f"ZIP corrompido: {bad}")
        n = len(z.namelist())
    sha = hashlib.sha256(open(out, "rb").read()).hexdigest()
    print(f"{name}: {n} arquivos, {os.path.getsize(out)} bytes, sha256={sha}")

everything = sorted(set(walk(["."])) - {".gitignore"} | {".gitignore"})
everything = [f for f in everything if not f.startswith(("dist/", ".git/"))]
build("MADS_StreetDeals_Qbox.zip", sorted(set(walk(RESOURCE))), "mads_streetdeals")
build("MADS_StreetDeals_Projeto_Completo.zip", everything, "MADS-Streetdeals-Fivem")
