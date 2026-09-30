# Modernization Plan: Photo Album on Azure

**Project**: Photo Album

---

## Technical Framework

- **Language**: Java 25, JavaScript
- **Framework**: Spring Boot 4.0.0
- **Build Tool**: Maven
- **Database**: Oracle Database Free (production), H2 (tests)
- **Key Dependencies**: Spring Data JPA, Hibernate, Thymeleaf, Spring Security, Oracle JDBC

---

## Overview

Migrate the existing Photo Album application to Azure without repeating the completed
Java or framework upgrade. The new architecture will:

- Move photo metadata and binary content from Oracle to Azure Database for PostgreSQL.
- Allow cloud-managed configuration of the application port and database credentials.
- Provision the Azure environment and deploy the application to Azure Container Apps.

Capture a baseline before changing the application, verify the migrated behavior,
remediate dependency CVEs, and deploy only after validation. The existing Dockerfile
still targets Java 8; deployment must use a runtime compatible with the current Java 25
build, without adding a separate framework-upgrade task.

---

## Migration Impact Summary

| Application | Original Service | New Azure Service | Authentication | Comments |
|-------------|------------------|-------------------|----------------|----------|
| Photo Album | Oracle Database | Azure PostgreSQL | Managed identity | Preserve photos and queries |
| Photo Album | Local Docker hosting | Azure Container Apps | Managed identity | Cloud-ready port and config |

---

## Infrastructure

**User requirements**: Provision Azure infrastructure for the Photo Album application
and deploy it. No subscription, region, environment, or cost constraints were supplied.

| Parameter | Value | Description |
|-----------|-------|-------------|
| IaC Tool | Bicep | Default for Azure Container Apps |
| Provision | Yes, during plan execution | Generate and apply IaC |
| Subscription | To be supplied | Do not embed identifiers or credentials in the plan |

**Proposed architecture**:

```text
Users → Azure Container Apps (Photo Album) → Azure Database for PostgreSQL
                     │
                     └→ Azure Container Registry (application image)
```

| Resource Type | Resource Name | SKU | Est. Monthly Cost | Purpose |
|---------------|---------------|-----|--------------------|---------|
| Resource group | To be chosen | N/A | Varies | Group app resources |
| Container Apps environment and app | To be chosen | To be chosen | To be estimated | Host application |
| Azure Container Registry | To be chosen | To be chosen | To be estimated | Host image |
| Azure Database for PostgreSQL | To be chosen | To be chosen | To be estimated | Store photos and metadata |

Costs and SKUs must be estimated and confirmed for the selected region and expected
usage before provisioning; no pricing lookup is available during plan creation.

---

## Open Questions & Questionnaire

- [x] Q: Provision new infrastructure? → A: Yes, explicitly requested.
- [x] Q: Include integration testing? → A: Yes, real mode with provisioned infrastructure (questionnaire default).
- [x] Q: Include security/CVE remediation? → A: Yes, mandatory plan task.
- [x] Q: Deployment target? → A: Azure Container Apps (default); containerization belongs to deployment.
- [ ] Which Azure subscription, region, environment, and budget should be used before provisioning?

The assessment's Java-version findings are obsolete after the completed upgrade.
The production password properties reference environment variables rather than
containing credentials; test-profile values are test-only. The remaining assessment
findings are mapped to tasks in `.metadata/tasks.json`.
