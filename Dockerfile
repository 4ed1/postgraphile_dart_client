FROM ubuntu:latest

RUN apt-get update && apt-get install -qy curl gnupg2

RUN curl -sL https://deb.nodesource.com/setup_11.x | bash - && apt-get install -qy nodejs

RUN apt-get update && \
  env DEBIAN_FRONTEND=noninteractive apt-get install -qy libdbd-pg-perl \
  postgresql-client \
  sqitch \
  postgresql \
  postgresql-contrib

WORKDIR /usr/src/postgraphile
COPY ./postgraphile/package*.json ./
RUN npm install

COPY ci/postgrest.conf /etc/postgrest.conf
ENV DATABASE_URL=postgres://postgres@localhost:5432/postgres \
  SCHEMA_NAME=myapp \
  JWT_SECRET=keI4eeng6Geesh0shaEQUAhx6bAiPh \
  DEFAULT_ROLE=web_anon \
  CORS=true \
  GRAPHIQL=true \
  NO_SECURITY=false

WORKDIR /usr/src/postgraphile
COPY ./postgraphile/main.js ./main.js

WORKDIR /usr/src/db-config
COPY ./ci/schema.sql ./
COPY ./ci/deploy.sh ./
CMD ["./deploy.sh"]

EXPOSE 3000
