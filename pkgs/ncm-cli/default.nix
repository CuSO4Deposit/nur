{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs,
}:

buildNpmPackage rec {
  pname = "ncm-cli";
  version = "0.1.7";

  src = fetchurl {
    url = "https://registry.npmjs.org/@music163/ncm-cli/-/ncm-cli-${version}.tgz";
    hash = "sha256-2WefoqInGtAl8t1aERDR1eplycSza1rXCnVb51/gW7k=";
  };

  # The published tarball only contains dist/ and package.json. Keep a lockfile
  # in the repository so dependency resolution stays reproducible.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-H/0ShHG9JKL4dNNz+G2q2zeWwnjMwueSzcEODLCNBhA=";
  dontNpmBuild = true;
  npmRebuildFlags = [ "--ignore-scripts" ];
  npmPruneFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    rm -f "$out/bin/ncm-cli"
    makeWrapper "${lib.getExe nodejs}" "$out/bin/ncm-cli" \
      --add-flags "$out/lib/node_modules/@music163/ncm-cli/dist/index.js" \
      --prefix PATH : "${lib.makeBinPath [ nodejs ]}"
  '';

  meta = {
    description = "Netease Music CLI";
    homepage = "https://www.npmjs.com/package/@music163/ncm-cli";
    license = lib.licenses.mit;
    mainProgram = "ncm-cli";
    platforms = lib.platforms.unix;
  };
}
