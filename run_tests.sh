#!/bin/sh
( ./node_modules/.bin/pouchdb-server --level-backend memdown -p 3052 & echo $$! > pouchdb-server.pid ) > /dev/null
# Wait for couch to be ready
while true; do if curl http://127.0.0.1:3052 > /dev/null 2>/dev/null; then break; else sleep 0.2; fi; done
( sleep 10 ; kill `cat pouchdb-server.pid` 2> /dev/null ) &
API_SECRET=1234 COUCH_GAMES_PORT_5984_TCP_ADDR=127.0.0.1 COUCH_GAMES_PORT_5984_TCP_PORT=3052 ./node_modules/.bin/mocha -b --recursive --compilers coffee:coffee-script/register tests | ./node_modules/.bin/bunyan -l ${BUNYAN_LEVEL}
kill `cat pouchdb-server.pid` || true
rm -f config.json
