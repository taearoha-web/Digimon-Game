# Toon Tale online play: protocol and client API

Real players who are signed in (the account system, `hosting/accounts`) meet in the
same world: they see each other, chat, party up, fight the same monsters, trade, duel
and go to the guild war together. Everything else (AI world players, offline play)
keeps working; when the connection drops the game carries on alone.

Free tier only: one Cloudflare Worker with one Durable Object (`WorldRoom`, SQLite
backed, WebSocket Hibernation API), next to the existing D1 account database.

## Transport

- `GET /api/online/ws` with `Upgrade: websocket`, same origin as the game, so the
  `__Host-toon_session` cookie goes along. The Worker checks the session in D1
  (`currentSession` in `hosting/accounts/server/accounts.js`); no session: 401.
  It then forwards the request to the Durable Object named `world`
  (`env.WORLD.idFromName("world")`) with the headers `x-toon-user-id` and
  `x-toon-username`. One room holds everyone (a few dozen players at most).
- Frames are JSON text: `{"t": "<type>", ...fields}`. Unknown types are ignored on
  both sides (forward compatible).
- One socket per account. A second socket of the same account replaces the first
  (the old one gets `{"t":"kicked","reason":"elsewhere"}` and is closed).
- Limits enforced by the server: frame <= 8 KB; at most 30 frames a second per socket
  (excess dropped silently); chat text trimmed to 120 characters; names come from the
  account, never from the client.
- Client sends `state` at most 8 times a second (5 on phones), only when it changed,
  plus once every 2 s as a heartbeat. Server drops a socket silent for 30 s.

## Player identity

`id` is the account user id (string). `name` is the character name chosen in game
(client supplied, trimmed to 16 chars, shown with the account username as fallback);
`user` is the account username (server supplied, trusted).

## Client -> server

| t | fields | meaning |
|---|---|---|
| `hello` | `name, cls, level, stars, look, zone, pos:[x,y,z], yaw, hp, max_hp, mount` | first frame after open; `look` = the character's appearance dict (class, gear ids, colours, wings, plus levels) exactly as the game builds a FieldPlayer look |
| `state` | `pos, yaw, anim, hp, max_hp, zone, mount` | movement; `anim` is "idle", "run", "attack", "skill:<id>", "dead" |
| `look` | `look, level, stars` | gear / appearance changed |
| `chat` | `ch:"world"\|"party"\|"whisper", text, to?` | `to` = target id for whisper |
| `who` | | ask for the full player list |
| `party_invite` | `to` | |
| `party_answer` | `from, ok:bool` | |
| `party_leave` | | |
| `party_kick` | `who` | leader only |
| `ent_snap` | `zone, ents:[[eid, x, z, yaw, hp, max_hp, flags]]` | zone host only, 4 per second: the shared monsters / fighters (see Shared combat) |
| `ent_hit` | `zone, eid, dmg, crit, skill?` | a party member hit a shared entity; relayed to the host |
| `pet_act` | `zone, k, e, p:[x,z]` | my own pet attacked (`k` "a") or cast skill `k` at shared entity `e` (0 none), hit point `p`; a picture for the others, never damage (see Pets) |
| `ent_event` | `zone, eid, ev, data` | host only: "spawn", "dead", "cast", "phase", "aggro" ... relayed to the players the host serves in that zone |
| `wp_snap` | `zone, ps:[[index, x, z, yaw, anim, flags]]` | zone host only, 4 per second: the AI world players (see Shared world) |
| `wp_event` | `zone, index, ev, data` | zone host only: "skill", "bubble", "leave" (see Shared world) |
| `ai_chat` | `lines:[{ch:"world", speaker, text, color?, index?}]` | world host only: the AI world-channel chat (see Shared world) |
| `trade_req` | `to` | |
| `trade_answer` | `from, ok` | |
| `trade_offer` | `items:[item dict], gold` | replaces my offer; unlocks both sides |
| `trade_lock` | | |
| `trade_confirm` | | both locked, both confirm -> server sends `trade_done` |
| `trade_cancel` | | |
| `duel_req` | `to` | |
| `duel_answer` | `from, ok` | |
| `pvp_hit` | `to, dmg, crit, skill?, fx?` | attacker-computed raw damage; the victim applies its own defence |
| `duel_over` | `loser` | sent by the side that fell |
| `gw_invite` | | party leader asks the party into the guild war (same match) |
| `gw_answer` | `ok` | |
| `gw_start` | `seed, plan` | leader (host) starts; relayed to accepted members |
| `stall_list` | `lots:[{lot, item, price}]` | publish my stall's current lots (PlayerStall) for real players; sent on connect and on every change |
| `stall_view` | `seller` | ask for a real player's stall |
| `stall_buy` | `seller, lot, price` | buy a lot (the buyer has the gold; it is taken on `stall_bought`) |
| `stall_sold` | `to, lot, item, price` | seller's answer: the lot is gone from my stall and I got the gold |
| `stall_refuse` | `to, lot` | seller's answer: already sold / unlisted |

## Server -> client

| t | fields |
|---|---|
| `welcome` | `you:{id,user}`, `players:[player]`, `party` (or null) |
| `join` | `player` = `{id, user, name, cls, level, stars, look, zone, pos, yaw, hp, max_hp, mount, party}` |
| `leave` | `id` |
| `state` | `id` + the state fields |
| `look` | `id, look, level, stars` |
| `chat` | `ch, from, user, name, text, to?` (whisper: only sender and target get it) |
| `players` | `players:[player]` (answer to `who`) |
| `party_invite` | `from, name` |
| `party` | `party:{id, leader, members:[id], away:[id]}` or `party:null` (sent to every member on any change); `away` = members whose connection dropped and who keep their place for the grace (below) |
| `host` | `zone, id` - who simulates the shared entities of my zone (open zone: everyone there; instanced zone: my party there); null: nobody shares, play alone |
| `whost` | `id` - the world host: whose game makes the AI world chat (null: nobody has said hello yet) |
| `ent_snap` / `ent_event` | relayed from the host, plus `from` |
| `ent_hit` | relayed to the host, plus `from` |
| `pet_act` | `from, zone, k, e, p` - another player's pet attacked / cast (see Pets) |
| `wp_snap` / `wp_event` | relayed from the zone host, plus `from` |
| `ai_chat` | relayed from the world host, plus `from` |
| `trade_req` / `trade_answer` / `trade_offer` / `trade_lock` / `trade_confirm` / `trade_cancel` | relayed with `from`; the server keeps the trade session state |
| `trade_done` | `give:{items,gold}, get:{items,gold}` - apply it: remove `give`, add `get` |
| `duel_req` / `duel_answer` / `pvp_hit` / `duel_over` | relayed with `from` |
| `gw_invite` / `gw_answer` / `gw_start` | relayed with `from` within the party |
| `stall` | `seller, lots` (answer to `stall_view`; also pushed to viewers when the seller re-publishes) |
| `stall_buy` | relayed to the seller with `from` |
| `stall_bought` | `seller, lot, item, price` to the buyer (from the seller's `stall_sold`): pay `price`, add `item` |
| `stall_refuse` | relayed to the buyer with `from` |
| `error` | `code, text` (Thai, shown to the player) |
| `kicked` | `reason` |

## Server behaviour in detail

What the server (`hosting/worker/online/room.mjs`) does where the tables above leave a
choice. The wire format is the one above; a few frames carry an extra field, which
clients may ignore.

- **Order.** `welcome` comes as soon as the socket opens, before the client's `hello`;
  its `players` (and `players` from `who`) never include yourself. Frames other than
  `hello` / `who` sent before `hello` are ignored. `join`, `state` and `look` are not
  echoed to the sender. `join` is sent again when a player sends `hello` again
  (treat it as an update).
- **`state` goes to everyone online**, whatever the zone; clients filter by `zone`.
- **Chat echo.** Every chat line, world and party included, comes back to its sender
  too: show chat lines from the server only. Whisper to someone not online:
  `error not_online`; party chat without a party: `error no_party`.
- **Party.** Any member may invite (the party fills at 5); only the leader kicks. The
  inviter gets `party_answer {from, ok}` (relayed) for a yes and a no. Invites, trade and
  duel requests expire after 60 s. A party left with one member ends (`party: null`).
  When the leader leaves or drops, the next connected member leads. A dropped
  connection (phone locked, app switched, network blip, idle drop, the room restarting)
  does **not** leave the party: the member is listed in `away` for 15 minutes
  (`PARTY_GRACE_MS`) and is back in the party as soon as the same account reconnects
  (its `welcome` has the party, the others get `party` with it out of `away`). Only
  `party_leave`, a kick or the grace running out remove a member. The parties are also
  kept in the Durable Object's storage, so they survive a deploy. A second socket of the
  same account (`kicked` on the old one) keeps the party and the player's place.
- **Zone host.** Open zones (every zone except `tower`, `pvp`, `guildwar`, `arena`, `raid`, the
  instanced ones; `INSTANCED_ZONES` in room.mjs) have one host for every connected player
  in that zone (with a hello), party or not: the one that arrived in the zone first
  (re-elected when it changes zone, drops or goes away; a party or its leader arriving
  later does not take over). In an instanced zone the host is chosen among the party
  members in that zone: the leader when there, else the member who arrived first; a player
  without a party is alone there. `host {zone, id}` is sent to a player whenever its
  (zone, host) pair changes: on its first `hello`, when it changes zone, when its zone's
  host changes, and with `id: null` while fewer than two players share it (play alone);
  every player gets `host` now, not only party members. Joining or leaving a party only
  sends `host` when it changes something (instanced zones).
- **Relays from the zone host.** `ent_snap` / `ent_event` / `wp_snap` / `wp_event` are
  relayed only from the host of the sender's current zone, to every other player it
  serves (everyone in that open zone; the party members in that instanced zone), never to
  another zone; frames from anyone else, or with a `zone` that is not the sender's current
  zone, are dropped. `ent_hit` from any player the host serves goes to the host only; it
  is dropped when nobody else hosts the sender's zone (or the `zone` is not the sender's).
  The payloads are relayed as they are (8 KB frame limit), with `from`.
- **World host.** `whost {id}`: the connected player with a hello that has been online
  the longest (a second socket of the same account keeps the account's time; a reconnect
  after a drop starts anew). Every socket gets `whost` right after `welcome` (`id: null`
  while nobody has said hello) and again whenever it changes (the first hello in an empty
  room, the world host dropping, going idle). `ai_chat` from anyone but the world host is
  dropped; from the world host it goes to everyone else (whatever the zone) with `from`.
  Only the first 8 entries of `lines` are read; an entry that is not an object, has a
  `ch` other than "world" or an empty `text` is left out; `text` is cut to 200
  characters, `speaker` to 24, `color` is kept when it is a string (cut to 16) or
  `[r, g, b]` / `[r, g, b, a]` numbers, `index` when it is an integer >= 0; `ch` is always
  "world" in the relayed line. A frame with no line left is dropped.
- **Trade.** A player in a trade or a duel is busy (`error busy`). `trade_done` also
  carries `with` (the other player's id). A disconnect (or a second socket) sends the
  partner `trade_cancel` with `from` = the player who left.
- **Duel.** `pvp_hit` is relayed only when `to` is the sender's accepted duel opponent.
  `duel_over` is relayed with `loser` = the sender (whatever it wrote). If a duelist
  drops, the other gets `duel_over {from, loser}` with the dropped player as loser.
- **Guild war.** `gw_invite` (leader only) goes to every other member; `gw_answer` goes to
  every other member (leader included); `gw_start` (leader only) goes to the members who
  answered yes since the last `gw_invite`.
- **Stalls.** `stall_list` with no valid lots closes the stall. `stall` answers
  `stall_view` with `lots: []` for a player without a stall. `stall_buy` to a player
  without a published stall: `error no_stall`; the relayed `stall_buy` also carries
  `seller`. `stall_sold` / `stall_refuse` are only accepted for an open `stall_buy` of
  that buyer and lot (open for 60 s), and `stall_bought.price` is the price the buyer
  sent in `stall_buy`. When a seller drops, its viewers of the last 5 minutes get
  `stall {seller, lots: []}` and its open purchases get `stall_refuse`.
- **Limits.** A frame over 8 KB gets `error too_large` and is dropped; frames past 30 in
  a second, bad JSON and unknown types are dropped silently. Every frame counts as a
  sign of life; a socket silent for 30 s is closed with code 4001 (no `kicked`; reconnect
  as usual). `kicked` is followed by close code 4000; do not reconnect by itself after it.
- **`error` codes:** `not_online`, `self`, `no_party`, `party_full`, `in_party`,
  `same_party`, `not_leader`, `no_invite`, `no_request`, `busy`, `no_trade`,
  `not_locked`, `no_stall`, `too_large`; `text` is Thai, ready to show.
- **Hibernation.** The room sleeps when nobody sends anything and wakes up with the
  same sockets, players, parties, hosts and stalls (positions come back with the next
  `state`; a very large `look` or stall may need the client's next `look` /
  `stall_list`). The zone hosts are rebuilt from the players' zones and arrival order,
  the world host from how long each has been online; `host` / `whost` are resent only to
  players whose host changed (a player whose socket did not survive the sleep is gone,
  so its zone or the world may get a new host). Trades, duels, guild-war invites and open requests do not survive a
  sleep; with the 2 s heartbeat a room with players in it does not sleep.
- `GET /api/online/status` (no sign-in) answers `{"online": <sockets connected>}`.

## Shared combat (party only)

(v1. Since v2 this party scope applies to the instanced zones only; open zones share
with everyone in them, see "Shared world (zone-wide, v2)" below.)

Players who are not in a party share nothing: each sees the other walk and chat, but
fights its own monsters (no stealing kills, no griefing). Players in the same party and
the same zone share the monsters:

- The server names a **host** per (party, zone): the leader when present, else the
  member who arrived first. It changes when the host leaves the zone or drops.
- The host's game runs the monsters as today and sends `ent_snap` 4 times a second
  plus `ent_event` for spawns, deaths, casts and boss phases. `eid` is the host's own
  stable id for the entity (an int it hands out at spawn).
- The other members do not spawn monsters in that zone; they build "mirror" entities
  from the snapshots (same model, interpolated movement, HP bar) and send `ent_hit`
  for every hit they land. The host applies it as `Mob.take_hit(dmg, crit, color,
  remote_player_node)`, so the threat system (`Mob.add_threat`) counts real players
  too and monsters chase whoever hits hardest.
- Monster attacks: the host resolves them against whatever it targets; when the target
  is a remote player the host sends `ent_event` `{ev:"hit", data:{to, dmg}}` and that
  player's game applies the damage (`Hero.take_damage`).
- A kill: the host sends `ent_event` `{ev:"dead", data:{killer, share:{id:damage}}}`.
  Every member in the zone rolls its own loot and EXP locally from that monster as if
  it had killed it (each gets its own drop - no loot fights).
- The same mechanism runs the guild war together: the party leader hosts the match,
  the AI fighters are shared entities, members fight on the leader's side.

## Client API (Godot autoload `Online`, `systems/online/online.gd`)

```gdscript
signal connected
signal disconnected
signal message(type: String, data: Dictionary)   # every server frame, after Online's own handling
signal player_joined(id: String)
signal player_left(id: String)
signal party_changed
signal host_changed(zone: StringName)

func is_online() -> bool
func my_id() -> String
func send(type: String, data := {}) -> void       # no-op when offline
func players() -> Dictionary                      # id -> player dict (latest)
func players_in_zone(zone: StringName) -> Array   # [player dict]
func party() -> Dictionary                         # {} when none
func in_party() -> bool
func party_members_in_zone(zone: StringName) -> Array  # ids, me excluded
func zone_host(zone: StringName) -> String         # "" when nobody shares
func is_zone_host(zone: StringName) -> bool
func is_mirror_zone(zone: StringName) -> bool      # someone else hosts (party or not): do not spawn monsters
func zone_members(zone: StringName) -> Array       # ids of the other real players in that zone, party or not
func serves(zone: StringName) -> Array             # whom that zone's host serves: zone_members (open) or party_members_in_zone (instanced)
static func is_instanced(zone: StringName) -> bool # tower, pvp, guildwar, arena, raid (INSTANCED_ZONES)
func world_host() -> String                        # `whost` id ("" unknown / offline)
func is_world_host() -> bool                       # this game makes the AI world chat
func remote_node(id: String) -> Node3D             # the RemotePlayer in the current zone, or null
## Tests: swap the socket for an object with send_text(text) and poll() -> Array[String];
## `_dispatch(msg)` handles one server frame as if it came off the wire.
func use_transport(transport: Object) -> void
func _dispatch(msg: Dictionary) -> void
```

Online connects by itself on the web build once the account is signed in
(`window.toonCloudStatus()` has a user) and the hero is in the world; it reconnects
with backoff (2, 4, 8, 16, 30 s). The settings get a switch "เล่นออนไลน์" (on by
default). Desktop / headless builds stay offline unless a test injects a transport.

Remote players are `RemotePlayer` nodes (group `remote_players`, built with the same
look code as `FieldPlayer`, a "ผู้เล่นจริง" tag over the name, interpolated movement),
added to the current zone for every player whose `zone` matches.

## Shared world (zone-wide, v2)

Every real player in the same **open** zone (fields, star / divine regions, the abyss, the
village) sees the same monsters, the same AI world players in the same places doing the
same things, and the same AI world chat. **Instanced** zones (`tower`, `pvp`, `guildwar`,
`arena`, `raid`) keep the party scope of "Shared combat" above. Like the tower, the daily
party raid (`raid`, RaidData) does not share its monsters yet (EntitySync.supports is false
for tower-like zones): real party mates who enter see each other, but each game runs its own
floors with its own hero and AI party (world players in `Game.world_party`).

- **Zone host.** `host {zone, id}` now names the zone host for everyone in an open zone:
  the connected player who arrived in that zone first (re-elected when it leaves the zone,
  drops or goes away). `id` is null while only one real player is there. In instanced
  zones the host is chosen among the party as before. `Online.is_mirror_zone(zone)` is
  true whenever someone else hosts the hero's zone, party or not.
- **Monsters.** `ent_snap` / `ent_event` go from the zone host to every other player the
  host serves (everyone in an open zone; the party in an instanced one); `ent_hit` from
  any of them to the host. Loot and EXP on `ent_event dead {killer, share:{id: damage}}`:
  a player rolls its own drop and EXP when it dealt damage (its id in `share` with
  damage > 0), or when a member of its party in that zone did. Nobody else gets anything
  (no kill stealing: the one who hit gets the reward). The host's own damage is in `share`
  under its id, and the host follows the same rule (no reward for a kill it took no part
  in); field boss, world boss and golden monster rewards too. The client also counts its
  own hits that the host may not have counted yet.
- **Host hand-over.** A `spawn` also carries the monster's home (`hx`, `hz`) and its boss
  phase (`p`, when past 0). When the server names a new host, that player's game turns its
  mirrors into real monsters where they stand (HP, anger, boss phase) under the **same
  eids** and carries on sending `ent_snap` / `ent_event`; new monsters get eids past every
  eid seen. The other players keep their mirrors (frames from the new host only) and drop
  the ones the new host does not name within 10 s. When the host leaves and nobody else is
  left (`host` id null) the last player keeps the mirrored monsters the same way.
- **AI world players.** The zone host's game runs them (WorldPresence) and sends
  `wp_snap {zone, ps:[[index, x, z, yaw, anim, flags]]}` 4 times a second (index =
  WorldPlayers roster index; anim "idle"/"run"/"attack"/"skill:<id>"/"dead" (the client
  also sends "sit": a stall keeper sitting by its wares); flags bit 0 riding, bit 1 wings
  open, bit 2 flying (with bit 1); at most 40, only those near any served player) and
  `wp_event {zone, index, ev, data}` for "skill" (`{id, eid}`: the cast and its target
  monster, so the effect plays), "bubble" (`{text}`), "leave". Relayed exactly like
  `ent_snap` / `ent_event`. A mirror zone shows exactly the listed players as puppets
  (looks from WorldPlayers by index, no AI of their own, interpolated).
- **AI world chat.** `whost {id}` (server -> everyone, on connect and on change) names the
  world host: the connected player online the longest. Only the world host's game makes
  the AI world-channel chat (lines, conversations, buy requests and stall answers,
  milestone announcements stay local because they are already the same everywhere) and
  sends it with `ai_chat {lines:[{ch:"world", speaker, text, color?, index?}]}`; the
  server relays it to everyone else with `from`. Everyone else does not make world-channel
  AI chat of its own and shows the relayed lines (bubble over the speaker when it stands
  in the zone). Guild and party AI chat and the AI's answers to the hero stay local.

## Pets (real players' pets fighting together)

- Each game simulates only its own hero's pet (`characters/pet.gd`). Its hits land on the
  zone's monsters like the hero's own: on a mirror they go to the host inside the hero's
  `ent_hit` (credited to that player once), on the host they are the hero's side's
  damage. No other game deals that damage again.
- So the others see it fight, the owner's game sends `pet_act {zone, k, e, p:[x, z]}`
  (`systems/online/pet_sync.gd`) for each attack (`k` "a") and skill (`k` = the PetData
  skill id): `e` the target's eid (0: none / its own spot), `p` the flat point (0.1 m).
  At most 3 a second (burst 4), only while someone else is in the zone.
- Server: dropped unless the sender has a pet (`hello` / `look` `pet`), `k` is "a" or one
  of that pet's skills (`PET_SKILLS`, kept equal to `data/pet_data.gd` by a test), `zone`
  is the sender's zone, `p` is two finite numbers within 5000, the zone is not "pvp" /
  "guildwar" and the sender is not duelling; at most 4 a second per player (the rest
  dropped silently). Relayed as `{t, from, zone, k, e, p}` (nothing else the client
  wrote) to the players the zone host would serve with the sender: everyone in an open
  zone, the party there in an instanced one.
- Viewers: the pet is a PetFollower (PetCrowd caps apply). It runs to the monster `e`
  names (a mirror, or one the viewer hosts; else to `p`), plays the clip of the skill and a
  cheap effect (one ring / flash / ball, VfxBudget and MemoryGuard gated, at most 6 a
  second for all followers), then walks back to its owner after 2.6 s without acts. It
  never calls take_hit: the monster's HP comes with the host's snapshots.
