@echo off
title Bombastico Dedicated Server
echo ========================================================
echo Iniciando Servidor Dedicado do Bombastico (Windows)
echo Porta padrao: 8910 (UDP)
echo ========================================================

REM Substitua pelo caminho do seu executavel do Godot ou build exportada
if exist "builds\windows\Bombastico.exe" (
    start "" builds\windows\Bombastico.exe --headless --server --port=8910
) else (
    echo Executavel exportado nao encontrado em builds\windows\Bombastico.exe.
    echo Para testar direto pelo Godot Engine, execute:
    echo godot.exe --headless --path . --server --port=8910
)
pause
