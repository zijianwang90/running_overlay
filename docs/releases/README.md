# GitHub Release Notes

Each GitHub release tag must have a matching handwritten release note file in
this directory before the tag is pushed.

Use one Markdown file per tag:

```text
docs/releases/v0.1.3.md
docs/releases/v0.1.4.md
```

The release workflow copies `docs/releases/${tag}.md` into the GitHub Release
body. The file must mention the expected zip and checksum asset names so the
published release page stays aligned with the uploaded artifacts.
