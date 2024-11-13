# postgres-backup-s3

Backup PostgresSQL to S3 (supports periodic backups)

## Basic Usage

```sh
$ docker run -e S3_ACCESS_KEY_ID="sua-chave" -e S3_SECRET_ACCESS_KEY="sua-chave-secreta" -e POSTGRES_DATABASE="nome-do-banco" -e POSTGRES_HOST="host-do-postgres" -e POSTGRES_USER="seu-usuario" -e POSTGRES_PASSWORD="sua-senha" -e S3_BUCKET="seu-bucket" -e TZ="America/Sao_Paulo" meu-backup-postgres-s3

```
## Exemple the use
```

TZ=America/Sao_Paulo
POSTGRES_DATABASE=all
POSTGRES_HOST=db_postgres
POSTGRES_PORT=5432
POSTGRES_USER=postgres
POSTGRES_PASSWORD='YOU PASSWORD'
S3_ACCESS_KEY_ID='YOU ID KEY'
S3_SECRET_ACCESS_KEY='YOU ACCESS KEY'
S3_BUCKET=postgres
S3_PREFIX=backup
S3_REGION=us-west-1
S3_ENDPOINT=https://s3.domain.com
S3_S3V4=yes
SCHEDULE=20 * * *
DELETE_OLDER_THAN=30 days ago

```

## Environment variables

| Variable             | Default          | Required | Description                                                                                                              |
|----------------------|------------------|----------|--------------------------------------------------------------------------------------------------------------------------|
| POSTGRES_DATABASE    |                  | Y        | Database you want to backup or 'all' to backup everything. In 'All' with V2 the banks are listed separately with the appropriate names and dates.|
| POSTGRES_HOST        |                  | Y        | The PostgreSQL host                                                                                                      |
| POSTGRES_PORT        | 5432             |          | The PostgreSQL port                                                                                                      |
| POSTGRES_USER        |                  | Y        | The PostgreSQL user                                                                                                      |
| POSTGRES_PASSWORD    |                  | Y        | The PostgreSQL password                                                                                                  |
| POSTGRES_EXTRA_OPTS  |                  |          | Extra postgresql options                                                                                                 |
| S3_ACCESS_KEY_ID     |                  | Y        | Your AWS access key                                                                                                      |
| S3_SECRET_ACCESS_KEY |                  | Y        | Your AWS secret key                                                                                                      |
| S3_BUCKET            |                  | Y        | Your AWS S3 bucket path                                                                                                  |
| S3_PREFIX            | backup           |          | Path prefix in your bucket                                                                                               |
| S3_REGION            | us-west-1        |          | The AWS S3 bucket region                                                                                                 |
| S3_ENDPOINT          |                  |          | The AWS Endpoint URL, for S3 Compliant APIs such as [minio](https://minio.io)                                            |
| S3_S3V4              | no               |          | Set to `yes` to enable AWS Signature Version 4, required for [minio](https://minio.io) servers                           |
| SCHEDULE             |                  |          | Backup schedule time, see explainatons below                                                                             |
| ENCRYPTION_PASSWORD  |                  |          | Password to encrypt the backup. Can be decrypted using `openssl aes-256-cbc -d -in backup.sql.gz.enc -out backup.sql.gz` |
| DELETE_OLDER_THAN    |                  |          | Delete old backups, see explanation and warning below                                                                    |
| TZ                   |America/Sao_Paulo |          |                                                                |

### Automatic Periodic Backups

You can additionally set the `SCHEDULE` environment variable like `-e SCHEDULE="@daily"` to run the backup automatically.

More information about the scheduling can be found [here](http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules).

### Delete Old Backups

You can additionally set the `DELETE_OLDER_THAN` environment variable like `-e DELETE_OLDER_THAN="30 days ago"` to delete old backups.

WARNING: this will delete all files in the S3_PREFIX path, not just those created by this script.

### Encryption

You can additionally set the `ENCRYPTION_PASSWORD` environment variable like `-e ENCRYPTION_PASSWORD="superstrongpassword"` to encrypt the backup. It can be decrypted using `openssl aes-256-cbc -d -in backup.sql.gz.enc -out backup.sql.gz`.
