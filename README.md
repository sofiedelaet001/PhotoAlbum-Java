# Photo Album Application - Java Spring Boot with PostgreSQL

A photo gallery application built with Spring Boot and PostgreSQL, featuring drag-and-drop upload, responsive gallery view, and full-size photo details with navigation.

## Features

- 📤 **Photo Upload**: Drag-and-drop or click to upload multiple photos
- 🖼️ **Gallery View**: Responsive grid layout for browsing uploaded photos  
- 🔍 **Photo Detail View**: Click any photo to view full-size with metadata and navigation
- 📊 **Metadata Display**: View file size, dimensions, aspect ratio, and upload timestamp
- ⬅️➡️ **Photo Navigation**: Previous/Next buttons to browse through photos
- ✅ **Validation**: File type and size validation (JPEG, PNG, GIF, WebP; max 10MB)
- 🗄️ **Database Storage**: Photo data stored as `bytea` values in PostgreSQL
- 🗑️ **Delete Photos**: Remove photos from both gallery and detail views
- 🎨 **Modern UI**: Clean, responsive design with Bootstrap 5

## Technology Stack

- **Framework**: Spring Boot 4.0.0 (Java 25)
- **Database**: PostgreSQL 17 (Azure Database for PostgreSQL Flexible Server in Azure; `postgres:17-alpine` locally)
- **Templating**: Thymeleaf
- **Build Tool**: Maven
- **Frontend**: Bootstrap 5.3.0, Vanilla JavaScript
- **Containerization**: Docker & Docker Compose

## Prerequisites

- Docker Desktop installed and running
- Docker Compose (included with Docker Desktop)

## Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Azure-Samples/PhotoAlbum-Java.git
   cd PhotoAlbum-Java
   ```

2. **Configure credentials and start the application**:
   ```bash
   # Copy the template and set strong, unique passwords in .env (git-ignored)
   cp .env.example .env

   # Use docker-compose directly (credentials are read from .env)
   docker-compose up --build -d
   ```

   This will:
   - Start a PostgreSQL 17 container
   - Build the Java Spring Boot application
   - Start the Photo Album application container
   - Automatically create the database schema using JPA/Hibernate

3. **Wait for services to start**:
   - PostgreSQL initialises in a few seconds on first run
   - Application will start once PostgreSQL is healthy

4. **Access the application**:
   - Open your browser and navigate to: **http://localhost:8080**
   - The application should be running and ready to use

## Services

## PostgreSQL Database
- **Image**: `postgres:17-alpine`
- **Ports**: 
  - `5432` (database) - mapped to host port 5432
- **Database**: `photoalbum` (override with `APP_DB_NAME`)
- **Schema**: `public`
- **Username/Password**: provided via the `APP_USER` / `APP_USER_PASSWORD` variables in `.env` (never hard-coded)

## Photo Album Java Application
- **Port**: `8080` (mapped to host port 8080)
- **Framework**: Spring Boot 4.0.0
- **Java Version**: 25
- **Database**: Connects to the PostgreSQL container
- **Photo Storage**: All photos stored as `bytea` values in the database (no file system storage)
- **UUID System**: Each photo gets a globally unique identifier for cache-busting

## Database Setup

The application uses Spring Data JPA with Hibernate for automatic schema management:

1. **Automatic Schema Creation**: Hibernate automatically creates tables and indexes
2. **Role Creation**: The PostgreSQL image creates a separate bootstrap administrator and database; `postgres-init/` creates the `photoalbum` application role from `.env` and makes it the database/schema owner without granting SUPERUSER
3. **No Manual Setup Required**: Everything is handled automatically

### Database Schema

The application creates the following table structure in PostgreSQL:

#### photos Table
- `id` (varchar(36), Primary Key, UUID Generated)
- `original_file_name` (varchar(255), Not Null)
- `stored_file_name` (varchar(255), Not Null)
- `file_path` (varchar(500), Nullable)
- `file_size` (bigint, Not Null)
- `mime_type` (varchar(50), Not Null)
- `uploaded_at` (timestamp, Not Null, Default CURRENT_TIMESTAMP)
- `width` (integer, Nullable)
- `height` (integer, Nullable)
- `photo_data` (bytea, Nullable)

#### Indexes
- `idx_photos_uploaded_at` (Index on `uploaded_at` for chronological queries)

#### UUID Generation
- **Java**: `UUID.randomUUID().toString()` generates unique identifiers
- **Benefits**: Eliminates browser caching issues, globally unique across databases
- **Format**: Standard UUID format (36 characters with hyphens)

## Storage Architecture

### Database `bytea` Storage (Current Implementation)
- **Photos**: Stored as `bytea` data directly in the database
- **Benefits**: 
  - No file system dependencies
  - ACID compliance for photo operations
  - Simplified backup and migration
  - Perfect for containerized deployments
- **Trade-offs**: Database size increases, but suitable for moderate photo volumes

## Azure deployment (passwordless)

In Azure the application runs on Azure Container Apps and connects to **Azure Database for
PostgreSQL Flexible Server** using a **user-assigned managed identity** — no password exists
anywhere.

- A Service Connector linker (`photoalbumdb`) injects `spring.datasource.url`,
  `spring.datasource.username`, `spring.datasource.azure.passwordless-enabled`,
  `spring.cloud.azure.credential.client-id` and
  `spring.cloud.azure.credential.managed-identity-enabled` at runtime.
- The injected JDBC URL must include
  `sslmode=require&authenticationPluginClassName=com.azure.identity.extensions.jdbc.postgresql.AzurePostgresqlAuthenticationPlugin`;
  do not replace it with a plain PostgreSQL URL.
- **Do not** set `SPRING_DATASOURCE_*` environment variables for the Azure deployment; they
  would override the injected configuration.
- The injected JDBC URL references
  `com.azure.identity.extensions.jdbc.postgresql.AzurePostgresqlAuthenticationPlugin`, which is
  supplied by the `com.azure.spring:spring-cloud-azure-starter-jdbc-postgresql` dependency in
  `pom.xml`. Removing that dependency still compiles but breaks the application at startup.
- To authenticate with a **service principal** instead of a managed identity, drop
  `spring.cloud.azure.credential.managed-identity-enabled` and set
  `spring.cloud.azure.profile.tenant-id`, `spring.cloud.azure.credential.client-id` and
  `spring.cloud.azure.credential.client-secret` (see the comments in
  `src/main/resources/application.properties`).

See `infra/` and `.github/modernize/env.md` for the provisioned resource names.

### Moving existing Oracle photo records

The application now stores photo bytes in PostgreSQL `photos.photo_data` (`bytea`).
For a one-time move from an existing Oracle database, use Ora2Pg from a secured
migration host; no Oracle endpoint or source credentials are stored in this
repository. Keep the application in maintenance mode while copying data so no
uploads are missed.

1. Let the application create the PostgreSQL schema, then stop application
   writes. Configure Ora2Pg outside the repository with the Oracle source
   connection and the PostgreSQL target details. Restrict access to that config
   because it may contain source credentials.
2. Configure Ora2Pg to export the existing `PHOTOS` rows (`TYPE COPY`) and map
   Oracle `PHOTO_DATA` BLOB values to PostgreSQL `bytea`. Preserve the existing
   columns (`ID`, `ORIGINAL_FILE_NAME`, `PHOTO_DATA`, `STORED_FILE_NAME`,
   `FILE_PATH`, `FILE_SIZE`, `MIME_TYPE`, `UPLOADED_AT`, `WIDTH`, `HEIGHT`);
   the target uses the lowercase names shown in the schema section above.
3. Review the generated SQL/data export for the expected row count and binary
   column handling, then load it into `photoalbum` using `psql` with the
   migration operator's authorized target credentials. Do not use the
   application's local database role for production data migration.
4. Compare source and target row counts and representative photo byte lengths,
   then smoke-test the gallery, detail view, image retrieval, navigation and
   deletion before reopening writes.

## Development

### Running Locally (without Docker)

1. **Install PostgreSQL 17** (or run only the `postgres-db` compose service)
2. **Create the database and role** (choose your own strong password; grant least
   privilege only — do NOT grant SUPERUSER):
   ```sql
   CREATE ROLE photoalbum LOGIN PASSWORD '<your-strong-password>';
   CREATE DATABASE photoalbum OWNER photoalbum;
   \connect photoalbum
   GRANT USAGE, CREATE ON SCHEMA public TO photoalbum;
   ```
3. **Provide local connection settings via environment variables** (do not
   hard-code them in `application.properties`). Activate the local `docker`
   profile, which reads the local-only password; Azure uses managed identity:
   ```bash
   export SPRING_DATASOURCE_URL="jdbc:postgresql://localhost:5432/photoalbum"
   export SPRING_DATASOURCE_USERNAME="photoalbum"
   export SPRING_DATASOURCE_PASSWORD="<your-strong-password>"
   export SPRING_PROFILES_ACTIVE="docker"
   ```
4. **Run the application**:
   ```bash
   mvn spring-boot:run -Dspring-boot.run.profiles=docker
   ```

### Building from Source

```bash
# Build the JAR file
mvn clean package

# Run the JAR file
java -jar target/photo-album-1.0.0.jar
```

## Troubleshooting

### PostgreSQL Database Issues

1. **PostgreSQL container won't start**:
   ```bash
   # Check container logs
   docker-compose logs postgres-db
   ```

2. **Database connection errors**:
   ```bash
   # Verify PostgreSQL is ready (credentials come from your .env values)
   docker exec -it photoalbum-postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1"'
   ```

3. **Permission errors**:
   ```bash
   # Check PostgreSQL init scripts ran
   docker-compose logs postgres-db | grep "init"
   ```

### Application Issues

1. **View application logs**:
   ```bash
   docker-compose logs photoalbum-java-app
   ```

2. **Rebuild application**:
   ```bash
   docker-compose up --build
   ```

3. **Reset database (nuclear option)**:
   ```bash
   docker-compose down -v
   docker-compose up --build
   ```

## Stopping the Application

```bash
# Stop services
docker-compose down

# Stop and remove all data (including database)
docker-compose down -v
```

## Performance Notes

- `bytea` storage in the database impacts performance at scale
- Suitable for development and small-scale deployments

## Project Structure

```
PhotoAlbum/
├── src/                             # Java source code
├── postgres-init/                   # PostgreSQL initialization scripts
├── infra/                           # Azure infrastructure (Bicep) and deploy scripts
├── docker-compose.yml               # PostgreSQL + Application services
├── Dockerfile                       # Application container build
├── pom.xml                          # Maven dependencies and build config
└── README.md                        # Project documentation
```

## Contributing

When contributing to this project:

- Follow Spring Boot best practices
- Maintain database compatibility
- Ensure UI/UX consistency
- Test both local Docker and Azure deployment scenarios
- Update documentation for any architectural changes
- Preserve UUID system integrity
- Add appropriate tests for new features

## License

This project is provided as-is for educational and demonstration purposes.
