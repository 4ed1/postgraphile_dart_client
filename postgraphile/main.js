const express = require("express");
const { postgraphile } = require("postgraphile");

const app = express();

app.use(
  postgraphile(process.env.DATABASE_URL, process.env.SCHEMA_NAME, {
    simpleCollections: 'both',
    jwtPgTypeIdentifier: "myapp.jwt_token",
    jwtSecret: process.env.JWT_SECRET,
    pgDefaultRole: process.env.DEFAULT_ROLE,
    jwtVerifyOptions: {audience: null},
    ignoreRBAC: process.env.NO_SECURITY !== "false",
    enableCors: process.env.CORS === "true",
    dynamicJson: true,
    graphileBuildOptions: {
      connectionFilterRelations: true,
    },
    graphiql: process.env.GRAPHIQL === 'true',
    watchPg: true,
  })
);

var port = process.env.PORT || 5000;
console.log('Starting postgraphile on port', port)
app.listen(port);
