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
| `ent_event` | `zone, eid, ev, data` | host only: "spawn", "dead", "cast", "phase", "aggro" ... relayed to the party in that zone |
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
| `stall_list` | | my stall's current lots (from PlayerStall) for real players to browse |
| `stall_buy` | `seller, lot` | buy a lot from a real player's stall |

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
| `party` | `party:{id, leader, members:[id]}` or `party:null` (sent to every member on any change) |
| `host` | `zone, id` - who simulates the shared entities of my party in that zone (null: nobody shares, play alone) |
| `ent_snap` / `ent_event` | relayed from the host, plus `from` |
| `ent_hit` | relayed to the host, plus `from` |
| `trade_req` / `trade_answer` / `trade_offer` / `trade_lock` / `trade_confirm` / `trade_cancel` | relayed with `from`; the server keeps the trade session state |
| `trade_done` | `give:{items,gold}, get:{items,gold}` - apply it: remove `give`, add `get` |
| `duel_req` / `duel_answer` / `pvp_hit` / `duel_over` | relayed with `from` |
| `gw_invite` / `gw_answer` / `gw_start` | relayed with `from` within the party |
| `stall` | `seller, lots:[...]` / `stall_sold` `{lot, buyer, gold}` to the seller / `stall_bought` `{lot, item, gold}` to the buyer |
| `error` | `code, text` (Thai, shown to the player) |
| `kicked` | `reason` |

## Shared combat (party only)

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
func is_mirror_zone(zone: StringName) -> bool      # in a party, someone else hosts: do not spawn monsters
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
