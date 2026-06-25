# bytEM User Guide for bytEM OUDEA Client (alpha version)

> ⚠️ **bytEM OUDEA alpha** — the platform is under ongoing, continuous change. This guide will keep being updated as features evolve; if something here doesn't match exactly what you see in the app, that's likely why.

> This guide is for people **using** a bytEM instance — logging in, creating Supply/Demand rooms, exchanging data, and using the bytEM app (which also acts as a Matrix client). It does not cover server installation; ask your administrator for the instance URL and your login credentials. Creating a Supply Room requires your own bytEM account; accessing **public** Demand Rooms can also be done with an existing matrix.org (or other federated Matrix) account, if your bytEM instance has federation set to open or whitelisted.

> Some commands and actions require sufficient permissions in a room (your Matrix "power level"). If a command reports that you don't have permission, ask the room owner/administrator.

> **Not yet working in this alpha:** the `search` command does not work on this release and has been omitted from this guide. To locate data, use `find` with a DEID you already know (see [Section 8](#8-how-supply-and-demand-exchange-data)). **Guest Access** (`guest-user-enable` / `guest-user-disable` / `guest-user-access`) does work, but is still alpha-rough — see [Section 7](#7-demand-room--data-demand-editor) for details.

---

## Table of Contents

1. [What is bytEM?](#1-what-is-bytem)
2. [Logging In](#2-logging-in)
3. [Overview Page](#3-overview-page)
4. [Supply Rooms vs Demand Rooms](#4-supply-rooms-vs-demand-rooms)
5. [Creating a Data Room](#5-creating-a-data-room)
   - 5a. [Self-Service Data Access (Index Room / DEID flow)](#5a-self-service-data-access-the-index-room--deid-flow)
6. [Supply Room — Data Supply Editor](#6-supply-room--data-supply-editor)
7. [Demand Room — Data Demand Editor](#7-demand-room--data-demand-editor)
8. [How Supply and Demand Exchange Data](#8-how-supply-and-demand-exchange-data)
9. [Terminal Commands Reference](#9-terminal-commands-reference)
10. [PWA — Mobile App](#10-pwa--mobile-app)
11. [Tips, Limits & What the Colors Mean](#11-tips-limits--what-the-colors-mean)
12. [Getting Help](#12-getting-help)

---


## 1. What is bytEM?

bytEM is a decentralised platform for sharing and exchanging data between organisations — think of it as "email for data," or as an extension of your own website that makes your organisation's data (datasets, APIs, etc.) exchangeable. It is built around two basic ideas:

- **Supply Room** (you provide data) — where you publish data you want to make available (e.g. a utility publishing water quality readings).
- **Demand Room** (you subscribe to data via exchange) — where you request and receive data you need (e.g. a city publishing water quality data for citizens to access via an exchange). There is essentially an unlimited number of real-world use cases for exchanging, processing, and analysing data — these are just examples.

Once a Supply Room and a Demand Room are linked through an **Exchange**, the relevant metadata (describing the actual data, e.g. an API or dataset) flows automatically from the supplier to the consumer — no direct file sharing happens outside of that.

---

## 2. Logging In

**URL:** `https://<your-bytem-domain>/user/login`

1. Open the login page in your browser.
2. **Homeserver** field — leave this as the pre-filled default. It points to your organisation's bytEM server and should not normally be changed.
3. Enter your **Username**.
4. Enter your **Password**.
5. Optionally tick **Remember me** to stay signed in on this device.
6. Click **Sign In**.

On success you land on the **Overview** page. If login fails, double-check your username/password with your administrator, or try a hard refresh of the page (Ctrl+Shift+R) — first-time logins after a server update sometimes need this to clear a cached page.


> Public Demand Rooms can also be accessed by any federating Matrix instance (e.g. a Synapse installation) using that instance's own username — e.g. `@user:matrix.org` — when your bytEM server has federation set to open or whitelisted.

---

## 3. Overview Page

**URL:** `https://<your-bytem-domain>/overview`

```
┌─────────────────────────────────────────────────────────────────┐
│ bytEM  alpha release                              [avatar] you   │
├─────────────────────────────────────────────────────────────────┤
│ [●]  (profile avatar)                                            │
│                                                                   │
│ ▼ bytEM                                                          │
│ ┌──────────────────────────────────────────────────────────┐    │
│ │  bytEM — type help for commands, or start with            │    │
│ │          find                                              │    │
│ │  @you:~$ _                                                 │    │
│ └──────────────────────────────────────────────────────────┘    │
│                                                                   │
│ DATA ROOMS:                    [Demand Room] [Supply Room]       │
│                                                                   │
│ ⊕ bytEM - matrix.your-domain                  [Clear Terminal]   │
│   └─ [Test Room] (green=supply, blue=demand)  [Create ▾]        │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```


### The Terminal
A command-line interface for your account. Type `help` to see the commands available in the current context. The terminal is also available inside Supply and Demand rooms, with extra room-specific commands (see [Section 9](#9-terminal-commands-reference)).

### Data Rooms List
Shows every Supply and Demand room you belong to.
- 🟢 **Green tag** = Supply Room
- 🔵 **Blue/purple tag** = Demand Room

**Click any room** to open a context menu:

| Option | What it does |
|---|---|
| **Open Data Room** | Opens the room's editor screen |
| **Edit Data Room Name** | Renames the room |
| **Copy Room ID** | Copies the room's unique Matrix ID to your clipboard |
| **Leave Data Room** | Removes you from the room (the room and its data still exist) |
| **Delete Data Room** | Permanently deletes the room and everything in it — cannot be undone |

> "Leaving" and "deleting/removing" a room follow the underlying Matrix protocol's definitions of those actions.

### Buttons
| Button | Action |
|---|---|
| **Create ▾** | Opens the "Create Data Room" dialog |
| **Clear Terminal** | Clears the terminal's output history (does not affect your data) |

> "Creating a room" likewise follows the Matrix protocol's room-creation mechanics.

---

## 4. Supply Rooms vs Demand Rooms

| | Supply Room | Demand Room |
|---|---|---|
| **Who uses it** | Data providers (e.g. a utility, a sensor network) | Data consumers (e.g. a city, an analyst) |
| **Purpose** | Publish data so others can find, exchange, and use it | Request/subscribe to data that already exists |
| **Tag color** | 🟢 Green | 🔵 Blue |
| **Main action** | Set up DEID + Class, then add a supply-type (dataset upload or API reference) so the data is exchangeable via your DEID | Locate Supply Rooms by DEID, then request an Exchange |
| **Becomes useful when** | Fully configured (DEID, Class, data uploaded) and listed | Linked to one or more Supply Rooms via Exchange |

A single bytEM account can own and manage any number of Supply and Demand rooms at once. The Matrix protocol still applies at the room level (e.g. user power levels).

A DEID (Data Entity Identifier) is required on every Supply Room — without one, the room isn't findable or exchangeable.

---

## 5. Creating a Data Room

1. On the Overview page, click **Create ▾** → **Create Data Room**.
2. Fill in the dialog.

**For a Supply Room:**

| Field | Description | Example |
|---|---|---|
| **Room Base Type** | Choose `supply` | supply |
| **Data Room Name** | A human-readable name | `Berlin Water Quality` |
| **Room Description** | What this room is for | `Water quality data for Berlin` |
| **Data Room Alias** | A short ID (auto-suggested, editable) | `berlin-water-quality` |
| **Room Type** | The kind of data entity | `entity` |
| **DEID URLs** | The URL identifying your data source/schema (see [Section 6](#deid--what-url-to-use)) | `https://your-domain/de/berlin/water` |
| **Public or Private** | Visibility — Private is the default for new supply rooms | Private |

> **Data Room Alias:** use the auto-suggested alias rather than overwriting it — it's generated to satisfy Matrix protocol room-alias requirements.

> **DEID:** a DEID doesn't need to resolve to a full web page, but it should resolve to *something* — at minimum a valid JSON document (e.g. `{"deid": "https://your-deid"}`) reachable from a browser, `curl`, or `wget`. It must also be served from the same base domain as your bytEM instance (see ["What URL to use"](#deid--what-url-to-use) in Section 6).

**For a Demand Room:**

| Field | Description | Example |
|---|---|---|
| **Room Base Type** | Choose `demand` | demand |
| **Data Room Name** | A human-readable name | `City Planning Data Request` |
| **Room Description** | What data you're looking for | `Requesting water quality reports` |
| **Data Room Alias** | A short ID | `city-planning-request` |
| **Public or Private** | Visibility — Public is typical for demand rooms so suppliers can discover them | Public |

> `exchange` and `registry` room types exist in the dropdown but are not for general use — `exchange` is for the exchange mechanism itself, `registry` is admin-only.



3. Click **Create**. The room appears immediately in your Data Rooms list with the matching color tag.

---

## 5a. Self-Service Data Access (the Index Room / DEID flow)

There is a **second, simpler way** to get a Demand Room with real exchanged data in it — no terminal commands at all. It's built for someone who already knows *which* DEID they want and just wants the data, without manually creating a Demand Room and running `find` / `exchange` themselves.

This only works for Supply Rooms that are fully "ready" — see the checklist below.

### Step 1 — Make your Supply Room exchangeable (provider side)

Before any Supply Room shows up for self-service access, its provider must:

1. Create the Supply Room with a **DEID that matches that server's own domain** (see ["What URL to use"](#deid--what-url-to-use) in Section 6 — the DEID must live on the same domain the bytEM instance itself is served from).
2. Set the room's **Class** ([Section 6](#setting-the-class)).
3. Upload/ingest the actual data (`load-supply dataset`, etc.) and click **Update Supply**.
4. Keep updating the Supply Room until every row in the **Entity Readiness** panel is green — Base Type, DEID, Class, Entity Status, and Market Status all need to show a green dot (see [Section 11](#11-tips-limits--what-the-colors-mean) for exactly what each color means). Market Status in particular needs to reach `exchangeable`, not just `draft` or `advertised`.

Once Market Status is `exchangeable`, the room is automatically listed on the public index page at:

```
https://<your-bytem-domain>/pwa/index-room
```

Each listing card shows the DEID (as a readable label), a status badge (`exchangeable` in green, `draft` in blue), and the room's Class/domain tags.

### Step 2 — Request access (consumer side)

1. Open `https://<your-bytem-domain>/pwa/index-room` and click **Access data →** on the listing you want. This opens `/deid/<the-deid-path>` — a public page, no login required yet.
2. Fill in the short form:

   | Field | Required? | Notes |
   |---|---|---|
   | **Matrix username** | Yes | Your existing Matrix account (e.g. `@you:matrix.example.org`) — this flow does **not** create an account or set a password for you; you must already have one on some Matrix homeserver |
   | **Location** | Yes | Click a point on the map, or type latitude/longitude directly. If the Supply Room already published a location, the form pre-fills it — you can still adjust it |
   | **Email** | No | Optional, for your own records — not used to create an account |

3. Click **Access My Data Room** (disabled until username + a location are filled in).

### Step 3 — Watch the live orchestration console

After clicking, the page polls a status endpoint and walks through a checklist in real time:

| Step shown | What's actually happening |
|---|---|
| Waiting in queue | Your request has been accepted and queued |
| Finding or reusing demand room | (Currently always creates a new room — see note below) |
| Creating demand room | A brand-new Matrix room is created for this request |
| Setting DEID | The new Demand Room is tagged with the DEID you requested |
| Resolving data source | The matching Supply Room is located. If none is exchangeable for this DEID, this step fails with *"No supply available for this DEID"* |
| Processing data access fee | ⚠️ **Cosmetic only** — this is a ~1.5s delay with no real payment, billing, or charge involved in this alpha |
| Confirming transaction | ⚠️ **Cosmetic only** — same as above, no real transaction occurs |
| Exchanging data | The actual exchange runs automatically (an "auto-exchange") — equivalent to the Supply side's data being pushed into your new room |
| Setting permissions | Your account is added to the room at a restricted permission level (see note below) |
| Inviting you — auto-accepting invitation | You're invited into the room, and the invitation auto-retries if Matrix rate-limits it |
| Done | Your Demand Room is ready |

> **No room reuse yet:** every self-service request currently creates a brand-new Demand Room, even if someone already requested the same DEID before. This is called out in the code as an interim approach — expect this to change in a future version.

> **Permissions:** you're added with Matrix power level 51, while the room's default `events_default` is 50 — so despite being described as "read-only" access, you technically *can* send events into the room (51 ≥ 50). Don't rely on this room being strictly locked down to viewing only.

> **Guest access is explicitly forbidden** on these self-service-created rooms (different from a manually-created Demand Room, where guest access is just off-by-default but can be turned on with `guest-user-enable` — see [Section 7](#guest-access)).

### Step 4 — Explore the data room

Once the checklist reaches **Done**, you'll see a success screen with:

- **Explore `<DEID>` by bytEM** button — takes you to a login page (`/user/login?roomId=...&matrix_user=...`) with your homeserver and username pre-filled from what you entered. You still need to **type your actual Matrix password** — no password is auto-created for you in this flow. After logging in, you're redirected straight into `data-editor/demand/{roomId}` — the new Demand Room, with the invite already auto-accepted, so there's no separate "accept invite" step.
- **↗ Open in Element or another Matrix client** link — a `matrix.to` link, if you'd rather view the room in your own Matrix client instead of the bytEM app.

From there, the Demand Room behaves exactly like any other Demand Room — see [Section 7](#7-demand-room--data-demand-editor) for every tab and button inside it.

---

## 6. Supply Room — Data Supply Editor

**URL:** `https://<your-bytem-domain>/data-editor/supply/{roomId}`

Open by clicking a 🟢 green room → **Open Data Room**.


```
┌──────────────────────────────────────────┬─────────────────────────┐
│ Data Room / Data Supply Editor            │ Room Information:       │
│ ─────────────────────────────────────     │ Data Room:    [name][📋]│
│ Hint: Help for cmds to load schemas       │ Data Room ID: [id]  [📋]│
│ and load / ingest data                    │ Data Room     [alias][📋]│
│                                            │ Alias:                   │
│ ▼ bytEM                                   │ Data Room     [📋]      │
│ ┌────────────────────────────────────┐    │ Link:                    │
│ │ @you:~$ _                          │    │ Entity Readiness:        │
│ └────────────────────────────────────┘    │ Base Type: ● supply     │
│                            [Clear Term.]   │ DEID:      ● —          │
│                                            │ Class:     ● —          │
├────────────────────────────────────────── │ Entity     ● —          │
│ DATA MANAGEMENT:                          │ Status:                  │
│ Room Location | Command                   │ Market     ● —          │
│                                            │ Status:                  │
├────────────────────────────────────────── │                          │
│ DATA EXCHANGE / PROVISION:                │                          │
│ ▼ Search Event        [×]                 │                          │
│  * Select and search your schema          │                          │
│  [Search here...]                         │                          │
├────────────────────────────────────────── │                          │
│ MetaData | Files | Forms | HTML | API     │                          │
│ bytEM Repo | Map | Reference              │                          │
│                                            │                          │
│                             [Update Supply]│                          │
└──────────────────────────────────────────┴─────────────────────────┘
```
*(a "Control" tab also appears here if this room has a supply-control event)*

### Room Information Panel (right side)

| Field | Description |
|---|---|
| **Data Room** | The room's display name, with a copy button |
| **Data Room ID** | The room's unique Matrix ID (e.g. `!abc123:matrix.your-domain`) — needed for some terminal commands and exchange links |
| **Data Room Alias** | A short, human-readable alias for the room |
| **Data Room Link** | A shareable link directly to this room's editor |

### Entity Readiness Panel

This shows how complete and "live" your Supply Room is. Each row has a colored dot:

| Indicator | What it tracks |
|---|---|
| **Base Type** | Confirms this room is a Supply room. Always green once created — no action needed. |
| **DEID** | Whether a Data Entity ID has been set for this room (see below) |
| **Class** | Whether a data classification has been set for this room (see below) |
| **Entity Status** | Whether your data entity (with its DEID) has been reserved and registered at the bytEM level, and ultimately in the global address space |
| **Market Status** | Whether this room is listed in the wider bytEM market/federation and open for exchange |

See [Section 11](#11-tips-limits--what-the-colors-mean) for what each color actually means and what to expect.

### Setting the DEID

The **DEID** (Data Entity ID) identifies what your data is and where it logically belongs. Use the terminal:

```bash
room-deid --schema      # Fetches the DEID template for this room
room-deid --save        # Saves the DEID you've filled in
```

Running `--schema` prints a fillable template, e.g.:

```json
{
  "@context": "https://bytem.app/room",
  "@type": "room-deid",
  "state_key": "bytem.app.room-deid",
  "deid": "<your-deid-url-here>",
  "version": "v001"
}
```

**What URL to use:** <a name="deid--what-url-to-use"></a> the `deid` value must use **exactly the same domain shown in your browser's address bar** right now — including any `bytem.` prefix. Do not strip or guess at the domain; if the page you're on is `bytem.example.org`, your DEID must be on `bytem.example.org` too, because that's the domain that's actually registered in DNS with a valid certificate. A DEID on a domain that isn't provisioned (e.g. the bare `example.org` without the `bytem.` prefix) will fail to resolve and the room will be blocked with *"Please add a valid DEID before adding entity data to the room."* For example, if your instance lives at `bytem.example.org`, valid DEIDs look like:

```
https://bytem.example.org/de/berlin/water
https://bytem.example.org/de/test_1
```

The path after the domain can be anything that meaningfully describes your data. It doesn't need to be a full web page, but it should resolve to *something* — even a minimal JSON document such as `{"deid": "https://bytem.example.org/de/berlin/water"}` reachable via a browser, `curl`, or `wget` is sufficient. **Before saving, test the exact DEID URL in a new browser tab or with `curl -I <url>` — if it doesn't load, the room will not accept it.**

After editing the `deid` field, run `room-deid --save` to store it.


### Setting the Class

The **Class** describes what category of data this room provides. In the terminal:

```bash
room-class --schema     # Fetches the Class template for this room
room-class --save        # Saves the Class you've filled in
```

The template looks like:

```json
{
  "@context": "https://bytem.app/room",
  "@type": "room-class",
  "state_key": "<your-domain>",
  "domain": "<your-domain>",
  "class": "<category>",
  "uri": "<a-url-on-your-domain>",
  "version": "v001"
}
```

- **domain** — your bytEM instance's own domain, exactly as shown in the browser address bar (same rule as DEID, e.g. `bytem.example.org`).
- **class** — a category for your data, e.g. `environment`.
- **uri** — a URL on the same domain describing this specific entry; reusing your room's own DEID URL here is a safe, working choice.

Run `room-class --save` once the fields are filled in.

> Organisations running bytEM can publish their own Classes, as long as they follow valid Class syntax. For an example of a real Class document, see [Liberbyte's `alpha.environment.app` repo on Codeberg](https://codeberg.org/Liberbyte/alpha.environment.app/src/branch/main/class) (a free Codeberg account is needed to browse it; schema repos are made public after the alpha phase).

### Uploading / Ingesting Data

Use the terminal command to load a dataset file into the room:

```bash
load-supply dataset
```

This opens a file picker, or accepts a URL (for linking to an existing public file or document instead of uploading one), to attach your dataset (e.g. a PDF or data file) to the Supply Room. You'll see a confirmation message ("File uploaded successfully to Room ...") once it completes. `load-supply` also accepts other types (e.g. `load-supply api`, `load-supply html`) to load a matching schema template for non-dataset data structures.


> Currently only example Liberbyte-managed schemas are available, hosted on Codeberg (a free Codeberg account is required to browse the repositories). Attaching a schema is optional but recommended for every dataset/API — it increases your data's findability via the bytEM index (the public Matrix room each bytEM instance publishes). Classes and Schemas are meant to form a hierarchy: a Schema should be a *more detailed* description nested under a broader Class — e.g. the Class `WaterQuality` might have a Schema `water-quality-drinking-water`.

### Workflow Panel (above Data Management)

If a supply workflow has been defined for this room, a **Workflow:** panel appears between the terminal and Data Management. It's a collapsible JSON tree (click the header to expand/collapse) showing the workflow document, plus two buttons:

- A dynamic button in the panel header — its label comes from the workflow JSON itself (the `execute.label` field, so it may read anything the workflow author chose, e.g. "Run"). Clicking it executes the workflow as currently configured (collapses the panel automatically afterward).
- **Save Workflow** — saves whatever you've edited in the JSON tree without executing it.

Most Supply Rooms won't have a workflow defined, in which case this whole panel is simply absent.

### DATA MANAGEMENT Section

| Tab | Purpose |
|---|---|
| **Room Location** | Set the geographic or logical location associated with this room |
| **Command** | Bundles the room's DEID, Class, Room Index, and Room Advertisement editors in one place |

> Room Location is typically used when a room's data is tied to a specific place — e.g. a water-quality dataset for one city, where the `supply-type-dataset` entry is tied to that city's geolocation.

#### Room Location — in detail

This tab is **disabled** (greyed out, unclickable) once a location schema already exists for the room — at that point, location is something you only set once. Before a location exists, and only if you're the room owner (Matrix power level 100), an interactive map is shown: click a point on the map to set the room's latitude/longitude, which is saved as a `room-location` state event.

#### Command — in detail

This single tab actually layers up to four independent editors, each appearing only once its underlying data exists:

| Sub-section | Shows |
|---|---|
| **DEID editor** | The same DEID document covered in ["Setting the DEID"](#setting-the-deid) above, as a JSON tree with **Edit**/**Done** and **Save** buttons |
| **Class editor** | The same Class document covered in ["Setting the Class"](#setting-the-class) above, same Edit/Save pattern — and the `domain`/`state_key` fields auto-fill from your DEID's hostname as you type |
| **Room Index** | A read-only display of this room's entry in the bytEM network index (no edit controls) |
| **Room Advertisement** | A JSON document advertising this room's listing (what shows up on the public index page) — same Edit/Save pattern as DEID/Class |

For all three editable sub-sections, the pattern is identical: the tree renders in read-only **view** mode by default; click **Edit** to switch it to an editable tree/code mode (the button then reads **Done**); make your changes; click **Save** to persist them. Both buttons are disabled if the room owner has locked that field (`classLocked`/`deidLocked`).

### Search Event Panel

If any search templates are available, a **Search Event** panel sits between Data Management and the bottom tabs — a collapsible panel (✕ to dismiss) with a dropdown to select a schema and a search box to filter it. This is for locating and selecting an existing schema template to attach to your supply data, separate from the DEID/Class documents above.

### Bottom Tabs

A Supply Room always has a single DEID. (A Demand Room, by contrast, is an assembly of one or more DEIDs — see [Section 7](#7-demand-room--data-demand-editor).)

All tabs sit underneath the same **Data by DEID** list — expand your DEID entry (e.g. `bytem.example.org/de/berlin/water`), then expand the data entry beneath it (e.g. `supply-type-dataset`) to see that tab's content for this specific entry. Each tab is its own "content slot" attached to that entry — independent of the others.

| Tab | Purpose |
|---|---|
| **Control** | Only appears if a supply-control event exists for this room — lets you edit that control document directly |
| **MetaData** | The entry's raw JSON-LD record, viewable as an editable tree — this is your default view, showing metadata plus any links/paths/URLs to the attached API or dataset |
| **Files** | Upload a file to this entry, from your device or a URL |
| **Forms** | Build/edit a fillable web form definition attached to this entry |
| **HTML** | HTML/event rendering for this entry |
| **API** | API-related data (OpenAPI-style endpoint definitions) attached to this entry |
| **bytEM Repo** | A media/asset repository view for this entry's downloadable files |
| **Map** | Geographic map data (GeoJSON) attached to this entry |
| **Reference** | Reference documents/links attached to this entry |

#### Control — in detail

Only rendered when a supply-control event already exists on this room; otherwise the tab itself doesn't appear at all. Shows that control document as an editable tree, with the same Edit-mode toggle pattern as the DEID/Class editors.

#### MetaData — in detail

Shows the entry's record as an editable JSON tree, for example:

```json
{
  "@context": "https://bytem.app/supply",
  "@type": "supply-type-dataset",
  "version": "v001",
  "asset_key": "<value>",
  "version_key": "<value>",
  "name": "<value>",
  "file": "<value>",
  "schema": "<value>"
}
```

Use the search box and expand/collapse arrows above the tree to navigate large records, and click **Edit** (top right) to modify values directly. Each event type can also be individually selected (checkbox) and removed. This is the most reliable place to confirm exactly what's been saved against a DEID entry, independent of what the Entity Readiness panel's colored dots show.


#### Files — in detail

A two-column layout: the dataset's distribution metadata (`encodingFormat`, `contentSize`, `name`) on the left, and an **Upload a File** panel on the right with two methods:

- **via File System** — click or drag a file directly into the upload area
- **via URL** — provide a link to the file instead of uploading it from your device

This is the same underlying action as the terminal's `load-supply dataset` command — use whichever is more convenient.

#### Forms — in detail

Lets you build a fillable web-form definition for this entry — useful when the data behind this DEID is meant to be collected or presented as a structured form rather than a flat file. Add fields, set their default values, and save; this is independent of the entry's MetaData JSON tree.

#### HTML — in detail

Renders HTML/event content associated with this entry. Starts empty (*"No Events Found"*) until HTML-type content has been added to the entry.

#### API — in detail

Shows OpenAPI-style endpoint definitions for this entry, with **Save** and **Execute** actions — meant for entries that expose their data through an API rather than (or in addition to) a file. Starts empty (*"No API data has been added to this room"*) until an API definition is attached.

#### bytEM Repo — in detail

A repository/media browser for this entry's downloadable assets, with a download action for each file. Starts empty (*"No bytEM Repo data has been added to this room"*) until files exist here. Files are stored locally to bytEM using the Matrix media repository, so the usual Matrix protocol storage features and limits apply.

#### Map — in detail

Renders any geographic (GeoJSON) data tied to this entry on an interactive map, with zoom/pan controls. Starts empty (*"No Map data has been added to this room"*) until location data is added. Other geo formats may be supported in future. Loading large GeoJSON files in-browser has practical limits — it's recommended to tile geodata into roughly 10×10 km areas (bytEM's default tiling size) rather than uploading one large file.

#### Reference — in detail

Holds supporting reference documents/links for this entry. Starts empty (*"No Reference data has been added to this room"*) until something is attached. References point to other DEIDs (e.g. for building composite data products) — look up the referenced DEID's details with `find`, and it can be exchanged like any other DEID.

### Update Supply Button

Click **Update Supply** (bottom right) any time after making changes (DEID, Class, files, schema) to save and push your updates.

> Data must be pushed into the room before its DEID/Supply Room is exchangeable. Once exchangeable, it also becomes visible on bytEM's own product/room index at `https://<your-bytem-domain>/pwa/index-room`.

---

## 7. Demand Room — Data Demand Editor

**URL:** `https://<your-bytem-domain>/data-editor/demand/{roomId}`

Open by clicking a 🔵 blue room → **Open Data Room**.


```
┌──────────────────────────────────────────┬─────────────────────────┐
│ Data Room / Data Demand Editor            │ Room Information:       │
│ ─────────────────────────────────────     │ Data Room:    [name][📋]│
│ Quick: [help] [find *]                    │ Data Room ID: [id]  [📋]│
│        [room-deid] [show-room-index]      │ Data Room     [alias][📋]│
│                                            │ Alias:                   │
│ ▼ bytEM                                   │ Data Room     [📋]      │
│ ┌────────────────────────────────────┐    │ Link:                    │
│ │ @you:~$ _                          │    │ Guest         [Disabled]│
│ └────────────────────────────────────┘    │ Accessible:              │
│                            [Clear Term.]   │                          │
├────────────────────────────────────────── │                          │
│ DATA MANAGEMENT:                          │                          │
│ Results | Publish | Mgmt.Logs(disabled)   │                          │
│ Room Location | Commands                  │                          │
│                                            │                          │
│ 🔍 No results yet                          │                          │
│   Use terminal — try                      │                          │
│   `find *`                                │                          │
├────────────────────────────────────────── │                          │
│ DATA EXCHANGE / SUBSCRIPTION:             │                          │
│ Searched/Found | Exchanged                │                          │
│ Exch. Details  | Exch. Logs (! if errors) │                          │
└──────────────────────────────────────────┴─────────────────────────┘
```

### Quick Command Shortcuts

Click any chip at the top to instantly run that command in the terminal:

| Shortcut | Runs | Purpose |
|---|---|---|
| `help` | `help` | Lists all available commands |
| `find *` | `find *` | Finds all available data entries |
| `room-deid` | `room-deid --schema` | Shows this room's DEID template |
| `show-room-index` | `show-room-index` | Shows this room's index in the bytEM network |

> `room-deid` and `show-room-index` are grouped under "Supply Room" in [Section 9](#9-terminal-commands-reference) by convention, but as this shortcut bar shows, they also work — and are offered — directly inside a Demand Room.

### Room Information Panel

| Field | Description |
|---|---|
| **Data Room** | Room name |
| **Data Room ID** | Unique Matrix room ID |
| **Data Room Alias** | Short alias identifier |
| **Data Room Link** | Shareable link |
| **Guest Accessible** | When `Disabled`, guests without an account cannot view this room's data |

### DATA MANAGEMENT Tabs

| Tab | Purpose |
|---|---|
| **Results** | Shows generated results for the current `find` |
| **Publish** | Publish/manage this Demand Room's own advertisement/listing |
| **Mgmt. Logs** | ⚠️ Currently hard-disabled in this alpha — the tab is visible but greyed out and unclickable |
| **Room Location** | Sets the geographic/logical location for this demand, either by editing JSON directly or via an interactive map |
| **Commands** | Run room-management commands directly (also available via the terminal) |

#### Results — in detail

Shows your actual `find` results once you've run one. If you haven't run anything yet, it shows an empty state pointing you at the terminal: *"No results yet — try `find *`."*

#### Room Location — in detail

Two ways to set it: edit the location schema directly as JSON, or (if you're the room owner) use an interactive map to click and set a latitude/longitude. The underlying terminal command is `room-location --schema [--lat <lat> --lon <lon>]` (see [Section 9](#9-terminal-commands-reference)).

#### Commands — in detail

This tab has its own pair of inner tabs:

| Inner tab | Shows |
|---|---|
| **Command** | The room's raw command-schema document as an editable JSON tree |
| **Command Output** | Results from commands you've run (e.g. `find`), plus a download-summary panel for anything downloaded. Empty state: *"No Results Found"* |

### DATA EXCHANGE / SUBSCRIPTION Tabs

| Tab | Purpose |
|---|---|
| **Searched/Found** | Lists Supply Rooms across the network that match your demand |
| **Exchanged** | Lists active exchanges — Supply Rooms currently sending you data |
| **Exch. Details** | Details of a given exchange link (status, start date, exchange type) |
| **Exch. Logs** | Full history of what arrived and when |

#### Searched/Found — in detail

Shows results from your `find` terminal command, with a progress indicator while results are loading, pagination for large result sets, and an event-type selector. A summary line above the results recaps what happened — e.g. *"Find: 12 results for keyword "berlin" (in 84ms)"*, and *"Exchanged: 3 results exchanged (in 210ms)"* once you've run an exchange — plus a **Re-Exchange** notice listing any event types that need re-requesting. This is the tab you check to see what's actually available before requesting an Exchange (see [Section 8](#8-how-supply-and-demand-exchange-data) for the exact command sequence).

#### Exchanged — in detail

Once data has actually been exchanged, this tab shows its own row of **inner tabs** — mirroring the Supply Room's bottom-tab pattern, but only showing the ones relevant to what was actually received:

| Inner tab | Shown when... |
|---|---|
| **MetaData** | Always — full JSON tree of the exchanged record(s), paginated. Guests get a read-only `Json` view; regular users get the full editor |
| **Reference** | The exchanged data includes `supply-type-reference` content |
| **Forms** | The exchanged data includes form-type content |
| **Map** | The exchanged data includes geographic information |
| **HTML** | The exchanged data includes website/HTML content |
| **API** | The exchanged data includes API/OpenAPI content — guests get a read-only view; regular users can re-execute queries |
| **bytEM Repo** | Downloadable files/assets exist in the exchanged data |
| **Echart** | The exchanged data includes a `supply-type-result-echart` entry — renders as a chart |

There's no "Files" inner tab — you're receiving data here, not uploading it. Before anything has been exchanged, any inner tab that isn't gated-on yet just shows its own "no data" message (e.g. *"No event-types have been exchanged yet"*).

#### Exch. Logs — in detail

Same full-history log view described in the table above, with one extra detail: the **Exch. Logs** tab label itself shows a red **!** prefix whenever any logged exchange contains errors — a quick visual signal to check the logs without having to open the tab first.

### Guest Access

A Demand Room can optionally be made viewable by people **without a bytEM login** — useful for sharing received data publicly (e.g. a public dashboard) without giving out accounts.

```bash
guest-user-enable      # Make this demand room's data viewable by guests
guest-user-disable     # Turn guest access back off
guest-user-access      # Expose the checked event-types (in Searched/Found) to guests
```


A few things to know:
- `guest-user-enable` is refused if the room contains Supply-side data — it's for sharing what you've *received* via Exchange, not for publishing original data.
- `guest-user-access` works off whatever event-types are currently **checked** in the Searched/Found tab — there's no typed argument; check the boxes first, then run the bare command.
- Guests see a read-only, filtered version of the Exchanged tab's content (the same MetaData/API sub-tabs, but without edit controls).
- The **Guest Accessible** field in the Room Information panel reflects the current state — `Disabled` until you run `guest-user-enable`.

---

## 8. How Supply and Demand Exchange Data

This is the core workflow that makes bytEM useful — connecting a data provider to a data consumer so updates flow automatically, without anyone manually emailing files back and forth.

> This is the **manual, terminal-driven** path — you create the Demand Room yourself and run `find` / `exchange` by hand. If you just want to grab data from an already-published, exchangeable Supply Room with no terminal commands at all, use the self-service flow in [Section 5a](#5a-self-service-data-access-the-index-room--deid-flow) instead — it creates the Demand Room and runs the exchange for you automatically.

### Step-by-step

**On the Supply side (the data provider):**

1. Create a Supply Room ([Sectionx 5](#5-creating-a-data-   )).
2. When the room is created, the bytEM bot is automatically invited into it and given the permissions it needs to process commands — you don't need to do this manually.
3. Set the room's **DEID** and **Class** ([Section 6](#6-supply-room--data-supply-editor)) — these are what make the room *discoverable*. A room with no DEID/Class is invisible to anyone searching from a Demand Room.
4. Upload or ingest your data (`load-supply dataset`, or `load-supply <type>` for other supply-types).
5. The bot processes the data in the background and indexes it for search — this typically takes a few seconds.

**On the Demand side (the data consumer) — the exact command sequence:**

6. Create a Demand Room.
7. **Find** the specific data by a DEID you already know:
   ```bash
   find *                  # find everything available for the selected DEID
   find --<field> <value>  # find by a specific field, e.g. a known DEID
   ```
   > Get the DEID you want directly from the supplier, or from the bytEM index at `/pwa/index-room`, and use `find` with it.
8. The results feed the **Searched/Found** tab (Data Exchange/Subscription).


9. In the **Searched/Found** tab, select the checkboxes next to the specific results you want.
10. Run the **exchange** command (bare, no arguments — it acts on whatever is checked):
    ```bash
    exchange
    ```
    This requires `find` to have already been run and at least one result checked — the command itself takes no typed arguments; it reads the checkbox selections and the prior find results from app state. Every exchange created this way is currently **one-off** — a "continuous" exchange type exists in the data model but isn't wired up to anything in this alpha, so don't expect supply-side updates to auto-propagate yet.
11. The exchange link is created immediately — there is currently no separate manual approval step on the supplier's side; once requested, the link is active.

**After linking:**

12. The bot does have logic to continuously watch a linked Supply Room and auto-push new data when the exchange type is "continuous" — but the `exchange` terminal command always creates **one-off** exchanges in this alpha, so in practice this auto-push never triggers yet. Expect to re-run `find` → check results → `exchange` again to pick up new data from the supplier.
13. Check the **Exchanged** tab any time to see the actual received data, broken into MetaData/Reference/Map/HTML/API/bytEM Repo/Echart sub-tabs depending on what was sent.

14. Check **Exch. Details** for the specifics of a given link (status, start date, exchange type).
15. Check **Exch. Logs** for the full history of what arrived and when.

### Quick summary

**Supply publishes (DEID + Class + data), Demand runs `find` on a known DEID → checks the results it wants → runs bare `exchange`. Every exchange is currently one-off, so re-run `find` → `exchange` to pick up new data later.**

---

## 9. Terminal Commands Reference

The terminal is available on the **Overview page**, inside **Supply Rooms**, and inside **Demand Rooms**. Type a command and press Enter. Type `help` to list the commands available in the current context, or `help <command>` for details on one command.

> Many room-level commands require sufficient permissions (your Matrix power level) in that room. If a command reports *"You do not have sufficient permissions to execute the '<command>' command in this room,"* ask the room owner/administrator.

> **Note on "Supply" vs "Demand" below:** these groupings reflect how each command is actually *used* in the normal workflow — most of them aren't hard-blocked by room type in the code itself, but running them in the "wrong" room either has no relevant effect or fails for unrelated reasons (e.g. missing prior state). Don't rely on a command being rejected just because you're in the wrong kind of room.

### Common (all contexts)

```bash
help [command]                # List commands, or show help for one command
clear                         # Clear the terminal window
leave --room-id <room_id>     # Leave a data room
delete --room-id <room_id>    # Delete a room entirely (irreversible)
room-location --schema [--lat <lat> --lon <lon>]   # Set / update the room's location (works in either room type)
```

### Supply Room

```bash
room-deid [--schema | --save]   # Show / set this room's DEID (--schema fetches a template, --save stores it)
room-class [--schema | --save]  # Show / set this room's Class (DEID must be set first)
load-supply <supply-type>       # Load a supply template (dataset, api, html, …) to add data into the room
show-room-index                 # Show this room's index state event
```

### Demand Room

```bash
find *                          # Find everything available for the selected DEID
find <field> <value>            # Find by a specific field — valid fields: room_id, room_name,
                                 #   room_topic, room_alias, event-search-index, *, location
                                 #   (a leading -- on the field, e.g. --room_id, is also accepted)
exchange                        # Bare command, no arguments. Requires a prior `find` and at least
                                 #   one checked result in the Searched/Found tab. Always creates a
                                 #   one-off exchange in this alpha (no continuous/auto-sync yet).
openapi-exec                    # Bare command. Executes OpenAPI for whichever event-types are checked
find-in-room                    # Bare: opens/fetches the find-in-room template in the Command tab
find-in-room <search-string> *  # Search string across all exchanged event-types
find-in-room <search-string>    # Search within whatever event-types are currently checked
result *                        # Build a Result from all exchanged data (filtered to checked types)
result find-in-room <search-string> *           # Build a Result from a find-in-room search, all types
result find-in-room <search-string> <anything>  # Same, restricted to the checked event-types
download <media-repo-URL>       # Download a specific file by its media URL
download *                      # Download every event-type that has files, zipped
download                        # Download just the event-types currently checked (no argument needed)
guest-user-enable                # Grant guest (no-login) access to this demand room
guest-user-disable               # Revoke guest access
guest-user-access                # Expose the checked event-types to guests
```

### Advanced / Bulk Tooling (power-user commands)

These aren't part of the everyday Supply/Demand workflow — they're for bulk-creating Matrix spaces/rooms and ingesting external web data into them. They work from any terminal context (Overview, Supply, or Demand) **except** the `--batch` variants below, which only work on the **Overview page** (the JSON panel they open is wired up there only — running `--batch` inside a Supply/Demand room editor does nothing).

```bash
rm --event-type <type1> <type2>     # Remove specific event-types from this room's data
rm --all                            # Remove all event-types from this room's data
                                     #   (works in Supply Rooms, and in Demand Rooms whose
                                     #   room ID is on this instance's own server)

list_servers                        # Lists available search servers for this room (Demand context)

load-schema <schema-url>            # Fetch and validate a JSON schema from a URL — doesn't
                                     #   save anything, just confirms it's usable

invite-user --room_id <room_id> --user <matrix-user-id>   # Pre-fills an invite form
                                     #   (Overview page only — opens the Invite Users panel there)

cmd-last-exec --schema --run        # Re-runs the last command stored in this room's command schema

space-create <name words> --desc <description words> [--parent <parent space name>]
                                     # Queues creation of a new Matrix space (returns a Job ID)
space-create --batch                # Opens a JSON panel for creating multiple spaces at once (Overview only)

room-create <name words> --desc <description words> [--alias <alias>] [--space <parent space name>]
                                     # Queues creation of a new Matrix room (returns a Job ID)
room-create --batch                 # Opens a JSON panel for creating multiple rooms at once (Overview only)

data-ingest <room-alias-or-room-id> <schema-url> [data-url]
                                     # Looks up the target room by alias (or accepts a room ID
                                     #   directly, starting with "!") anywhere on this instance,
                                     #   then queues ingestion of the schema/data into it
data-ingest --batch [--from-rooms]  # Opens a JSON panel for ingesting into multiple rooms at
                                     #   once (Overview only); --from-rooms auto-fills targets
                                     #   from rooms you created via room-create in the last 10 minutes
```

> These bulk-creation commands print their own usage/examples in the terminal if you run them with missing arguments — type the bare command name (e.g. `data-ingest`) to see the in-app help.

> Once data has been uploaded to a room, its DEID can no longer be edited — this is intentional, to prevent identity drift on data that's already in use. Create a new room if you need a different DEID.

---

## 10. PWA — Mobile App

**URL:** `https://<your-bytem-domain>/pwa/`

> The PWA is evolving towards being bytEM's general "index" entry point (see the `/pwa/index-room` flow in [Section 5](#5-creating-a-data-room)), in addition to its current role as the mobile app.

The PWA (Progressive Web App) is a mobile-optimised version of bytEM, designed to be installed like a native app on your phone.

### Installing on Mobile

1. Open `https://<your-bytem-domain>/pwa/` in your mobile browser.
2. Tap your browser's menu.
3. Select **"Add to Home Screen"** (iOS Safari) or **"Install App"** (Android Chrome).
4. The app icon appears on your home screen and opens full-screen, like a native app.

Once installed, log in the same way you would on desktop — your account works identically across both.


---

## 11. Tips, Limits & What the Colors Mean

The **Entity Readiness** panel uses colored dots to show progress:

| Color | Meaning |
|---|---|
| 🔴 Red | Not yet set, or not yet confirmed |
| 🟡 Yellow/Orange | Saved on your side, but waiting on network confirmation |
| 🟢 Green | Fully set and confirmed |

A few things worth knowing as you work:

- **DEID and Class** turn green once you successfully run `--save` and the value is accepted — re-check by refreshing the page after a few seconds.
- **Entity Status** commonly stays yellow ("local") even after a successful DEID save. This reflects that your entry is saved but pending full network confirmation — this can depend on factors outside the room itself (e.g. whether your instance is actively connected to the wider bytEM federation).
- **Market Status** depends on your instance being listed in the federation market and reachable by peer bytEM servers. If your instance isn't yet connected to other bytEM servers, this will stay red regardless of how complete your room is — this isn't something you can fix from within the room.
- If something you saved (DEID, Class, a file) doesn't appear after a refresh, wait roughly 10–15 seconds and refresh again — processing happens slightly asynchronously. If it's still missing after that, contact your administrator with the room name and what you tried to save.
- Once a Supply Room has data uploaded, its DEID becomes locked. Plan your DEID before uploading data, or create a fresh room if you need to change it.

---

## 12. Getting Help

### Matrix Support Room

Join the public bytEM support room to ask questions or report issues:

- Room address: `#bytem-support:matrix.liberbyte.com`
- Via Element: open [app.element.io](https://app.element.io) → **Explore** → enter `#bytem-support:matrix.liberbyte.com` → **Join**

### Within the App

Type `help` in any terminal (Overview, Supply Room, or Demand Room) to see the commands available in that context.

---

*User guide prepared for bytEM — Liberbyte GmbH © 2026*
