#!/usr/bin/env python3
"""Set all application image references to one immutable Git commit tag."""

from pathlib import Path
import re
import sys


if len(sys.argv) != 2 or not re.fullmatch(r"[0-9a-f]{40}", sys.argv[1]):
    raise SystemExit("Usage: update-image-tags.py <40-character Git SHA>")

manifest = Path("k8s/workloads.yaml")
text = manifest.read_text(encoding="utf-8")
tag = sys.argv[1]
registry = "397845934845.dkr.ecr.us-east-1.amazonaws.com/ivolve-devops"

for service in ("auth-service", "roadmap-service", "frontend"):
    pattern = re.compile(
        rf"({re.escape(registry)}/{re.escape(service)}:)[A-Za-z0-9._-]+"
    )
    text, count = pattern.subn(rf"\g<1>{tag}", text)
    if count != 1:
        raise SystemExit(
            f"Expected exactly one image for {service} in {manifest}; found {count}."
        )

manifest.write_text(text, encoding="utf-8", newline="\n")
print(f"Updated all three image tags in {manifest} to {tag}.")
