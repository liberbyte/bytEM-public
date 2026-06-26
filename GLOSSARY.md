# bytEM Glossary

A shared reference for terms used across bytEM — so everyone (support, ops, end users) means the same thing when they say "DEID" or "Exchange."

---

**Base Type**
The role a Data Room was created with: `supply` or `demand`. Set once at creation and never changes. Shown as a permanently green indicator in the Entity Readiness panel — it isn't something you configure, just a label confirming what kind of room this is.

**Bot**
The automated Matrix account (`@bot:...`) that bytEM uses to process commands, ingest data, mediate Exchanges, and write room state. It's automatically invited into every room you create and given the permissions it needs — you don't manage it directly.

**Class**
A classification you assign to a Supply Room describing what category its data falls into (e.g. `environment`). Set via `room-class --schema` / `room-class --save`. Required, alongside DEID, before a Supply Room becomes discoverable to Demand Rooms.

**Commands tab**
A tab for issuing a command and reviewing its result as a distinct input/output pair. Active in both Supply and Demand rooms; in the Demand Room only the **Mgmt. Logs** tab is disabled (Results, Publish, Room Location, and Commands all work).

**Data Room**
The general term for either a Supply Room or a Demand Room — a Matrix room configured by bytEM to either provide or request data.

**Data Room Alias**
A short, human-readable identifier for a room (e.g. `#test-data-product-2:bytem-synapse:8008`), as opposed to its long internal Room ID.

**DEID (Data Entity ID)**
A URL that identifies what a Supply Room's data *is* and where it logically belongs. It uses your instance's **base domain without any `bytem.` prefix** (e.g. `https://bm1.liberbyte.app/de/test_1`), or a published schema domain such as `https://alpha.environment.app/de/deid-1`. The Create-Data-Room dialog pre-fills it with your instance's base domain. Set via `room-deid --schema` / `room-deid --save` (or the **Save** button in the editor). Once data has been uploaded to the room, the DEID can no longer be changed.

**Demand Room**
A room created by a data *consumer* to request data they need. Tagged **purple** in the Overview page. In the current version, a usable Demand Room (with a reference DEID, so `find`/`exchange-data` work) is created automatically via the index/DEID flow (`/pwa/index-room`), not by hand.

**Echart**
A sub-tab of the Exchanged view in a Demand Room that renders received data as a chart — only appears when the exchanged data includes a `supply-type-result-echart` entry.

**Entity Readiness**
The panel in a Supply Room showing five status indicators (Base Type, DEID, Class, Entity Status, Market Status) that together describe how complete and discoverable the room is.

**Entity Status**
Whether a Supply Room's data entry has been confirmed by the network, as opposed to just saved locally. Commonly stays yellow ("local") rather than turning green, especially in an instance not actively connected to other bytEM servers.

**Exchange**
A link between a specific Supply Room and a specific Demand Room that lets data flow from supplier to consumer. The reliable way to create one is the self-service index flow: open the bytEM index (`/pwa/index-room`), pick the DEID you want, and the exchange runs automatically into a freshly-created Demand Room. Inside that index-created Demand Room you can then run `find` and `exchange-data` because it has the reference DEID set. See the User Guide for why a manually-created Demand Room cannot, on its own, run `find`/`exchange-data`.

**Exchange Type**
A numeric code passed to `exchange-data --exchange-type=` that sets how an Exchange behaves: `1` = one-off, `2` = continuous. (Continuous behaviour is still being stabilised in this alpha — confirm on your instance.)

**Federation**
The network of independent bytEM servers (instances) that trust each other and can share/discover data across server boundaries, built on the Matrix protocol's server-to-server federation.

**Find**
A terminal command (`find *`, or `find <field> <value>`) for looking up indexed data inside a Demand Room. It only returns results in a Demand Room that has a **reference DEID** set — which currently happens when the room is created through the index/DEID self-service flow (`/pwa/index-room`). A Demand Room you create manually has no reference DEID, so `find` has nothing to act on there.

**Guest Access** *(disabled in current version)*
A setting on a Demand Room that lets people without a bytEM login view the room's exchanged data in a read-only, filtered form. **Disabled in the current version** — the **Guest Accessible** field stays `Disabled`. When re-enabled, the commands are `enable-guest-user` / `disable-guest-user` / `grant-guest-access` (renamed from the older `guest-user-*` forms).

**Ingest**
The act of loading data into a Supply Room so it becomes part of that room's published dataset — done via the `load-supply dataset` command (or its equivalent in the Files tab).

**Market Status**
Whether a Supply Room is listed and visible in the wider bytEM federation/market. Depends on the instance being actively connected to other bytEM servers — independent of how well-configured the room itself is.

**MetaData tab**
Shows a room's data entries as an editable, structured (JSON) record — the most reliable place to confirm exactly what's been saved, independent of what the colored status indicators show.

**PWA (Progressive Web App)**
The mobile-optimised version of bytEM, installable on a phone like a native app, served at `/pwa/`.

**Room Advertisement**
The description a Demand Room publishes to the network (via the Publish tab) — what it's looking for, its location, and the capabilities it needs — so Supply Room owners can discover and respond to it, even before matching data exists.

**Room ID**
A room's permanent, unique technical identifier in Matrix (e.g. `!abc123:matrix.your-domain`). Needed for some terminal commands and Exchange requests.

**Schema**
A structured template (in JSON-LD format) describing the shape of a particular kind of data — used to fill in DEID/Class and to attach a recognised data structure to a Supply Room via `load-supply`.

**Search**
A terminal command (`search --event-type *` or `search --event-type <keyword>`) for finding published data across the bytEM network by event type. Offered as a quick-action chip in the editor UI and listed in the live `help`. For pulling data into a usable Demand Room, the primary path remains the index/DEID flow plus `find` (see [BYTEM_USER_GUIDE.md](BYTEM_USER_GUIDE.md)).

**Solr**
The search engine bytEM uses internally to index published Supply Room data, making it discoverable via `search`/`find`.

**Space** *(not used in bytEM OUDEA)*
A Matrix "space" — an organisational container (like a folder) that groups related rooms together. The Overview page still shows a **Create Spaces** batch tool in the current build, but spaces are **not part of the bytEM OUDEA workflow** and the `space-create` command is not used; you can ignore that tab.

**Supply Room**
A room created by a data *provider* to publish data for others to find and use. Tagged green in the Overview page.


**Whitelist**
The list of trusted, federated bytEM server domains an instance is allowed to exchange data with — maintained via `whitelist-sync.sh`.

---

*Maintained alongside [BYTEM_USER_GUIDE.md](BYTEM_USER_GUIDE.md) and [BYTEM_INSTALL.md](BYTEM_INSTALL.md) — add a new term here any time a new concept comes up in conversation, so the definition stays in one place instead of being re-explained ad hoc.*