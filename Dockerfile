# syntax=docker/dockerfile:1.7

##########
# Build stage
##########
FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /app

# Copy only pom first to leverage layer cache
COPY pom.xml .

# Pre-fetch dependencies (uses a BuildKit cache mount)
RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -DskipTests dependency:go-offline

# Now add sources
COPY src ./src

# Build the jar (still using the cache)
RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -DskipTests clean package

##########
# Runtime stage
##########
FROM eclipse-temurin:21-jre
# (Optionally: use a smaller base, e.g. eclipse-temurin:21-jre-alpine if available)

# OCI labels (optional but nice)
LABEL org.opencontainers.image.title="simple-java-maven-app" \
      org.opencontainers.image.description="Sample Java app, built with Maven" \
      org.opencontainers.image.source="https://github.com/<you>/<repo>" \
      org.opencontainers.image.licenses="Apache-2.0"

WORKDIR /app

# Copy the built artifact
# If your jar has a fixed name, prefer copying it explicitly.
COPY --from=build /app/target/*.jar /app/app.jar

# Run as non-root for safety
RUN adduser --system --home /nonroot --shell /sbin/nologin appuser
USER appuser

# Optional: expose if your app listens on a port (change if needed)
# EXPOSE 8080

# Simple healthcheck (adjust port/path to your app)
# HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
#   CMD wget -qO- http://127.0.0.1:8080/actuator/health || exit 1

# Allow runtime JVM flags via JAVA_OPTS
ENV JAVA_OPTS=""

ENTRYPOINT ["sh","-c","exec java $JAVA_OPTS -jar /app/app.jar"]
