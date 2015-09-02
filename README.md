Coordinator
-----------

Manage the users games list.

Relations
---------

The coordinator module will:
 * create game IDs
 * maintain the list of ongoing games for a user
 * assign a game to a server URL

Configuration
-------------

 * `COUCH_GAMES_PORT_5984_TCP_ADDR` - IP of the games couchdb
 * `COUCH_GAMES_PORT_5984_TCP_PORT` - Port of the games couchdb
 * `REDIS_AUTH_PORT_6379_TCP_ADDR` - IP of the AuthDB redis
 * `REDIS_AUTH_PORT_6379_TCP_PORT` - Port of the AuthDB redis
 * `NOTIFICATIONS_PORT_8080_TCP_ADDR` - IP of the notifications service
 * `NOTIFICATIONS_PORT_8080_TCP_PORT` - Port of the notifications service
 * `GAME_SERVERS_URL` - Comma separated list of servers
 * `API_SECRET` - Give access to private APIs

API
---

All requests made to the coordinator API require an auth token, passed in the request URL.

# Single Game [/coordinator/v1/auth/:token/:type/:version/games/:id]

    + Parameters
        + token (string) ... User authentication token
        + id (string) ... ID of the game

## Retrieve a game state [GET]

### response [200] OK

    {
        "id": "ab12345789",
        "type": "triominos/v1",
        "players": [ "some_username_1", "some_username_2" ],
        "status": "active",
        "url": "http://ganomede.fovea.cc:43301",
        "gameOverData": { ... only if status is "gameover" ... }
        "waiting": [ "some_username_2" ] ... only if status is "inactive"
    }

Possible `status`:

 * `inactive`
 * `active`
 * `gameover`

When status is `inactive`, `waiting` will contains the list of username that didn't activate the game.

# Single Game Join [/coordinator/v1/auth/:token/games/:id/join]

## Edit a game [POST]

### response [200] OK

    {
        "id": "ab12345789",
        "type": "triominos/v1",
        "players": [ "some_username_1", "some_username_2" ],
        "status": "inactive",
        "url": "http://ganomede.fovea.cc:43301",
        "waiting": [ "some_username_2" ] ... only if status is "inactive"
    }

### response [403] Forbidden

### Note

 * This is only allowed for inactive games, when called by a "waiting" user.
    * Will reply with status 403 otherwise.
 * `status` will change to `active` when there is no more waiting players.
 * [a notification](https://github.com/j3k0/ganomede-notifications/blob/master/api-docs/coordinator.md) will be sent to other active players (that aren't in the waiting list)

# Single Game Leave [/coordinator/v1/auth/:token/games/:id/leave]

## Edit a game [POST]

### body (application/json)

(optional)

    {
        "reason": "resign"
    }

### response [200] OK

    {
        "id": "ab12345789",
        "type": "triominos/v1",
        "players": [ "some_username_1", "some_username_2" ],
        "status": "inactive",
        "url": "http://ganomede.fovea.cc:43301",
        "waiting": [ "some_username_2" ] ... only if status is "inactive"
    }

### response [403] Forbidden

### Note

 * This is only allowed when called by a non waiting user.
    * Will reply with status 403 otherwise.
 * `status` will change to `inactive`
 * [a notification](https://github.com/j3k0/ganomede-notifications/blob/master/api-docs/coordinator.md) will be sent to other active players.

# Single Game Over [/coordinator/v1/auth/:token/games/:id/gameover]

## Edit a game [POST]

### response [200] OK

    {
        "gameOverData": { ... }
    }

### response [403] Forbidden

### Note

 * This is only allowed when called by a non waiting user.
    * Will reply with status 403 otherwise.
 * `status` will change to `inactive`

# Active Games Collection [/coordinator/v1/auth/:token/:type/:version/active-games]

    + Parameters
        + token (string) ... User authentication token

## List games [GET]

List all the "active" games of the authenticated player.

### response [200] OK

    [{
        "id": "1234",
        "type": "triominos/v1",
        "players": [ "some_username", "other_username" ]
    }, {
        "id": "1235",
        "type": "triominos/v1",
        "players": [ "some_username", "amigo" ],
    }]

# Inactive Games Collection [/coordinator/v1/auth/:token/:type/:version/games]

    + Parameters
        + token (string) ... User authentication token

## Create a game [POST]

### body (application/json)

    {
        "players": [ "some_username_1", "some_username_2" ]
    }

### response [200] OK

    {
        "id": "1234",
        "type": "triominos/v1",
        "players": [ "some_username", "other_username" ],
        "status": "inactive",
        "url": "http://ganomede.fovea.cc:43301"
    }

### design notes

Only when status set to "active", the game will appear in the games collection of both player.

Until then, it's waiting for activation... Hopefully it should be listed in the players' invitations.

Inactive games will have an expiry date of 1 month.

# Changes [/coordinator/v1/gameover]

## Listen for gameover [GET] - private

    + Parameters
        + secret (string) ... API secret code opening access to this call
        + since (string) ... Last sequence number known of

### response [200] OK

    {
        "result": [{
            "seq":26,
            "id": "1234",
            "type": "triominos/v1",
            "players": [ "some_username", "other_username" ],
            "status": "gameover",
            "gameOverData": { ... }
        }, {
            "seq":33,
            "id": "1236",
            "type": "triominos/v1",
            "players": [ "some_username", "other_username" ],
            "status": "gameover",
            "gameOverData": { ... }
        }],
        "last_seq":39
    }

 * `seq`: The update sequence number.
 * `id`: The document ID.
 * `changes`: An array of fields, which by default includes the document’s revision ID, but can also include information about document conflicts and other things.
