#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

module_id="blarg_targets"
module_location="https://github.com/pcrockett/blarg-targets.git"
module_ref="v0.5.1"

write_target() {
    local target_path="${1}"
    cat >"${target_path}" <<'EOF'
#!/usr/bin/env blarg
satisfied_if() { true; }
EOF
}

main() {
    local num_targets="${1:-100}"
    if [ "$#" -gt 1 ] || ! [[ "${num_targets}" =~ ^[1-9][0-9]*$ ]]; then
        echo "usage: ${0} [num_targets]" >&2
        return 2
    fi

    # global so the EXIT trap can still see it after main returns
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "${tmp_dir}"' EXIT
    # route signals through exit so the EXIT trap above still cleans up
    trap 'exit 130' INT
    trap 'exit 143' TERM

    mkdir "${tmp_dir}/bin" "${tmp_dir}/targets"
    cp "${repo_root}/blarg" "${tmp_dir}/bin/blarg"
    export PATH="${tmp_dir}/bin:${PATH}"

    cat >"${tmp_dir}/blarg.conf" <<EOF
[module.${module_id}]
location = ${module_location}
ref = ${module_ref}
EOF

    printf '#!/usr/bin/env blarg\n' >"${tmp_dir}/targets/main.bash"
    local i target_name
    for ((i = 1; i <= num_targets; i++)); do
        printf -v target_name 'target_%03d' "${i}"
        write_target "${tmp_dir}/targets/${target_name}.bash"
        printf 'depends_on %s\n' "${target_name}" >>"${tmp_dir}/targets/main.bash"
    done
    # blarg executes dependency targets directly, so they need the executable bit
    chmod +x "${tmp_dir}/targets/"*.bash

    cd "${tmp_dir}"

    # warmup: clones external modules into .blarg/ so the clone cost is not timed
    echo "warmup: running a single target to clone external module '${module_id}' (${module_ref})..."
    blarg ./targets/target_001.bash

    echo "timed run: ${num_targets} targets..."
    local start_ns end_ns elapsed_ns
    start_ns="$(date +%s%N)"
    blarg ./targets/main.bash
    end_ns="$(date +%s%N)"
    elapsed_ns=$((end_ns - start_ns))

    awk -v num_targets="${num_targets}" -v elapsed_ns="${elapsed_ns}" \
        'BEGIN { printf "%d targets in %.2fs (%.1fms/target)\n", num_targets, elapsed_ns / 1e9, elapsed_ns / 1e6 / num_targets }'
}

main "$@"
