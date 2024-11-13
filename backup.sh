#!/bin/sh

set -e
set -o pipefail

>&2 echo "-----"

# Define o fuso horário
export TZ=${TZ:-UTC}  # Usa UTC como padrão caso TZ não esteja definido

# Verifica as variáveis de ambiente
if [ "${S3_ACCESS_KEY_ID}" = "**None**" ]; then
  echo "You need to set the S3_ACCESS_KEY_ID environment variable."
  exit 1
fi

if [ "${S3_SECRET_ACCESS_KEY}" = "**None**" ]; then
  echo "You need to set the S3_SECRET_ACCESS_KEY environment variable."
  exit 1
fi

if [ "${S3_BUCKET}" = "**None**" ]; then
  echo "You need to set the S3_BUCKET environment variable."
  exit 1
fi

if [ "${POSTGRES_HOST}" = "**None**" ]; then
  if [ -n "${POSTGRES_PORT_5432_TCP_ADDR}" ]; then
    POSTGRES_HOST=$POSTGRES_PORT_5432_TCP_ADDR
    POSTGRES_PORT=$POSTGRES_PORT_5432_TCP_PORT
  else
    echo "You need to set the POSTGRES_HOST environment variable."
    exit 1
  fi
fi

if [ "${POSTGRES_USER}" = "**None**" ]; then
  echo "You need to set the POSTGRES_USER environment variable."
  exit 1
fi

if [ "${POSTGRES_PASSWORD}" = "**None**" ]; then
  echo "You need to set the POSTGRES_PASSWORD environment variable or link to a container named POSTGRES."
  exit 1
fi

if [ "${S3_ENDPOINT}" == "**None**" ]; then
  AWS_ARGS=""
else
  AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
fi

# Configuração do AWS e PostgreSQL
export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$S3_REGION
export PGPASSWORD=$POSTGRES_PASSWORD
POSTGRES_HOST_OPTS="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER $POSTGRES_EXTRA_OPTS"

# Criação do dump
if [ "${POSTGRES_DATABASE}" == "all" ]; then
  # Lista os bancos de dados e cria um dump separado para cada um
  DATABASES=$(psql $POSTGRES_HOST_OPTS -d postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;")
  
  for DB in $DATABASES; do
    SRC_FILE="${DB}_$(date +"%Y-%m-%dT%H:%M:%SZ").sql.gz"
    echo "Creating dump of ${DB} database from ${POSTGRES_HOST}..."
    pg_dump $POSTGRES_HOST_OPTS -d $DB | gzip > $SRC_FILE
    
    # Encrypt the file if encryption password is set
    if [ "${ENCRYPTION_PASSWORD}" != "**None**" ]; then
      >&2 echo "Encrypting ${SRC_FILE}"
      openssl enc -aes-256-cbc -in $SRC_FILE -out ${SRC_FILE}.enc -k $ENCRYPTION_PASSWORD
      if [ $? != 0 ]; then
        >&2 echo "Error encrypting ${SRC_FILE}"
      fi
      rm $SRC_FILE
      SRC_FILE="${SRC_FILE}.enc"
    fi

    # Upload para o S3
    echo "Uploading ${SRC_FILE} to $S3_BUCKET"
    cat $SRC_FILE | aws $AWS_ARGS s3 cp - s3://$S3_BUCKET/$S3_PREFIX/$SRC_FILE || exit 2
    rm $SRC_FILE  # Remove o arquivo local após o upload
  done
else
  # Backup de um banco de dados específico
  SRC_FILE=${POSTGRES_DATABASE}_$(date +"%Y-%m-%dT%H:%M:%SZ").sql.gz
  echo "Creating dump of ${POSTGRES_DATABASE} database from ${POSTGRES_HOST}..."
  pg_dump $POSTGRES_HOST_OPTS $POSTGRES_DATABASE | gzip > $SRC_FILE
  
  # Encrypt the file if encryption password is set
  if [ "${ENCRYPTION_PASSWORD}" != "**None**" ]; then
    >&2 echo "Encrypting ${SRC_FILE}"
    openssl enc -aes-256-cbc -in $SRC_FILE -out ${SRC_FILE}.enc -k $ENCRYPTION_PASSWORD
    if [ $? != 0 ]; then
      >&2 echo "Error encrypting ${SRC_FILE}"
    fi
    rm $SRC_FILE
    SRC_FILE="${SRC_FILE}.enc"
  fi
  
  echo "Uploading ${SRC_FILE} to $S3_BUCKET"
  cat $SRC_FILE | aws $AWS_ARGS s3 cp - s3://$S3_BUCKET/$S3_PREFIX/$SRC_FILE || exit 2
  rm $SRC_FILE
fi

# Excluir arquivos antigos, se definido
if [ "${DELETE_OLDER_THAN}" != "**None**" ]; then
  >&2 echo "Checking for files older than ${DELETE_OLDER_THAN}"
  aws $AWS_ARGS s3 ls s3://$S3_BUCKET/$S3_PREFIX/ | grep " PRE " -v | while read -r line;
    do
      fileName=`echo $line | awk {'print $4'}`
      created=`echo $line | awk {'print $1" "$2'}`
      created=`date -d "$created" +%s`
      older_than=`date -d "$DELETE_OLDER_THAN" +%s`
      if [ $created -lt $older_than ]
      then
        if [ $fileName != "" ]
        then
          >&2 echo "DELETING ${fileName}"
          aws $AWS_ARGS s3 rm s3://$S3_BUCKET/$S3_PREFIX/$fileName
        fi
      else
        >&2 echo "${fileName} not older than ${DELETE_OLDER_THAN}"
      fi
    done
fi

echo "SQL backup finished"
>&2 echo "-----"
