# Base image is one of Python official distributions.
FROM python:3.8.13-slim-buster

# Update libraries and install sudo.
RUN apt update
RUN apt -y install sudo

# Install curl.
RUN sudo apt install -y curl

# Install git.
RUN sudo apt install install-info
RUN sudo apt install -y git-all

# Install nodejs.
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
RUN sudo apt install -y nodejs

# Download Google Cloud CLI installation script.
RUN mkdir -p /tmp/google-cloud-download
RUN curl -sSL https://sdk.cloud.google.com > /tmp/google-cloud-download/install.sh

# Install Google Cloud CLI.
RUN mkdir -p /gcloud
RUN bash /tmp/google-cloud-download/install.sh --install-dir=/gcloud --disable-prompts

# Copy local code to the container image.
ENV APP_HOME /app
WORKDIR $APP_HOME
COPY . ./

# Install production dependencies.
RUN pip install --no-cache-dir -r requirements.txt

# Set some variables and create gitpod user.
ENV PGWORKSPACE="/workspace/.pgsql"
ENV PGDATA="$PGWORKSPACE/data"
RUN sudo mkdir -p $PGDATA
RUN useradd -l -u 33333 -G sudo -md /home/gitpod -s /bin/bash -p gitpod gitpod
RUN sudo chown gitpod $PGWORKSPACE -R

# Declare Django env variables.
ENV DJANGO_DEBUG=True
ENV DJANGO_DB_ENGINE=django.db.backends.postgresql_psycopg2

# Declare Postgres env variables. Note that these variables
# cannot be renamed since they are used by Postgres.
# https://www.postgresql.org/docs/current/libpq-envars.html
ENV PGDATABASE=postgres
ENV PGUSER=gitpod
ENV PGPASSWORD=gitpod
ENV PGHOST=localhost
ENV PGPORT=5432

# Install PostgreSQL 14. Note that this block needs to be located
# after the env variables are specified, since it uses POSTGRES_DB,
# POSTGRES_USER and POSTGRES_PASSWORD to create the first user.
RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc|sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
RUN sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
RUN sudo apt -y update
RUN sudo apt -y install postgresql-14

USER gitpod

# Set some more variables and init the db.
ENV PATH="/usr/lib/postgresql/14/bin:$PATH"
RUN mkdir -p ~/.pg_ctl/bin ~/.pg_ctl/sockets
RUN initdb -D $PGDATA
RUN printf '#!/bin/bash\npg_ctl -D $PGDATA -l ~/.pg_ctl/log -o "-k ~/.pg_ctl/sockets" start\n' > ~/.pg_ctl/bin/pg_start
RUN printf '#!/bin/bash\npg_ctl -D $PGDATA -l ~/.pg_ctl/log -o "-k ~/.pg_ctl/sockets" stop\n' > ~/.pg_ctl/bin/pg_stop
RUN chmod +x ~/.pg_ctl/bin/*
ENV PATH="$HOME/.pg_ctl/bin:$PATH"
ENV DATABASE_URL="postgresql://gitpod@localhost"
ENV PGHOSTADDR="127.0.0.1"
