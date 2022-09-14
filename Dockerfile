# Base image is one of Python official distributions.
FROM python:3.8.13-slim-buster


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

RUN apt update
RUN apt -y install \
	sudo \
	curl \
	install-info \
	git-all \
	gnupg \
	lsb-release

# Install PostgreSQL 14. Note that this block needs to be located
# after the env variables are specified, since it uses POSTGRES_DB,
# POSTGRES_USER and POSTGRES_PASSWORD to create the first user.
RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg && \
	echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
	apt -y update && \
	apt -y install postgresql-14

# Install nodejs.
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash && \
	apt -y install nodejs

# Download Google Cloud CLI installation script.
RUN mkdir /gcloud && \
	curl -sSL https://sdk.cloud.google.com | bash -s -- --install-dir=/gcloud --disable-prompts

# Copy local code to the container image.
ENV APP_HOME /app
WORKDIR $APP_HOME

# Handle requirements.txt first so that we don't need to re-install our
# python dependencies every time we rebuild the Dockerfile
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Set some variables and create gitpod user.
ENV PGDATA="/data/pgdata" PGSTATE="/data/run"
RUN useradd -l -u 33333 -G sudo -md /home/gitpod -s /bin/bash -p gitpod gitpod && \
	install -d -m 700 -o gitpod -g gitpod  $PGDATA $PGSTATE $PGSTATE/sockets

RUN printf '#!/bin/bash\npg_ctl -D $PGDATA -l $PGSTATE/log -o "-k $PGSTATE/sockets" start\n' > /usr/local/bin/pg_start && \
	printf '#!/bin/bash\npg_ctl -D $PGDATA -l $PGSTATE/log -o "-k ~/$PGSTATE/sockets" stop\n' > /usr/local/bin/pg_stop && \
	chmod 755 /usr/local/bin/pg_*

COPY . ./

USER gitpod

# Set some more variables and init the db.
ENV PATH="/usr/lib/postgresql/14/bin:$PATH"
RUN initdb -D $PGDATA
ENV DATABASE_URL="postgresql://gitpod@localhost"
ENV PGHOSTADDR="127.0.0.1"
