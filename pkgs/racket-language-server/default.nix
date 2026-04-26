{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchzip,
  makeWrapper,
  racket,
}:

let
  html-parsing = fetchzip {
    url = "https://www.neilvandyke.org/racket/html-parsing.zip";
    # Racket catalog checksum: 8b469e50b1629c3f694a458fc9f797258b362adb
    hash = "sha256-a+EzAtYC0Jj+luddIcOXvelxe/dIp6E4s8b2Hr3oesI=";
  };

  mcfly = fetchzip {
    url = "https://www.neilvandyke.org/racket/mcfly.zip";
    # Racket catalog checksum: e670b083eefe6ac27c23cc9423bac0f31720d58c
    hash = "sha256-gAA/Uqyis4FWkWj0mMim5mlFOr6QjpCUW71y/+lqNZM=";
  };

  overeasy = fetchzip {
    url = "https://www.neilvandyke.org/racket/overeasy.zip";
    # Racket catalog checksum: f7cff9a14b313c4a51e1dcd47bb3aa4fe7d50526
    hash = "sha256-3xgr35Ba5ngeu2aeew6vevTZeJA/JRy57QWcFBht3Zk=";
  };

  fixw = fetchFromGitHub {
    owner = "6cdh";
    repo = "racket-fixw";
    rev = "b93ec4e13223533b1897e269f2245bad16fe3c45";
    # Racket catalog checksum, used as the git revision above.
    hash = "sha256-PC+JTSmgz+LSQTasEAKXWidu1bOUroMtBoOeHMgpV5U=";
  };
in

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "racket-language-server";
  version = "0-unstable-2026-04-14";

  src = fetchFromGitHub {
    owner = "jeapostrophe";
    repo = "racket-langserver";
    rev = "5cbf431c8e7e62c75b64b7b3a3a672d73daaa5f4";
    hash = "sha256-79C48QcBSbcEpTYBZGQ4dGMa2h/CCmED9zEVUiQuaZ8=";
  };

  nativeBuildInputs = [
    makeWrapper
    racket
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    export HOME="$TMPDIR/home"
    export PLTADDONDIR="$out/share/racket"
    mkdir -p "$HOME" "$PLTADDONDIR" "$out/bin"

    raco pkg install \
      --batch --copy --deps force --no-setup --user \
      --name mcfly \
      --checksum e670b083eefe6ac27c23cc9423bac0f31720d58c \
      ${mcfly}
    raco pkg install \
      --batch --copy --deps force --no-setup --user \
      --name overeasy \
      --checksum f7cff9a14b313c4a51e1dcd47bb3aa4fe7d50526 \
      ${overeasy}
    raco pkg install \
      --batch --copy --deps fail --no-setup --user \
      --name html-parsing \
      --checksum 8b469e50b1629c3f694a458fc9f797258b362adb \
      ${html-parsing}
    raco pkg install \
      --batch --copy --deps fail --no-setup --user \
      --name fixw \
      --checksum b93ec4e13223533b1897e269f2245bad16fe3c45 \
      ${fixw}

    raco pkg install \
      --batch \
      --copy \
      --deps force \
      --no-setup \
      --user \
      --name racket-langserver \
      "$PWD"

    makeWrapper ${lib.getExe racket} "$out/bin/racket-language-server" \
      --add-flags "-A" \
      --add-flags "$PLTADDONDIR" \
      --add-flags "-l" \
      --add-flags "racket-langserver"

    ln -s racket-language-server "$out/bin/racket-langserver"

    runHook postInstall
  '';

  meta = {
    description = "Language Server Protocol implementation for Racket";
    homepage = "https://github.com/jeapostrophe/racket-langserver";
    license = lib.licenses.mit;
    mainProgram = "racket-language-server";
    platforms = racket.meta.platforms;
  };
})
