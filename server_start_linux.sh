#!/bin/bash
# ========================================================
# Script de Inicialização do Servidor Dedicado do Bombástico (Linux)
# ========================================================

PORT=8910
SERVER_BIN="./Bombastico_Server.x86_64"

echo "========================================================"
echo "Iniciando Bombástico Dedicated Server..."
echo "Porta: $PORT (UDP)"
echo "========================================================"

if [ -f "$SERVER_BIN" ]; then
    chmod +x "$SERVER_BIN"
    "$SERVER_BIN" --headless --server --port=$PORT
else
    echo "Executável $SERVER_BIN não encontrado."
    echo "Se você estiver usando o binário godot headless:"
    echo "./godot --headless --path . --server --port=$PORT"
fi
