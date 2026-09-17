# euclid-amo — Application Monitoring

A Qt 6 / QML dashboard wall over euclid's monitoring module (EMO): panels on a grid, placed and
resized on demand, each one a query against a metric.

It is a sibling of `euclid-rui` rather than a part of it. The RUI is an administration console —
queues, buckets, users, one page per module — and monitoring there is a page among forty. This is
the other thing: a screen left running, showing a handful of numbers, that nobody clicks through.

## What a dashboard is

A JSON file under `~/.euclid/amo/dashboards`, one per dashboard, holding a list of panels. A panel
is a query plus how to draw it:

```json
{
  "id": "p1758012345678",
  "title": "Pool utilisation",
  "type": "line",
  "metric": "module-utilisation",
  "labels": {},
  "groupBy": "module",
  "unit": "%",
  "decimals": 0,
  "x": 12, "y": 9, "w": 12, "h": 6
}
```

`labels` narrows to a dimension value; `groupBy` splits the rows into one line per value of a
dimension. Both come from EMO's label map, so a metric an application pushed with
`{"area": "heap", "id": "G1 Eden Space"}` can be filtered on one dimension and split by another.

A file per dashboard, for the reason Grafana keeps them apart too: a dashboard is edited, broken,
copied to another machine and put in a repository, and all four are file operations.

## Panel types

| type | what it answers | notes |
|------|-----------------|-------|
| `line` | how it moved | multi-series, hover crosshair, drag to zoom, click the legend to hide a series |
| `bar` | which is biggest | one bar per series, ordered by value; `reduce` picks latest/max/total |
| `stat` | what it is now | one large number with a sparkline behind it |
| `gauge` | how much of it is used | for values with a real ceiling — a percentage, a pool against its maximum |

## The grid

24 columns, because 24 divides by 2, 3, 4, 6, 8 and 12 — halves, thirds and quarters of a row all
land on whole columns. Rows are a fixed pixel height rather than a fraction of the window, so a wall
built on a laptop stays readable on a television: more panels fit, at the same size.

Unlock the wall (the padlock) to drag panels by their header and resize them from the bottom-right
corner. A move that would overlap another panel is refused rather than resolved by pushing the
neighbours around — a wall where dropping one panel rearranges three others is a wall somebody has
to repair afterwards. Every change is saved immediately.

## Time ranges

The range buttons carry a resolution with them, because EMO stores three tiers: RAW (five-minute
buckets), HOUR and DAY. A week of RAW is 2,016 points per series where a week of HOUR is 168 — the
same line, drawn twelve times faster.

| range | tier |
|-------|------|
| 15m, 1h, 6h | RAW |
| 24h, 7d | HOUR |
| 30d | DAY |

Ranges are relative and evaluated per refresh, so a wall left running for a week shows the last hour
all week rather than the hour it was opened in.

## Metric discovery

EMO has no action that enumerates its series — `list` filters, it does not describe. The editor's
metric picker is therefore assembled by reading the most recent rows and collecting the distinct
names and label keys found there. That makes it an approximation: a metric that exists but has been
quiet may be missing from the list, which is why the metric and dimension fields can be typed into
as well as picked from. Refusing to chart what the picker cannot offer would make the application
useless for exactly the series somebody is investigating — the one that stopped.

## Building

Needs the same statically linked Qt 6 build `euclid-rui` uses:

```sh
cmake -B cmake-build-debug -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build cmake-build-debug -j8
./cmake-build-debug/euclid-amo
```

Override the Qt location with `-DCMAKE_PREFIX_PATH=/path/to/qt`.

### Options

```
--user, -u        sign in without the dialog
--password, -p
--namespace, -n
--dashboard, -d   dashboard to open on start
```

The last one is what makes this usable as a wall: a screen nobody sits at should come back up on the
right dashboard after a restart.

## Configuration

`~/.euclid/amo.json` — gateway address, authentication mode and the access key issued at login. Its
own file rather than the RUI's: two applications writing one file would each overwrite the other's
last change, and a wall pointed at one installation beside a console pointed at another is a normal
thing to want.

Authentication is the same as the RUI's — RFC 9421 request signing with the access key EAM issues at
login, falling back to the bearer token.
