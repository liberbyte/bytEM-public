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
A tab (in both Supply and Demand rooms) for issuing a command and reviewing its result as a distinct input/output pair — separate from the scrolling terminal log above it.

**Data Room**
The general term for either a Supply Room or a Demand Room — a Matrix room configured by bytEM to either provide or request data.

**Data Room Alias**
A short, human-readable identifier for a room (e.g. `#test-data-product-2:bytem-synapse:8008`), as opposed to its long internal Room ID.

**DEID (Data Entity ID)**
A URL that identifies what a Supply Room's data *is* and where it logically belongs. Must be on the room owner's own bytEM domain (e.g. `bm2.liberbyte.app`, no `bytem.` prefix). Set via `room-deid --schema` / `room-deid --save`. Once data has been uploaded to the room, the DEID can no longer be changed.

**Demand Room**
A room created by a data *consumer* to search for and request data they need. Tagged blue in the Overview page.

**Echart**
A sub-tab of the Exchanged view in a Demand Room that renders received data as a chart — only appears when the exchanged data includes a `supply-type-result-echart` entry.

**Entity Readiness**
The panel in a Supply Room showing five status indicators (Base Type, DEID, Class, Entity Status, Market Status) that together describe how complete and discoverable the room is.

**Entity Status**
Whether a Supply Room's data entry has been confirmed by the network, as opposed to just saved locally. Commonly stays yellow ("local") rather than turning green, especially in an instance not actively connected to other bytEM servers.

**Exchange**
A link between a specific Supply Room and a specific Demand Room that makes data flow automatically — once linked, anything new the Supply Room publishes is pushed to the Demand Room without either side re-requesting it. Created in a Demand Room by running `search`, then `find`, selecting the results you want, then running the `exchange` command.

**Exchange Type**
A numeric code identifying how an Exchange behaves. Currently only type `1` ("Standard — supply pushes to demand") is in use.

**Federation**
The network of independent bytEM servers (instances) that trust each other and can share/discover data across server boundaries, built on the Matrix protocol's server-to-server federation.

**Find**
A terminal command (`find *`) for looking up indexed data across the network — a broader, more general counterpart to `search`.

**Guest Access**
A setting on a Demand Room (`guest-user-enable` / `guest-user-disable`) that lets people without a bytEM login view the room's exchanged data in a read-only, filtered form. Only works on rooms with no Supply-side data of their own.

**Ingest**
The act of loading data into a Supply Room so it becomes part of that room's published dataset — done via the `load-supply dataset` command or by attaching a matching schema through Search Event.

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
A structured template (in JSON-LD format) describing the shape of a particular kind of data — used both to fill in DEID/Class, and to attach a recognised data structure to a Supply Room via Search Event.

**Search**
A terminal command (`search --event-type *` or `search --event-type <keyword>`) for finding published data across the bytEM network by event type. The shorthand `search *` works the same way.

**Solr**
The search engine bytEM uses internally to index published Supply Room data, making it discoverable via `search`/`find`.

**Space**
An organisational container (like a folder) that groups related Supply and Demand rooms together.

**Supply Room**
A room created by a data *provider* to publish data for others to find and use. Tagged green in the Overview page.


**Web Component**
A custom data-entry field you can build for a Supply Room entry via the Forms tab — not a simple form, but a small builder (component type, name, label, required flag) that extends the entry's data structure beyond the standard DEID/Class fields. Built-in types include Website and DataSet.

**Whitelist**
The list of trusted, federated bytEM server domains an instance is allowed to exchange data with — maintained via `whitelist-sync.sh`.

---

*Maintained alongside [USER_GUIDE.md](USER_GUIDE.md) and [GUIDE.md](GUIDE.md) — add a new term here any time a new concept comes up in conversation, so the definition stays in one place instead of being re-explained ad hoc.*