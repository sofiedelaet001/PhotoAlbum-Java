# Configuration & Externalized Settings Inventory

The application has a small, single-module Spring Boot configuration footprint: three property files (base, docker, test profiles), one Docker Compose environment definition, and a `.env` file for local secrets — no config server, Vault, or feature-flag framework is present.

## Configuration Sources

| Source | Type | Path/Location | Notes |
|---|---|---|---|
| `application.properties` | Spring Boot properties | `src/main/resources/application.properties` | Default profile; used for local (non-docker) run, targets Oracle at `oracle-db:1521/FREEPDB1` |
| `application-docker.properties` | Spring Boot properties (profile-specific) | `src/main/resources/application-docker.properties` | Activated via `SPRING_PROFILES_ACTIVE=docker` in Docker Compose |
| `application-test.properties` | Spring Boot properties (profile-specific) | `src/test/resources/application-test.properties` | Used during Maven test phase; switches to H2 in-memory DB |
| `docker-compose.yml` | Docker Compose environment | repo root | Defines `oracle-db` and `photoalbum-java-app` services, injects env vars into the app container |
| `.env.example` | Environment variable template | repo root | Documents required `.env` keys (`ORACLE_PASSWORD`, `APP_USER`, `APP_USER_PASSWORD`, `APP_ADMIN_USERNAME`, `APP_ADMIN_PASSWORD`); actual `.env` is git-ignored |
| `oracle-init/*.sql`, `oracle-init/create-user.sh` | DB init scripts | `oracle-init/` | Run by the Oracle container's `container-entrypoint-initdb.d` mechanism to create the app schema user |
| `azure-setup.ps1` / `azure-reset.ps1` | Deployment scripts | repo root | Provision/tear down Azure resources (not application runtime config, but externalizes deployment-time settings) |

No Spring Cloud Config, Azure App Configuration, HashiCorp Vault, or AWS Secrets Manager integration was found — all secrets are handled via plain environment variables passed through Docker Compose.

## Build Profiles

| Profile | Activation | Purpose | Key Dependencies/Plugins |
|---|---|---|---|
| (none defined) | N/A | The `pom.xml` defines no Maven `<profiles>`. A single build configuration is used for all builds. | `spring-boot-maven-plugin` (repackages jar); Java 8 source/target (`maven.compiler.source/target=8`) |
| Docker multi-stage build | Automatic (`docker build` / `docker compose build`) | Stage 1 compiles with Maven+JDK8 (`mvn clean package -DskipTests`); Stage 2 copies the jar into a slim JRE 8 runtime image | `maven:3.9.6-eclipse-temurin-8` (build stage), `eclipse-temurin:8-jre` (runtime stage) |

## Runtime Profiles

| Profile | Activation Method | Config Files | Key Overrides |
|---|---|---|---|
| default (no profile) | No `SPRING_PROFILES_ACTIVE` set (local/manual run) | `application.properties` | `spring.jpa.show-sql=true`; DEBUG logging for `com.photoalbum` and `org.springframework.web` |
| `docker` | `SPRING_PROFILES_ACTIVE=docker` set in `docker-compose.yml` for `photoalbum-java-app` | `application-docker.properties` (merged with `application.properties`) | Logging lowered to INFO/WARN, `org.hibernate.SQL=DEBUG` added; datasource URL/credentials sourced from container env vars |
| `test` | Activated by Maven Surefire during `mvn test` (Spring Boot Test convention, `@ActiveProfiles("test")` or `spring.profiles.active=test` in test context) | `application-test.properties` | Switches datasource to H2 in-memory (`jdbc:h2:mem:testdb`), `ddl-auto=create-drop`, adds `app.admin.username`/`app.admin.password` test values, sets `app.file-upload.upload-path=target/test-uploads` |

Profiles are not combined (only one active profile at a time); no `@Profile`-annotated beans were found in the codebase.

## Properties Inventory

### Server & Web

| Property Key | Default | Profiles | Source |
|---|---|---|---|
| `server.port` | `8080` | all | static value |
| `server.servlet.encoding.charset` | `UTF-8` | all | static value |
| `server.servlet.encoding.enabled` | `true` | all | static value |
| `server.servlet.encoding.force` | `true` | all | static value |
| `spring.servlet.multipart.max-file-size` | `10MB` | default, docker | static value |
| `spring.servlet.multipart.max-request-size` | `50MB` | default, docker | static value |

### Database (Oracle / H2)

| Property Key | Default | Profiles | Source |
|---|---|---|---|
| `spring.datasource.url` | `jdbc:oracle:thin:@oracle-db:1521/FREEPDB1` | default, docker | `${SPRING_DATASOURCE_URL:...}` placeholder, overridden by Docker Compose env var; test profile hardcodes H2 URL |
| `spring.datasource.username` | `photoalbum` | default, docker | `${SPRING_DATASOURCE_USERNAME:...}` placeholder; test profile hardcodes `sa` |
| `spring.datasource.password` | *(none — required)* | default, docker | `${SPRING_DATASOURCE_PASSWORD}` — no default, must be supplied via env var; test profile hardcodes empty string |
| `spring.datasource.driver-class-name` | `oracle.jdbc.OracleDriver` | default, docker | static value; test profile uses `org.h2.Driver` |
| `spring.jpa.database-platform` | `org.hibernate.dialect.OracleDialect` | default, docker | static value; test profile uses `H2Dialect` |
| `spring.jpa.hibernate.ddl-auto` | `create` | default, docker | static value; test profile uses `create-drop` |
| `spring.jpa.show-sql` | `true` | default, docker | static value; test profile sets `false` |
| `spring.jpa.properties.hibernate.format_sql` | `true` | default, docker | static value (not set in test) |

### Application-Specific (File Upload)

| Property Key | Default | Profiles | Source |
|---|---|---|---|
| `app.file-upload.max-file-size-bytes` | `10485760` (10MB) | all | static value; injected via `@Value` into `PhotoServiceImpl` |
| `app.file-upload.allowed-mime-types` | `image/jpeg,image/png,image/gif,image/webp` | all | static value; injected via `@Value` as `String[]` |
| `app.file-upload.max-files-per-upload` | `10` | all | static value (present in properties but no `@Value` usage found in code) |
| `app.file-upload.upload-path` | `target/test-uploads` | test only | test-only property; no equivalent found in default/docker profiles |

### Application-Specific (Admin/Security)

| Property Key | Default | Profiles | Source |
|---|---|---|---|
| `app.admin.username` | `admin` | test (explicit); default/docker via env fallback | `@Value("${app.admin.username:admin}")` in `SecurityConfig`; Docker Compose sets `APP_ADMIN_USERNAME` env var (Spring relaxed binding maps to this property) |
| `app.admin.password` | *(none — required)* | test (`test-admin-password`); default/docker require env var | `@Value("${app.admin.password}")` in `SecurityConfig` — no default, must be supplied; Docker Compose sets `APP_ADMIN_PASSWORD` |

### Logging

| Property Key | Default | Profiles | Source |
|---|---|---|---|
| `logging.level.com.photoalbum` | `DEBUG` | default | static value; docker overrides to `INFO` |
| `logging.level.org.springframework.web` | `DEBUG` | default | static value; docker overrides to `WARN` |
| `logging.level.org.hibernate.SQL` | *(not set)* | docker only | `DEBUG`, added only in docker profile |

### Environment Variables (Docker Compose → Container)

| Env Var | Default | Consumed By |
|---|---|---|
| `SPRING_PROFILES_ACTIVE` | `docker` (hardcoded in compose) | Spring Boot profile activation |
| `SPRING_DATASOURCE_URL` | `jdbc:oracle:thin:@oracle-db:1521/FREEPDB1` (hardcoded in compose) | `spring.datasource.url` |
| `SPRING_DATASOURCE_USERNAME` | `${APP_USER:-photoalbum}` | `spring.datasource.username` |
| `SPRING_DATASOURCE_PASSWORD` | *(required, from `.env`)* | `spring.datasource.password` |
| `APP_ADMIN_USERNAME` | `${APP_ADMIN_USERNAME:-admin}` | `app.admin.username` |
| `APP_ADMIN_PASSWORD` | *(required, from `.env`)* | `app.admin.password` |
| `ORACLE_PASSWORD` | *(required, from `.env`)* | Oracle container SYS/SYSTEM password (not consumed by the Java app) |
| `APP_USER` | `photoalbum` | Oracle container schema user creation (`oracle-init` scripts) |
| `APP_USER_PASSWORD` | *(required, from `.env`)* | Oracle container schema user password |

## Startup Parameters & Resource Requirements

| Service | JVM/Runtime Options | Memory | Instance Count |
|---|---|---|---|
| `photoalbum-java-app` | `JAVA_OPTS="-Xmx512m -Xms256m"` (set in Dockerfile `ENV`, applied via `java $JAVA_OPTS -jar app.jar`) | No explicit Docker `mem_limit` set in `docker-compose.yml`; JVM heap capped at 512MB max | 1 (single container, no scaling/replica config defined) |
| `oracle-db` (`gvenzl/oracle-free:latest`) | N/A (no JVM) | No explicit `mem_limit` set in `docker-compose.yml` | 1 |

No Kubernetes manifests or resource `requests`/`limits` were found in the repository.

## Startup Dependency Chain

1. `oracle-db` container starts first.
2. `oracle-db` healthcheck (`healthcheck.sh` via `CMD-SHELL`) polls every 30s, times out at 10s, retries up to 15 times, with a 180s start period — accounting for Oracle's slow cold-start/database creation time.
3. `photoalbum-java-app` has `depends_on: oracle-db: condition: service_healthy` in `docker-compose.yml`, so Docker Compose blocks starting the app container until the Oracle healthcheck passes.
4. On the Oracle side, `oracle-init/*.sql` and `create-user.sh` run automatically via the image's `container-entrypoint-initdb.d` mechanism to create the `photoalbum` schema user before the healthcheck can succeed.
5. `photoalbum-java-app` has `restart: on-failure`, so if the app fails to connect to the DB at startup it will retry restarting the container.

No explicit application-level readiness/health endpoint (e.g., Spring Boot Actuator) or `dockerize`/wait-for-TCP script was found for the Java app itself.

## Secrets & Sensitive Configuration

| Secret Reference | Type | Storage (masked) |
|---|---|---|
| `SPRING_DATASOURCE_PASSWORD` | DB connection password | `.env` file (git-ignored), no default — `${SPRING_DATASOURCE_PASSWORD}` (required, fails fast if unset) |
| `APP_ADMIN_PASSWORD` | Admin Basic-Auth password for state-changing endpoints | `.env` file (git-ignored), no default — `${APP_ADMIN_PASSWORD}` (required) |
| `ORACLE_PASSWORD` | Oracle SYS/SYSTEM admin password | `.env` file (git-ignored), no default (required) |
| `APP_USER_PASSWORD` | Oracle schema user password | `.env` file (git-ignored), no default (required) |
| `app.admin.password` (test) | Test-only admin password | Hardcoded in `application-test.properties` as `test-admin-password` (non-production, low sensitivity) |

No encryption tooling (Jasypt, DPAPI, sealed secrets) is used — secrets are plain environment variables. `docker-compose.yml` uses Compose's `:?` required-variable syntax so the stack refuses to start if a required secret is missing.

### Secrets Provisioning Workflow

- **Secret source**: A developer-managed `.env` file at the repo root (copied from `.env.example`, git-ignored). No centralized secret store (Key Vault, Vault, Secrets Manager) is used for local/Docker Compose deployment.
- **Identity/access model**: None — Docker Compose reads `.env` directly into container environment variables; no managed identity or RBAC is involved at this layer. (`azure-setup.ps1`/`azure-reset.ps1` may provision Azure-side identities for cloud deployment, but that is outside the Docker Compose flow.)
- **Provisioning sequence**: Developer copies `.env.example` → `.env` and fills in strong values → `docker compose up` reads `.env` → Compose injects `ORACLE_PASSWORD`/`APP_USER`/`APP_USER_PASSWORD` into the `oracle-db` container (consumed by `oracle-init` scripts to create the schema user) and `SPRING_DATASOURCE_*`/`APP_ADMIN_*` into the `photoalbum-java-app` container (consumed by Spring property placeholders).
- **Service consumption**: `oracle-db` needs `ORACLE_PASSWORD`, `APP_USER`, `APP_USER_PASSWORD`. `photoalbum-java-app` needs `SPRING_DATASOURCE_USERNAME`/`PASSWORD` (DB credentials) and `APP_ADMIN_USERNAME`/`PASSWORD` (application Basic Auth credentials for upload/delete endpoints).

## Feature Flags

No feature flag framework, `@ConditionalOnProperty`/`@ConditionalOnExpression` usage, or A/B testing configuration was found in the codebase.

## Framework & Runtime Versions

| Component | Version | Source |
|---|---|---|
| Spring Boot (parent BOM) | 2.7.18 | `pom.xml` `<parent>` |
| Java (language level) | 8 | `pom.xml` (`java.version`, `maven.compiler.source/target=8`) |
| Oracle JDBC driver (`ojdbc8`) | managed by Spring Boot BOM (no explicit version pin) | `pom.xml` |
| Commons IO | 2.11.0 | `pom.xml` |
| H2 Database (test scope) | managed by Spring Boot BOM | `pom.xml` |
| Maven (build tool, Docker build stage) | 3.9.6 | `Dockerfile` (`maven:3.9.6-eclipse-temurin-8`) |
| Docker base image (build stage) | `maven:3.9.6-eclipse-temurin-8` | `Dockerfile` |
| Docker base image (runtime stage) | `eclipse-temurin:8-jre` | `Dockerfile` |
| Oracle Database (container) | `gvenzl/oracle-free:latest` (Oracle Database Free 23ai) | `docker-compose.yml` |
