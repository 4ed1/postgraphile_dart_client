CREATE SCHEMA myapp;

CREATE ROLE web_anon nologin;
GRANT web_anon TO postgres;
GRANT USAGE ON SCHEMA myapp TO web_anon;

CREATE ROLE admin nologin;
GRANT admin TO postgres;
GRANT USAGE ON SCHEMA myapp TO admin;

CREATE role authenticator nologin;
GRANT authenticator TO postgres;
GRANT USAGE ON SCHEMA myapp TO authenticator;

CREATE FUNCTION current_user_id() RETURNS TEXT AS $$
  SELECT NULLIF(coalesce(current_setting('jwt.claims.user_id', TRUE), current_setting('request.jwt.claim.user_id', TRUE)), '')::TEXT;
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

CREATE TYPE myapp.jwt_token AS (
  user_id INTEGER,
  role TEXT
);

CREATE TABLE myapp.book (
  id SERIAL PRIMARY KEY,
  name TEXT
);
GRANT ALL ON myapp.book TO admin;
GRANT ALL ON myapp.book_id_seq TO admin;

-- group is a reserved keyword
CREATE TABLE myapp."group" (
  id SERIAL PRIMARY KEY,
  name TEXT
);
GRANT ALL ON myapp."group" TO admin;
GRANT ALL ON myapp.group_id_seq TO admin;

CREATE TABLE myapp.user (
  id SERIAL PRIMARY KEY,
  name TEXT,
  role NAME,
  password  TEXT,
  "group" INTEGER REFERENCES myapp."group"(id),
  current_book INTEGER REFERENCES myapp.book(id)
);
GRANT ALL ON myapp.user TO admin;
GRANT ALL ON myapp.user_id_seq TO admin, authenticator;
GRANT SELECT, INSERT ON myapp.user to authenticator;

CREATE TABLE myapp.book_choice (
  "group" INTEGER REFERENCES myapp."group"(id),
  book INTEGER REFERENCES myapp.book(id),
  PRIMARY KEY("group", book)
);
GRANT ALL ON myapp.book_choice TO admin;
