# Dockerfile para Servidor Dedicado do Bombástico
FROM debian:bookworm-slim

# Instala dependências básicas do sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libfontconfig1 \
    libasound2 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copia os arquivos da build do servidor
COPY builds/server/ /app/

RUN test -f /app/Bombastico_Server.x86_64 \
    && chmod +x /app/Bombastico_Server.x86_64

EXPOSE 8910/udp

ENTRYPOINT ["./Bombastico_Server.x86_64", "--headless", "--server", "--port=8910"]
