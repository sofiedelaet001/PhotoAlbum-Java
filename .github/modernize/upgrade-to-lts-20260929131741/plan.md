# Upgrade Plan: PhotoAlbum-Java (20260929132056)

- **Generated**: 2026-09-29 13:20:56 UTC
- **HEAD Branch**: main
- **HEAD Commit ID**: (working directory)

## Available Tools

**JDKs**
- JDK 8.0: Current project JDK (used for baseline, if available)
- JDK 21: **<TO_BE_INSTALLED>** (required for intermediate step 4)
- JDK 25: **<TO_BE_INSTALLED>** (required for final step 9)

**Build Tools**
- Maven 3.9+: **<TO_BE_INSTALLED>** (recommended for Java 21+ support; 3.8.x is EOL)
- Maven Wrapper: not present (will use system Maven after installation)

## Guidelines

> Note: You can add any specific guidelines or constraints for the upgrade process here if needed, bullet points are preferred.

- Migrate all javax.* imports to jakarta.* (Spring Boot 3.0+ requirement)
- Update Spring Security configuration to use new Lambda DSL (Spring Security 6.0+)
- Ensure compatibility with Java module system (Java 9+)
- Preserve all application functionality and behavior
- Maintain security controls throughout the upgrade

## Options

- Working branch: appmod/java-upgrade-20260929132056
- Run tests before and after the upgrade: true

## Upgrade Goals

- **Java**: 8 → 25
- **Spring Boot**: 2.7.18 → 4.0.0 (latest stable 4.x)
- **Spring Framework**: 5.3.x (via SB 2.7) → 7.x (via SB 4.0)
- **Jakarta EE**: Migrate javax.* → jakarta.* namespaces

## Technology Stack

| Technology/Dependency | Current | Min Compatible | Why Incompatible |
|----------------------|---------|----------------|------------------|
| Java | 8 | 25 | User requested |
| Spring Boot | 2.7.18 | 4.0.0 | User requested; 4.0+ requires Spring Framework 7.x |
| Spring Framework | 5.3.x | 7.x | Determined by Spring Boot 4.0 |
| Maven (recommended) | unknown | 3.9.0 | 3.8.x is EOL; 3.9+ recommended for Java 21+ |
| maven-compiler-plugin | 3.8.1 (via SB parent) | 3.11.0 | Recommended for better Java 21+ support |
| javax.persistence ⚠️ EOL | 2.2 (via Spring Boot) | N/A | Replaced by jakarta.persistence in Spring Boot 3.0+ |
| javax.validation ⚠️ EOL | 2.0 (via Spring Boot) | N/A | Replaced by jakarta.validation in Spring Boot 3.0+ |
| Hibernate | 5.6.x (via SB 2.7) | 6.x | Required by Spring Boot 3.0+ (uses jakarta.persistence) |
| Spring Data JPA | 2.7.x (via SB 2.7) | 3.x | Updated by Spring Boot 3.0+ |
| Commons IO | 2.11.0 | 2.11.0 | Already compatible |
| Oracle JDBC Driver (ojdbc8) | latest managed | 23.x+ | Should be updated to latest for Java 21+ |
| H2 Database (test) | managed by SB | 2.1.x | Update for Java 21+ compatibility |

## Derived Upgrades

| Dependency | Current | Target | Justification |
|-----------|---------|--------|--------------|
| Maven | 3.8.x (if available) | 3.9+ | Java 21+ support recommended; 3.8.x is EOL |
| maven-compiler-plugin | 3.8.1 (via parent) | 3.11+ | Better Java 21+ support; delegates to javac |
| maven-surefire-plugin | 2.22.x (via parent) | 3.0+ | Java 17+ module system improvements |
| Hibernate | 5.6.x (via SB 2.7) | 6.x (via SB 3.0+) | Spring Boot 3.0+ requires Hibernate 6.x with jakarta.persistence |
| Tomcat (embedded) | 9.x (via SB 2.7) | 10.x (via SB 3.0+) | Spring Boot 3.0+ uses jakarta.servlet (Tomcat 10.x) |
| Oracle JDBC | managed | latest 23.x+ | Enhanced Java 21+ support; ojdbc8 is legacy |

## Impact Analysis

### Subsection: Dependency Changes

| File | Dependency | Current | Action | Target | Reason |
|------|-----------|---------|--------|--------|--------|
| pom.xml | spring-boot-starter-parent | 2.7.18 | upgrade | 3.5.14 (intermediate) | Bridge to 4.0; Spring Boot 3.5 is stable LTS |
| pom.xml | spring-boot-starter-parent | 3.5.14 | upgrade | 4.0.0 | User requested final target |
| pom.xml | java.version property | 1.8 | upgrade | 21 (intermediate step 7) | Bridge to Java 25 |
| pom.xml | java.version property | 21 | upgrade | 25 | User requested final target |
| pom.xml | maven.compiler.source | 8 | upgrade | 21 (step 7) | Match java.version |
| pom.xml | maven.compiler.source | 21 | upgrade | 25 | User requested final target |
| pom.xml | maven.compiler.target | 8 | upgrade | 21 (step 7) | Match java.version |
| pom.xml | maven.compiler.target | 25 | upgrade | 25 | User requested final target |

### Subsection: Source Code Changes

| File | Location | Current | Required Change | Reason |
|------|----------|---------|----------------|--------|
| Photo.java | import line 3 | `import javax.persistence.*` | Replace with: `import jakarta.persistence.*` | Jakarta EE 9+ namespace |
| Photo.java | import lines 4-7 | `import javax.validation.constraints.*` | Replace with: `import jakarta.validation.constraints.*` | Jakarta EE 9+ namespace |
| PhotoServiceImpl.java | import lines 14-16 | `import javax.imageio.*` | No change (javax.imageio is in java.* namespace) | Not part of Jakarta EE |
| SecurityConfig.java | line 51 | `.csrf().disable()` | Replace with: `.csrf(csrf -> csrf.disable())` | Spring Security 6.0+ lambda DSL |
| SecurityConfig.java | line 54 | `.authorizeRequests()` | Replace with: `.authorizeHttpRequests(authz ->` | Spring Security 6.0+ API change |
| SecurityConfig.java | line 56 | `.antMatchers(HttpMethod.POST, ...)` | Replace with: `.requestMatchers(HttpMethod.POST, ...)` | Spring Security 6.0+ API change |
| SecurityConfig.java | lines 51-61 | Classic API with .and() chaining | Rewrite using lambda DSL | Spring Security 6.0+ requires lambda-based configuration |

### Subsection: Configuration Changes

No application.properties / application.yml changes needed for the migration. All deprecated properties are handled by Spring Boot's auto-migration.

### Subsection: CI/CD Changes

| File | Location | Current | Required Change |
|------|----------|---------|----------------|
| Dockerfile | line 1 (base image) | `openjdk:8-...` or similar | Change to: `openjdk:25-...` or `eclipse-temurin:25-...` |
| Dockerfile | line 12 (Maven command) | May need Maven 3.9+ | Update Maven base image or include Maven installation |

### Subsection: Risks & Warnings

- **Spring Security DSL rewrite (SecurityConfig.java)**: Non-trivial. Spring Security 6.0 requires lambda-based method references. **Mitigation**: Verify security behavior with existing integration tests after rewrite; add smoke tests if none cover authentication.
- **Jakarta EE migration (javax.* → jakarta.*)**: Automatically handled by Spring Boot 3.0+ managed dependencies. Source code imports must be updated manually. **Mitigation**: Verify all javax.* imports in source files are replaced.
- **Java 21+ module system**: No reflection into internal JDK packages detected. **Mitigation**: Monitor for runtime errors; apply `--add-opens` if needed.
- **Build tool availability**: Maven and JDKs may not be installed. **Mitigation**: Steps 1-2 handle installation; enter degraded mode if installation fails.

## Upgrade Steps

- **Step 1: Setup Environment**
  - **Rationale**: Verify and install required JDKs (21, 25) and Maven 3.9+.
  - **Changes to Make**: Install JDK 21, JDK 25, and Maven 3.9+ if not already available.
  - **Verification**: Command: `#list-jdks` and `#list-mavens` succeed. Expected Result: All required tools available.

- **Step 2: Setup Baseline**
  - **Rationale**: Establish baseline compilation and test pass rate using current JDK 8 and Spring Boot 2.7.18.
  - **Changes to Make**: None. Compile and test with current setup.
  - **Verification**: Command: `mvn clean compile test-compile -q && mvn clean test -q`. Expected Result: Baseline compilation SUCCESS; note test pass rate.

- **Step 3: Upgrade to Spring Boot 3.5.14 (Intermediate)**
  - **Rationale**: Spring Boot 3.5.14 is the final stable 3.x release and a proven bridge to 4.0. It requires Java 11+ and migrates all javax.* to jakarta.*.
  - **Changes to Make**: Upgrade pom.xml: `spring-boot-starter-parent 2.7.18 → 3.5.14`
  - **Verification**: Command: `mvn clean test-compile -q`. Expected Result: Compilation SUCCESS.

- **Step 4: Upgrade to Java 11 (Intermediate)**
  - **Rationale**: Java 11 is required by Spring Boot 3.x and is an LTS version.
  - **Changes to Make**: pom.xml: `<java.version>1.8 → 11</java.version>`, compiler source/target to 11.
  - **Verification**: Command: `mvn clean test-compile -q`. Expected Result: Compilation SUCCESS with Java 11.

- **Step 5: Migrate javax.* to jakarta.* in Source Code**
  - **Rationale**: Update all javax.persistence and javax.validation imports in source files.
  - **Changes to Make**: Photo.java: Replace `javax.persistence` and `javax.validation` imports with jakarta equivalents.
  - **Verification**: Command: `mvn clean test-compile -q`. Expected Result: Compilation SUCCESS.

- **Step 6: Update Spring Security Configuration (SecurityConfig.java)**
  - **Rationale**: Spring Security 6.0 requires lambda DSL for configuration.
  - **Changes to Make**: Rewrite `securityFilterChain` method to use new lambda DSL (csrf, authorizeHttpRequests, requestMatchers).
  - **Verification**: Command: `mvn clean test-compile -q && mvn clean test -q`. Expected Result: Compilation SUCCESS; all tests PASS.

- **Step 7: Upgrade to Java 21 (Intermediate)**
  - **Rationale**: Java 21 is an LTS version and required for the next step (Java 25).
  - **Changes to Make**: pom.xml: `<java.version>11 → 21</java.version>`, compiler source/target to 21.
  - **Verification**: Command: `mvn clean test-compile -q`. Expected Result: Compilation SUCCESS with Java 21.

- **Step 8: Upgrade to Spring Boot 4.0.0 (Final Target)**
  - **Rationale**: Spring Boot 4.0 upgrades Spring Framework to 7.x.
  - **Changes to Make**: pom.xml: `spring-boot-starter-parent 3.5.14 → 4.0.0`
  - **Verification**: Command: `mvn clean test-compile -q && mvn clean test -q`. Expected Result: Compilation SUCCESS; all tests PASS.

- **Step 9: Upgrade to Java 25 (Final Target)**
  - **Rationale**: User's final target.
  - **Changes to Make**: pom.xml: `<java.version>21 → 25</java.version>`, compiler source/target to 25.
  - **Verification**: Command: `mvn clean test-compile -q`. Expected Result: Compilation SUCCESS with Java 25.

- **Step 10: CVE Validation & Fix**
  - **Rationale**: Scan all direct dependencies for known vulnerabilities.
  - **Changes to Make**: Extract direct dependencies, scan with `#validate-cves-for-java`, upgrade flagged dependencies.
  - **Verification**: Command: `#validate-cves-for-java` succeeds; no CVEs remain. Expected Result: All CVEs fixed or documented as unavailable.

- **Step 11: Final Validation**
  - **Rationale**: Verify all upgrade goals are met, all tests pass, and application is ready for deployment.
  - **Changes to Make**: None. Verify only.
  - **Verification**: Command: `mvn clean verify -q`. Expected Result: Compilation SUCCESS; 100% test pass rate; no deprecation warnings.
