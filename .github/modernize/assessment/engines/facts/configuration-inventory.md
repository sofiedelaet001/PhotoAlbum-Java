# Configuration & Externalized Settings Inventory

Three Spring properties files, Docker Compose with a local dotenv template, and Azure Bicep/deployment scripts supply configuration. Local Docker uses externally supplied passwords, Azure's database connection is intended to use a managed identity, and tests have separate overrides.

## Configuration Sources

| Source | Type | Path/Location | Notes |
|---|---|---|---|
| Base settings | Spring properties | `src/main/resources/application.properties` | Loaded for all profiles; environment placeholders and no database password. |
| Docker overrides | Spring profile properties | `src/main/resources/application-docker.properties` | Loaded with `docker`; requires a datasource password. |
| Test overrides | Spring profile properties | `src/test/resources/application-test.properties` | Only on the test classpath with `test`. |
| Local service configuration | Compose / host environment | `docker-compose.yml` | Interpolates host or `.env` variables, sets container environments and mounts `postgres-init/01-init-schema.sh` for first initialization. |
| Local secret template | Dotenv template | `.env.example` | Copy to git-ignored `.env` and replace placeholders; do not commit actual credentials. |
| Azure infrastructure | Bicep and ARM parameters | `infra/main.bicep`, `infra/modules/{containerapp,containerregistry,identity,loganalytics,postgresql}.bicep`, `infra/parameters.json`, `infra/main.parameters.json` | Defines resource defaults, runtime environment and secure admin-password parameter. JSON files contain empty placeholders for sensitive values. |
| Azure provisioning | CLI scripts / process environment | `infra/deploy.sh`, `infra/deploy.ps1` | Pass parameters to Bicep and create the `photoalbumdb` passwordless Service Connector unless skipped. |
| Separate legacy provisioning | PowerShell / generated dotenv | `azure-setup.ps1` | Separate password-based Azure setup; emits local connection variables, not the Container Apps managed-identity deployment. |
| Azure runtime injection | Service Connector | Container App connection `photoalbumdb` | Intended to inject datasource URL, username, passwordless setting and managed-identity settings; not hard-coded in Bicep. |
| Registry secret (conditional) | Container Apps secret | `infra/modules/containerapp.bicep` | `acr-password` exists only when the `AcrPull` role assignment is disabled. |

No `bootstrap.*` file, Spring Cloud Config Git repository, external configuration server, Key Vault/Vault/AWS Secrets Manager integration, Kubernetes ConfigMap/Secret, or actual `.env` file is present in the inspected workspace.

## Build Profiles

| Profile | Activation | Purpose | Key Dependencies/Plugins |
|---|---|---|---|
| Default Maven build | Automatic, e.g. `mvn package` | Build Java 25 executable JAR | Spring Boot parent and Maven plugin `4.0.0`; Spring Cloud Azure BOM `7.4.0`; web, Thymeleaf, JPA, security, validation, PostgreSQL/Azure JDBC and test dependencies. |
| Container build invocation (not a Maven profile) | `docker build` or `docker compose up --build` | Package the app without running tests | Dockerfile runs `mvn clean package -DskipTests` using Maven 3.9.6/Temurin 8, then Temurin 8 JRE. **These Java 8 images are incompatible with the POM's Java 25 target/Spring Boot 4.** |

`pom.xml` has no Maven `<profiles>`; `docker` and `test` are Spring **runtime** profiles. `-DskipTests` is a build option, not a profile.

## Runtime Profiles

| Profile | Activation Method | Config Files | Key Overrides |
|---|---|---|---|
| Default | No active Spring profile; Azure Service Connector can inject runtime settings | `application.properties` | PostgreSQL/Entra passwordless defaults, JPA `update`, application/web logging `DEBUG`. Requires externally supplied `app.admin.password`. |
| `docker` | Compose `SPRING_PROFILES_ACTIVE=docker`, or explicitly select the profile for a local run | Base + `application-docker.properties` | Password-based PostgreSQL, passwordless `false`, JPA `create`, changed logging. |
| `test` | `@ActiveProfiles("test")` on integration test classes | Base + test-classpath `application-test.properties` | H2, JPA `create-drop`, test-only admin credentials and upload-path setting. |

Spring can activate multiple comma-separated profiles, but no composed activation, `spring.profiles.active` in a properties file, or `@Profile` component is defined. `AZURE_CLIENT_ID` does not activate a Spring profile.

## Properties Inventory

**Spring application.** Defaults below are packaged values or placeholder fallbacks, not claims about the value injected at runtime. Spring's environment/property sources can override packaged properties; active profile files override the base file. `required` means no fallback; sensitive values are masked.

| Property Key | Default / Type | Profiles / Overrides | Source |
|---|---|---|---|
| `server.port` | `8080` (TCP port) | Docker repeats `8080`; Azure sets `SERVER_PORT` to `targetPort` | Base, Docker, Bicep |
| `server.servlet.encoding.charset` | `UTF-8` (charset) | Docker repeats | Base, Docker |
| `server.servlet.encoding.enabled` | `true` (boolean) | Docker repeats | Base, Docker |
| `server.servlet.encoding.force` | `true` (boolean) | Docker repeats | Base, Docker |
| `spring.datasource.url` | `${SPRING_DATASOURCE_URL:jdbc:postgresql://postgres-db:5432/photoalbum}` (JDBC URL) | Docker repeats; test `jdbc:h2:mem:testdb`; Azure Service Connector injects URL | Base, Docker, test, Service Connector |
| `spring.datasource.username` | `${SPRING_DATASOURCE_USERNAME:photoalbum}` (string) | Docker repeats; test `sa`; Azure Service Connector injects username | Base, Docker, test, Service Connector |
| `spring.datasource.password` | Absent in base (sensitive string) | Docker requires `${SPRING_DATASOURCE_PASSWORD}`; test sets empty; Azure uses token-based authentication | Docker, test |
| `spring.datasource.driver-class-name` | `org.postgresql.Driver` (class) | Docker repeats; test `org.h2.Driver` | Base, Docker, test |
| `spring.datasource.azure.passwordless-enabled` | `${SPRING_DATASOURCE_AZURE_PASSWORDLESS_ENABLED:true}` (boolean) | Docker `false`; Azure Service Connector injects setting | Base, Docker, Service Connector |
| `spring.cloud.azure.credential.managed-identity-enabled` | `${SPRING_CLOUD_AZURE_CREDENTIAL_MANAGED_IDENTITY_ENABLED:true}` (boolean) | Azure Service Connector injects setting | Base, Service Connector |
| `spring.cloud.azure.credential.client-id` | `${SPRING_CLOUD_AZURE_CREDENTIAL_CLIENT_ID:}` (string, empty fallback) | Azure Service Connector supplies user-assigned identity; Bicep also sets `AZURE_CLIENT_ID` | Base, Service Connector, Bicep |
| `spring.jpa.database-platform` | `org.hibernate.dialect.PostgreSQLDialect` (class) | Docker repeats; test `org.hibernate.dialect.H2Dialect` | Base, Docker, test |
| `spring.jpa.hibernate.ddl-auto` | `${SPRING_JPA_HIBERNATE_DDL_AUTO:update}` (enum-like string) | Docker `create`; test `create-drop` | Base, Docker, test |
| `spring.jpa.show-sql` | `true` (boolean) | Docker repeats; test `false` | Base, Docker, test |
| `spring.jpa.properties.hibernate.format_sql` | `true` (boolean) | Docker repeats | Base, Docker |
| `spring.servlet.multipart.max-file-size` | `10MB` (data size) | Docker repeats | Base, Docker |
| `spring.servlet.multipart.max-request-size` | `50MB` (data size) | Docker repeats | Base, Docker |
| `app.file-upload.max-file-size-bytes` | `10485760` (long, bytes) | Docker repeats twice; test repeats | Base, Docker, test |
| `app.file-upload.allowed-mime-types` | `image/jpeg,image/png,image/gif,image/webp` (CSV strings) | Docker repeats twice; test repeats | Base, Docker, test |
| `app.file-upload.max-files-per-upload` | `10` (integer) | Docker repeats twice; test repeats | Base, Docker, test |
| `app.file-upload.upload-path` | Unset outside tests (path) | Test `target/test-uploads`; no production consumer identified | Test |
| `app.admin.username` | `admin` (string, `@Value` fallback) | Compose `APP_ADMIN_USERNAME` defaults to `admin`; test sets `admin` | `SecurityConfig`, Compose, test |
| `app.admin.password` | Required (sensitive string, `@Value` without fallback) | Compose requires `APP_ADMIN_PASSWORD`; test supplies a test-only value [MASKED]; Azure templates do not supply it | `SecurityConfig`, Compose, test |
| `logging.level.com.photoalbum` | `DEBUG` (level) | Docker `INFO`; test `DEBUG` | Base, Docker, test |
| `logging.level.org.springframework.web` | `DEBUG` (level) | Docker `WARN` | Base, Docker |
| `logging.level.org.hibernate.SQL` | Unset | Docker `DEBUG` | Docker |

The base file comments also describe optional, **not configured** service-principal keys `spring.cloud.azure.profile.tenant-id`, `spring.cloud.azure.credential.client-secret`, and `spring.cloud.azure.credential.client-id`, and sovereign-cloud keys `spring.cloud.azure.profile.cloud-type` and `spring.datasource.azure.scopes`. These are guidance, not active property assignments.

**Compose and local PostgreSQL.** Compose `${VAR:-fallback}` uses a host or `.env` value when present, while `${VAR:?message}` requires a nonempty value.

| Property Key | Default / Type | Profiles / Overrides | Source |
|---|---|---|---|
| `APP_DB_NAME` → `POSTGRES_DB`, JDBC database name | `photoalbum` (string) | Local Compose | Compose, `.env.example` |
| `POSTGRES_ADMIN_USER` → `POSTGRES_USER` | `postgres` (string) | Local Compose | Compose, `.env.example` |
| `POSTGRES_ADMIN_PASSWORD` → `POSTGRES_PASSWORD` | Required [MASKED] | Local database bootstrap | Compose, `.env.example` |
| `APP_USER` → `APP_USER`, `SPRING_DATASOURCE_USERNAME` | `photoalbum` (string) | Local init and app | Compose, `.env.example`, `postgres-init/01-init-schema.sh` |
| `APP_USER_PASSWORD` → `APP_USER_PASSWORD`, `SPRING_DATASOURCE_PASSWORD` | Required [MASKED] | Local init and app | Compose, `.env.example`, init script |
| `APP_ADMIN_USERNAME` → `APP_ADMIN_USERNAME` | `admin` (string) | Local app | Compose, `.env.example` |
| `APP_ADMIN_PASSWORD` → `APP_ADMIN_PASSWORD` | Required [MASKED] | Local app | Compose, `.env.example` |
| `SPRING_DATASOURCE_URL` | `jdbc:postgresql://postgres-db:5432/${APP_DB_NAME:-photoalbum}` | Local app | Compose |

**Azure deployment inputs** (deployment configuration, not packaged Spring properties):

| Property Key | Default / Type | Profiles / Overrides | Source |
|---|---|---|---|
| `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP` | Current Azure CLI subscription, `rg-photoalbum` | Deployment scripts | `infra/deploy.*` |
| `AZURE_LOCATION`, `AZURE_POSTGRES_LOCATION`, `AZURE_ENV_NAME` | `eastus2`, `eastus2`, `photoalbum` | Scripts override Bicep defaults; parameter JSON also sets `eastus2` | `infra/deploy.*`, `infra/main.bicep`, parameter JSON |
| `AZURE_POSTGRES_DATABASE_NAME`, `AZURE_TARGET_PORT` | `photoalbum`, `8080` | Bash script; PowerShell has corresponding fixed defaults | `infra/deploy.sh`, `infra/deploy.ps1` |
| `SKIP_SERVICE_CONNECTOR` | `false` (string interpreted as boolean) | PowerShell equivalent: `-SkipServiceConnector` switch | Deployment scripts |
| `environmentName`, `location`, `postgresLocation`, `databaseName` | `photoalbum`, resource group location, `location`, `photoalbum` | Script/parameter-file overrides | `infra/main.bicep`, deployment scripts, parameter JSON |
| `postgresAdministratorLogin`, `postgresAdministratorLoginPassword` | `pgadmin`; required secure value [MASKED] | Scripts generate password; parameter JSON contains empty placeholder | `infra/main.bicep`, deployment scripts, parameter JSON |
| `entraAdminObjectId`, `entraAdminName`, `entraAdminType` | Required, required, `User` | Scripts derive signed-in Entra user; parameter JSON holds identity placeholders | `infra/main.bicep`, deployment scripts |
| `targetPort`, `assignAcrPullRole` | `8080` (port), `true` (boolean) | Script can retry with `assignAcrPullRole=false` | `infra/main.bicep`, deployment scripts |
| `tags` | `azd-env-name`, `application`, `managedBy` | Bicep parameter override | `infra/main.bicep` |
| `containerImage`, `containerName`, `useRegistryAdminCredentials` | `mcr.microsoft.com/azuredocs/containerapps-helloworld:latest`, `photoalbum`, `false` | Image must be replaced at app rollout; registry fallback uses `!assignAcrPullRole` | `infra/modules/containerapp.bicep` |
| `skuName`, `skuTier`, `storageSizeGB`, `postgresVersion` | `Standard_B1ms`, `Burstable`, `32` (GB), `17` | PostgreSQL module parameters | `infra/modules/postgresql.bicep` |
| `tenantId` | Subscription tenant ID | Entra admin | `infra/modules/postgresql.bicep` |

Remaining Bicep module inputs (generated names, IDs, workspace IDs, registry server and identity IDs) are wired from `infra/main.bicep` module outputs, not independent external property defaults. `azure-setup.ps1` separately reads or generates `POSTGRES_ADMIN_USER`, `POSTGRES_ADMIN_PASSWORD`, `POSTGRES_APP_USER` and `POSTGRES_APP_PASSWORD`; its emitted dotenv variables are not the current Compose input contract.

## Startup Parameters & Resource Requirements

| Service | JVM/Runtime Options | Memory | Instance Count |
|---|---|---|---|
| Compose `photoalbum-java-app` | Dockerfile `JAVA_OPTS="-Xmx512m -Xms256m"`; `java $JAVA_OPTS -jar app.jar`; `SPRING_PROFILES_ACTIVE=docker`; port `8080` | 256 MiB initial / 512 MiB maximum JVM heap; no container memory or CPU limit set | One container; no scaling configured |
| Compose `postgres-db` | PostgreSQL 17, port `5432`; persistent `postgres_data` volume and first-run init script | No memory or CPU limit set | One container |
| Azure Container App | `AZURE_CLIENT_ID` from user-assigned identity, `SERVER_PORT` from `targetPort` (`8080`); no JVM flags in Bicep; if this Dockerfile image is used, its 512 MiB max heap applies | 1 GiB and 0.5 CPU per replica | Minimum 1, maximum 3 replicas |
| Azure PostgreSQL Flexible Server | PostgreSQL 17, `Standard_B1ms`/`Burstable`, 32 GB storage | No explicit memory/CPU setting beyond SKU | One server |
| Local Maven run | Profile can be set with `-Dspring-boot.run.profiles=docker` or `SPRING_PROFILES_ACTIVE=docker`; no default startup `-D` or heap flags | Not specified | One process |

## Startup Dependency Chain

1. Local: `postgres-db` initializes the database and application role on a new volume, then `pg_isready` checks the admin user/database (10-second interval, 5-second timeout, 15 retries, 30-second start period).
2. Local: `photoalbum-java-app` waits for `postgres-db` via Compose `depends_on: condition: service_healthy` and restarts `on-failure`. No application health check or explicit app startup timeout is configured.
3. Azure provisioning: Log Analytics and the identity feed the Container Apps module; identity and registry/`AcrPull` assignment precede the Container App. PostgreSQL server → firewall rule → Entra admin → database; scripts subsequently create Service Connector `photoalbumdb` unless skipped.
4. Azure runtime: image pull requires identity `AcrPull` or the conditional registry secret; PostgreSQL connectivity requires the provisioned server, Entra role and Service Connector. Bicep initially deploys a hello-world placeholder image; no explicit application readiness/liveness probe, database wait loop or startup timeout is defined.

## Secrets & Sensitive Configuration

| Secret Reference | Type | Storage (masked) |
|---|---|---|
| `POSTGRES_ADMIN_PASSWORD` → `POSTGRES_PASSWORD` | Local database bootstrap password | Ignored local `.env` → Compose environment [MASKED]; template contains only a replacement placeholder. |
| `APP_USER_PASSWORD` → `SPRING_DATASOURCE_PASSWORD` | Local database application-role password | Ignored local `.env` → PostgreSQL init and Java environment [MASKED]; Docker properties require the environment value. |
| `APP_ADMIN_PASSWORD` → `app.admin.password` | Application admin password | Required Compose environment [MASKED], or other external Spring configuration; Azure templates do not bind it. |
| `postgresAdministratorLoginPassword` | Azure PostgreSQL bootstrap password | Randomly generated by `infra/deploy.*`, passed via Bicep `@secure()` parameter [MASKED]; not used by app. |
| `acr-password` | Conditional ACR image-pull credential | Container Apps secret populated by `containerRegistry.listCredentials()` only in registry-admin fallback [MASKED]. |
| `spring.cloud.azure.credential.client-secret` | Optional, not configured service-principal secret | Described in comments/README only; would require external provisioning [MASKED]. |
| Legacy `POSTGRES_PASSWORD` / `POSTGRES_APP_PASSWORD` | Separate Azure setup passwords | `azure-setup.ps1` reads or generates them and writes local dotenv settings [MASKED]; not the managed-identity deployment path. |

### Secrets Provisioning Workflow

Local: copy `.env.example` to ignored `.env`, replace all password placeholders, then start Compose. Compose requires the database bootstrap, application-role and admin passwords; it passes the database values to PostgreSQL/first-run init and the app-role/admin values to Spring. Existing database volumes do not rerun initialization.

Azure Bicep path: an authenticated operator's deployment script generates the PostgreSQL administrator password, passes it as a secure Bicep parameter and makes the signed-in Entra user the database administrator. A user-assigned managed identity receives registry `AcrPull` RBAC (the deploying principal needs permission to assign roles); Service Connector then binds that identity to PostgreSQL and injects passwordless datasource settings. If role assignment fails, deployment retries with ACR admin enabled and stores the registry password as the `acr-password` Container Apps secret. No Key Vault or encrypted property store is provisioned. **`app.admin.password` is required by the application but not provisioned by Bicep or Service Connector; a real application image needs an externally supplied value to start.**

## Feature Flags

| Flag Name | Default | Controlled By |
|---|---|---|
| `spring.datasource.azure.passwordless-enabled` | `true` base; `false` Docker | `SPRING_DATASOURCE_AZURE_PASSWORDLESS_ENABLED`, Docker profile, Service Connector |
| `spring.cloud.azure.credential.managed-identity-enabled` | `true` base | `SPRING_CLOUD_AZURE_CREDENTIAL_MANAGED_IDENTITY_ENABLED`, Service Connector |
| `assignAcrPullRole` / `useRegistryAdminCredentials` | `true` / `false` | Bicep parameter; deployment retry switches to registry-admin credentials on failure |
| `SKIP_SERVICE_CONNECTOR` / `-SkipServiceConnector` | `false` / not set | Bash environment / PowerShell switch |

No application feature-flag service, A/B rollout, `@ConditionalOnProperty`, or `@ConditionalOnExpression` is configured.

## Framework & Runtime Versions

| Component | Version | Source |
|---|---|---|
| Spring Boot parent / Maven plugin | `4.0.0` (plugin version inherited) | `pom.xml` |
| Java compile target | `25` | `pom.xml` |
| Spring Cloud Azure BOM | `7.4.0` | `pom.xml` |
| Spring Boot DevTools | `4.0.6` explicitly | `pom.xml` |
| Commons IO | `2.14.0` explicitly | `pom.xml` |
| Hibernate, PostgreSQL JDBC, H2, Spring Security | Managed by parent/BOM; no explicit artifact version | `pom.xml` |
| Maven build image | `maven:3.9.6-eclipse-temurin-8` (Maven 3.9.6 / Java 8) | `Dockerfile`; incompatible with Java 25 compilation |
| Java runtime image | `eclipse-temurin:8-jre` (Java 8) | `Dockerfile`; incompatible with Java 25 bytecode |
| Local PostgreSQL image / Azure PostgreSQL | `postgres:17-alpine` / `17` | `docker-compose.yml`, `infra/modules/postgresql.bicep` |
| Azure Container App initial image | `mcr.microsoft.com/azuredocs/containerapps-helloworld:latest` | `infra/modules/containerapp.bicep`; placeholder, not a pinned application runtime |
| Local Maven installation | Not pinned; no Maven wrapper in repository | Repository root |
