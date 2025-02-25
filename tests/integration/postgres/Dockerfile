ARG PG_VERSION

# Use the official PostgreSQL image as a base
FROM postgres:$PG_VERSION

ARG PG_VERSION
# Install pglogical dependencies and pglogical itself
RUN apt-get update && apt-get install -y \
    postgresql-$PG_VERSION-pglogical \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Expose the default PostgreSQL port
EXPOSE 5432

# Set the default command to start PostgreSQL
CMD ["postgres"]
