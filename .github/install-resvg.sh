#!/usr/bin/env bash
# Installs the resvg program that the diagram renderer needs into DIR, a new
# directory, for CI (run_tests.yml and release.yml). Put DIR first on PATH.
# Locally, `just setup` installs resvg through mise.toml instead.
#
# The version comes from ConceptQL::DiagramRenderer::Resvg::VERSION, not from a
# copy here. The checksum of the release tarball is pinned in
# .github/resvg-linux-x86_64.tar.gz.sha256, in the same `sha256sum -c` format as
# the test data pins. A version change without a new pin fails the checksum.
set -euo pipefail

dir=${1:?usage: .github/install-resvg.sh DIR}
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
version=$(ruby -I"$root/lib" -rconceptql/diagram_renderer/resvg -e 'print ConceptQL::DiagramRenderer::Resvg::VERSION')
asset=resvg-linux-x86_64.tar.gz
pin="$root/.github/$asset.sha256"

mkdir "$dir"
echo "Downloading resvg ${version} into ${dir}"
curl -fsSL --retry 3 --retry-delay 5 -o "$dir/$asset" \
	"https://github.com/linebender/resvg/releases/download/v${version}/${asset}"
if ! (cd "$dir" && sha256sum -c "$pin"); then
	echo "The resvg ${version} tarball does not match ${pin}. If Resvg::VERSION changed, pin the new tarball's sha256 there."
	exit 1
fi
tar -xzf "$dir/$asset" -C "$dir" resvg
have=$("$dir/resvg" --version)
if [ "$have" != "$version" ]; then
	echo "The installed resvg prints version ${have}, not ${version}."
	exit 1
fi
echo "resvg ${have} is at ${dir}/resvg"
