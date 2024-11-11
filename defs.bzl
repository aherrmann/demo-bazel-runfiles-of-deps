_SCRIPT_SNIPPET= """\
#!/usr/bin/env bash

# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
# shellcheck disable=SC1090
source "${{RUNFILES_DIR:-/dev/null}}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${{RUNFILES_MANIFEST_FILE:-/dev/null}}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  {{ echo>&2 "ERROR: cannot find $f"; exit 1; }}; f=; set -e
# --- end runfiles.bash initialization v3 ---

set -euo pipefail

set -x
for f in {}; do
  $(rlocation $f)
done
"""

def _runfiles_test_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".sh")
    deps_paths = []
    deps_files = []
    deps_runfiles = []
    for dep in ctx.attr.deps:
        workspace_name = dep[DefaultInfo].files_to_run.executable.owner.workspace_name or "__main__"
        short_path = dep[DefaultInfo].files_to_run.executable.short_path
        deps_paths.append(workspace_name + "/" + short_path)
        deps_files.append(dep[DefaultInfo].files)
        deps_runfiles.append(dep[DefaultInfo].default_runfiles)
    content = _SCRIPT_SNIPPET.format(" ".join(deps_paths))
    ctx.actions.write(out, content)
    return [DefaultInfo(
        executable = out,
        files = depset(direct = [out], transitive = deps_files),
        runfiles = ctx.runfiles([out]).merge_all(deps_runfiles),
    )]

runfiles_test = rule(
    _runfiles_test_impl,
    executable = True,
    test = True,
    attrs = {
        "deps": attr.label_list(
            mandatory = False,
            allow_files = False,
        ),
    },
)
