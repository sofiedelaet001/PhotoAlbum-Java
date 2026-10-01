#!/bin/bash
# This script runs automatically the first time the PostgreSQL container
# initialises its data directory.
#
# The image creates the database and a separate bootstrap administrator from
# POSTGRES_DB / POSTGRES_USER / POSTGRES_PASSWORD. Create a least-privilege
# application role from APP_USER / APP_USER_PASSWORD and transfer database and
# schema ownership to that role. Credentials are intentionally NOT hard-coded.
#
# The application role receives no SUPERUSER or cluster-wide privileges.
set -euo pipefail

psql -v ON_ERROR_STOP=1 \
    -v app_user="$APP_USER" \
    -v app_password="$APP_USER_PASSWORD" \
    -v app_db="$POSTGRES_DB" \
    --username "$POSTGRES_USER" \
    --dbname "$POSTGRES_DB" <<-'EOSQL'
    CREATE ROLE :"app_user" LOGIN PASSWORD :'app_password';
    GRANT CONNECT ON DATABASE :"app_db" TO :"app_user";
    ALTER DATABASE :"app_db" OWNER TO :"app_user";
    -- Hibernate ddl-auto requires ownership to create and evolve application objects.
    ALTER SCHEMA public OWNER TO :"app_user";
    GRANT USAGE, CREATE ON SCHEMA public TO :"app_user";
EOSQL
