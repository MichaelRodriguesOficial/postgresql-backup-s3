#!/bin/sh

set -x  # Ativa a depuração (para que você veja cada comando antes de ser executado)

# Configura o AWS S3 se necessário
if [ "${S3_S3V4}" = "yes" ]; then
    echo "Configurando AWS S3 para usar a versão v4 de assinatura"
    aws configure set default.s3.signature_version s3v4
    if [ $? -ne 0 ]; then
        echo "Erro na configuração do AWS S3"
        exit 1
    fi
fi

# Verifica o agendamento
if [ "${SCHEDULE}" = "**None**" ]; then
    echo "Sem agendamento definido, executando o backup agora"
    sh backup.sh
else
    echo "Agendando o backup com o cron: $SCHEDULE"
    exec go-cron "$SCHEDULE" /bin/sh backup.sh
fi
