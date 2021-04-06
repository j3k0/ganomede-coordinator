var url = require('url');
var pkg = require("./package.json");

var gameServers = function() {
    var e = process.env.GAME_SERVERS_URL;
    return e ? e.split(",") : [ "http://localhost:8080" ];
}

module.exports = {

  // legacy config
  port: +process.env.PORT || 8000,
  routePrefix: process.env.ROUTE_PREFIX || pkg.api,

  // unified config
  http: {
    port: +process.env.PORT || 8000,
    prefix: process.env.ROUTE_PREFIX || pkg.api,
  },

  couch: {
    serverUri: url.format({
      protocol: 'http',
      auth: process.env.COUCH_GAMES_PORT_5984_TCP_AUTH || undefined,
      hostname: process.env.COUCH_GAMES_PORT_5984_TCP_ADDR || 'localhost',
      port: +process.env.COUCH_GAMES_PORT_5984_TCP_PORT || 5984
    }),

    // This is database name. Default one is test database, so we won't
    // drop production data by accidentally running tests.
    name: process.env.COUCH_GAMES_DB_NAME || 'ganomede_games_test',
    designName: 'coordinator'
  },

  authdb: {
    host: process.env.REDIS_AUTH_PORT_6379_TCP_ADDR || 'localhost',
    port: +process.env.REDIS_AUTH_PORT_6379_TCP_PORT || 6379
  },

  apiSecret: process.env.API_SECRET,

  gameServers: gameServers()
};
