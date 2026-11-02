# first47 S3-to-EFS staging image

This image downloads only the pinned first47 S3 object versions, validates
their byte lengths and SHA-256 digests, validates every tar member, and writes
the approved payloads to separate EFS access-point mounts.

It rejects absolute paths, parent traversal, duplicate members, links, special
files, unexpected files, mutable object versions, and group/world-writable
manifest modes. It installs the DELIVERY payload, installs the DELIVERY
`authority/` overlay as the shared authority, and installs only `archive/` from
the private read archive. The private archive's historical `control/` subtree
is verified but is not installed.

Required environment variable:

- `FIRST47_OPERATION_ID`: `[A-Za-z0-9][A-Za-z0-9._-]{0,63}`

Default mount paths:

- delivery: `/mnt/zoop-first47`
- authority: `/mnt/zoop-authority`
- AI archive: `/srv/zoop-ai-read/archive`
- operation results: `/mnt/zoop-ops`

The target delivery, authority, and archive roots must be empty. Success is
recorded as `staging/<operation-id>/result.json` below the OPS root.

Run unit tests:

```sh
python -m unittest discover -s tests -v
```
