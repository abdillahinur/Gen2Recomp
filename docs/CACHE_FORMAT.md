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

## Lifecycle

An import uses a sibling temporary directory that cannot be mistaken for a
completed cache:

1. Identify the ROM and derive the expected cache owner.
2. Create a unique staging directory.
3. Decode payload files into staging.
4. Verify every payload and build its sorted inventory.
5. Write and verify `manifest.json` last.
6. Promote the completed directory without exposing a partial target.
7. Remove obsolete staging data after successful promotion or recovery.

A directory without a valid, complete, matching manifest is never loaded.
Promotion and interruption recovery are implemented by `M1-006` and
`M1-007`; this document defines the contract those operations must preserve.
