# Private cache format

## Purpose

The cache contains player-owned content decoded at runtime from a verified ROM.
It is stored beneath LÖVE's `gen2recomp` save directory, never in the source
tree or release package. The original ROM path and ROM bytes are not cache
metadata.

## Ownership

One cache belongs to exactly one tuple:

| Field | Purpose |
| --- | --- |
| `applicationId` | Prevent another application from claiming the cache |
| `profileId` | Select the immutable extraction and behavior profile |
| `romSha1` | Bind content to the exact player-supplied ROM release |
| `cacheSchema` | Invalidate content when the profile's output schema changes |
| `importerVersion` | Invalidate content when extraction behavior changes |

The relative directory is deterministic:

```text
cache/<profile-id>/<rom-sha1>/schema-<n>/importer-<n>/
```

Changing the application version alone does not invalidate a cache. The
application version is recorded as producer information, while intentional
compatibility breaks increment `cacheSchema` or `importerVersion`.

## Completed manifest

`manifest.json` is the completion and ownership record. Its logical model is:

```text
format: "gen2recomp-cache"
formatVersion: 1
state: "complete"
owner:
  applicationId
  profileId
  romSha1
  cacheSchema
  importerVersion
producer:
  applicationVersion
files[]:
  path
  kind
  size
  sha1
fileCount
totalBytes
```

File paths are sorted, relative, forward-slash-separated paths. Traversal,
absolute paths, duplicate paths, the manifest's own filename, and ROM/save
extensions are invalid. File fingerprints cover the generated payload and
allow later launch-time integrity checks.

The manifest carries no decoded records directly. This keeps ownership
validation small and prevents loading executable Lua from a writable cache.
The on-disk encoding is deterministic UTF-8 JSON. Cache data is parsed as
data; writable cache files are never loaded as Lua source.

The Crystal import coordinator currently writes four normalized payloads:

- `data/font.json`
- `data/species.json`
- `data/tilesets/johto.json`
- `reports/import.json`

The structural report records only the accepted profile, ROM fingerprint and
header summary, warnings, decoded section counts, and expected payload paths.
It does not contain the ROM path, ROM bytes, or executable behavior.

Before serialization, the importer walks the decoded object graph and rejects
large strings that match the player ROM. It checks whole strings and overlapping
4 KiB windows at 1 KiB intervals, records the passing audit in the structural
report, and releases the temporary ROM comparison string before cache staging.

## Lifecycle

An import uses a sibling temporary directory that cannot be mistaken for a
completed cache:

1. Identify the ROM and derive the expected cache owner.
2. Decode and structurally validate normalized data in memory.
3. Serialize deterministic JSON and create a unique staging directory.
4. Write payload files and build their fingerprinted inventory.
5. Write and verify `manifest.json` last.
6. Promote the completed directory with a same-parent native rename.
7. Remove obsolete staging data after successful promotion or recovery.

A directory without a valid, complete, matching manifest is never loaded.
LÖVE owns reads, writes, directory creation, enumeration, and removal beneath
its save directory. Since LÖVE 11.x has no rename call, the filesystem adapter
uses Lua's native `os.rename` only for same-parent cache-directory promotion.
It never accepts player-controlled paths.

Promotion preserves an already valid matching target instead of replacing it.
An invalid target is first renamed to a quarantine sibling; if promotion fails,
that target is restored.

Cancellation is cooperative between extraction stages and at payload-write and
commit boundaries. It removes the active staging directory without touching a
valid target. At startup, recovery classifies same-owner siblings:

- a valid target wins and stale staging/quarantine siblings are removed;
- a complete staging cache may be promoted when the target is absent or
  invalid;
- incomplete staging directories are removed;
- a quarantined prior directory is restored if neither a target nor a usable
  staging cache survived.

Recovery never selects directories whose names do not match the internally
generated transaction-token grammar.
