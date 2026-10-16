#!/usr/bin/env bash
# name: run-tests.sh
# purpose: Run the rolodex tests in Podman (Rule 14), network off, repo mounted read-only, reusing the workflow test image.
# inputs: none; ROLODEX_TEST_IMAGE overrides the image tag.
# outputs: test output on stdout, exit code 0 when every check passes.
# writes-to: nothing outside the container's scratch mount.
# cleanup: the container is removed on exit (--rm).
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$here/../../.." && pwd)
image=${ROLODEX_TEST_IMAGE:-localhost/dotfiles-workflow-test:1}
podman image exists "$image" || podman build -q -t "$image" -f "$root/claude/workflow/tests/container/Containerfile" "$root/claude/workflow" >/dev/null
exec podman run --rm --network=none --userns=keep-id -v "$root:/repo:ro,Z" -e HOME=/tmp "$image" bash /repo/tools/rolodex/tests/test_rolodex.sh
