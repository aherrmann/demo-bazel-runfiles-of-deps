_TestInfo = provider()

def _test_suite_aspect_impl(target, ctx):
    if ctx.rule.kind == "test_suite":
        paths = []
        files = []
        runfiles = []
        for test in ctx.rule.attr.tests:
            test_info = test[_TestInfo]
            paths.append(test_info.paths)
            files.append(test_info.files)
            runfiles.append(test_info.runfiles)
        info = _TestInfo(
            paths = depset(transitive = paths),
            files = depset(transitive = files),
            runfiles = ctx.runfiles().merge_all(runfiles),
        )
        return [info]
    elif ctx.rule.kind.endswith("_test"):
        default_info = target[DefaultInfo]
        workspace_name = default_info.files_to_run.executable.owner.workspace_name or "__main__"
        short_path = default_info.files_to_run.executable.short_path
        info = _TestInfo(
            paths = depset(direct = [workspace_name + "/" + short_path]),
            files = default_info.files,
            runfiles = default_info.default_runfiles,
        )
        return [info]
    else:
        return []

_test_suite_aspect = aspect(
    implementation = _test_suite_aspect_impl,
    attr_aspects = ["tests"],
)

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
        test_info = dep[_TestInfo]
        deps_paths.append(test_info.paths)
        deps_files.append(test_info.files)
        deps_runfiles.append(test_info.runfiles)
    paths = depset(transitive = deps_paths)
    content = _SCRIPT_SNIPPET.format(" ".join(paths.to_list()))
    files = depset(direct = [out], transitive = deps_files)
    runfiles = ctx.runfiles([out]).merge_all(deps_runfiles)
    ctx.actions.write(out, content)
    return [DefaultInfo(
        executable = out,
        files = files,
        runfiles = runfiles,
    )]

runfiles_test = rule(
    _runfiles_test_impl,
    executable = True,
    test = True,
    attrs = {
        "deps": attr.label_list(
            mandatory = False,
            allow_files = False,
            aspects = [_test_suite_aspect],
        ),
    },
)
