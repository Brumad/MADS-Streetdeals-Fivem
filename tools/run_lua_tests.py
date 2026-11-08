#!/usr/bin/env python3
"""Executa tests/run_all.lua em Lua 5.4 real (via lupa.lua54) ou, se existir, no binario lua5.4.
Mocks/testes locais NAO equivalem a integracao Qbox nem a homologacao in-game."""
import os, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
exe = shutil.which("lua5.4") or shutil.which("lua")
if exe:
    sys.exit(subprocess.call([exe, "tests/run_all.lua"]))
try:
    from lupa.lua54 import LuaRuntime
except ImportError:
    sys.exit("Sem lua5.4 nem lupa: instale 'pip install lupa' ou o binario lua5.4.")
lua = LuaRuntime(unpack_returned_tuples=True)
with open("tests/run_all.lua", encoding="utf-8") as fh:
    failed = lua.execute(fh.read())
sys.exit(0 if failed == 0 else 1)
