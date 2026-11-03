# SentinelUI Auction Data API

How external tools can read, provide, and exchange auction price data.

## Where the prices live

All scan results go into a global table (SavedVariables `SentinelUIDB`):

```lua
SentinelUIDB.global.auctionDB = {
    ["Realm-Faction"] = {        -- e.g. "Everlook-Alliance"
        realm = "Everlook",      -- plain server name, no faction
        [12345] = { p = 1599, t = 1750000000, src = "ext" },  -- itemID -> entry
    },
}
```

| Field | Meaning |
|---|---|
| `p` | unit price in **copper** (total/stack computed by the addon) |
| `t` | Unix timestamp of the observation (seconds) |
| `src` | `"ext"` when the price came from an external feed, absent for own scans |
| `realm` | server name on the realm sub-table |

Item IDs are plain numbers — `|Hitem:12345|` link IDs.

## Providing prices (external feed)

A companion addon named `SentinelAHData` (or any addon creating the same global) exposes:

```lua
SENTINEL_AH_DATA = {
    updated = 1750000000,          -- unix ts of the snapshot
    realms = {
        ["Everlook-Alliance"] = {
            [12345] = 1599,        -- itemID -> unit price in copper
            [6789]  = 400,
        },
        ["Everlook"] = { ... },    -- realm without faction also accepted
    },
}
```

- The realm key tries `Realm-Faction` first, then bare `Realm`.
- On login (and when the AH opens) the module calls `AH:MergeExternalDB()`: entries are merged into `auctionDB` with `src = "ext"` and the external `updated` wins over older local data per item.
- Prices land in the same store our PriceHistory/scan uses, so tooltips, CraftWatch and the sell suggestion pick them up automatically.

## Reading prices out (for your tool)

The full DB lives in `WTF/Account/<account>/SavedVariables/SentinelUI.lua` under `SentinelUIDB.global.auctionDB` after `/reload` or logout — Lua tables you can parse directly.

In-game, a Lua snippet can dump the current realm:

```lua
/run local k=GetRealmName().."-"..UnitFactionGroup("player")
/run for id,e in pairs(SentinelUIDB.global.auctionDB[k] or {}) do if type(e)=="table" then print(id,e.p,date("%x %X",e.t)) end end
```

## Minimal exchange format for player-to-player sharing

Plain text / JSON you can hand to another player's companion addon — one line per realm:

```json
{ "updated": 1750000000, "realms": { "Everlook-Alliance": { "12345": 1599, "6789": 400 } } }
```

A converter script generates a `SentinelAHData` addon whose `SENTINEL_AH_DATA` equals that table; drop it in `Interface/AddOns/` and prices are live next login. Newer `updated` wins over a stale local scan.
