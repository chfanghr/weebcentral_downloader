{
  description = "WeebCentral Manga Downloader";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          pythonEnv = pkgs.python3.withPackages (
            ps: with ps; [
              beautifulsoup4
              ebooklib
              fpdf2
              pillow
              pyqt6
              requests
              tqdm
            ]
          );
          pname = "weebcentral-downloader";
          fsHelperName = "start-flaresolverr";
          fsPyHelperName = "start-flaresolverr-py";
        in
        {
          default = pkgs.stdenv.mkDerivation {
            inherit pname;
            version = "unstable";
            src = self;

            nativeBuildInputs = [
              pkgs.makeWrapper
              pkgs.qt6.wrapQtAppsHook
            ];

            buildInputs = [
              pkgs.qt6.qtbase
            ];

            dontBuild = true;

            installPhase = ''
              runHook preInstall

              mkdir -p $out/share/${pname} $out/bin
              cp -r . $out/share/${pname}
              chmod -R u+w $out/share/${pname}
              find $out/share/${pname} -type d -name __pycache__ -prune -exec rm -rf {} +

              install -Dm755 $src/start_flaresolverr.py $out/share/${pname}/start_flaresolverr.py

              cat > $out/bin/start-flaresolverr <<'EOF'
              #!${pkgs.runtimeShell}
              set -eu

              health_url="http://127.0.0.1:8191/health"

              if curl -fsS "$health_url" >/dev/null 2>&1; then
                exit 0
              fi

              state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/weebcentral-downloader"
              mkdir -p "$state_dir"

              log_file="$state_dir/flaresolverr.log"
              flaresolverr >"$log_file" 2>&1 &
              fs_pid=$!

              for _ in 1 2 3 4 5 6 7 8 9 10; do
                sleep 1
                if curl -fsS "$health_url" >/dev/null 2>&1; then
                  exit 0
                fi

                if ! kill -0 "$fs_pid" >/dev/null 2>&1; then
                  break
                fi
              done

              echo "Warning: FlareSolverr did not report healthy on port 8191" >&2
              exit 0
              EOF
              chmod +x $out/bin/start-flaresolverr

              cat > $out/bin/${fsPyHelperName} <<EOF
              #!${pkgs.runtimeShell}
              exec ${pythonEnv}/bin/python $out/share/${pname}/start_flaresolverr.py "$@"
              EOF
              chmod +x $out/bin/${fsPyHelperName}

              cat > $out/bin/${pname} <<'EOF'
              #!${pkgs.runtimeShell}
              script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
              share_dir=$(CDPATH= cd -- "$script_dir/../share/${pname}" && pwd)
              "$script_dir/start-flaresolverr"
              exec ${pythonEnv}/bin/python "$share_dir/run_gui.py" "$@"
              EOF
              chmod +x $out/bin/${pname}

              cat > $out/bin/${pname}-cli <<'EOF'
              #!${pkgs.runtimeShell}
              script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
              share_dir=$(CDPATH= cd -- "$script_dir/../share/${pname}" && pwd)
              "$script_dir/start-flaresolverr"
              exec ${pythonEnv}/bin/python "$share_dir/weebcentral_scraper.py" "$@"
              EOF
              chmod +x $out/bin/${pname}-cli

              runHook postInstall
            '';

            postFixup = ''
              wrapQtApp $out/bin/${pname}
              wrapProgram $out/bin/${pname} --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.curl pkgs.flaresolverr ]}
              wrapProgram $out/bin/${pname}-cli --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.curl pkgs.flaresolverr ]}
              wrapProgram $out/bin/${fsPyHelperName} --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.curl pkgs.flaresolverr ]}
            '';

            meta = with pkgs.lib; {
              description = "Manga downloader for WeebCentral with a PyQt6 GUI";
              homepage = "https://github.com/Yui007/weebcentral_downloader";
              license = licenses.mit;
              mainProgram = pname;
              platforms = platforms.linux;
            };
          };
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = {
            type = "app";
            program = "${self.packages.${system}.default}/bin/weebcentral-downloader";
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          pythonEnv = pkgs.python3.withPackages (
            ps: with ps; [
              beautifulsoup4
              ebooklib
              fpdf2
              pillow
              pyqt6
              requests
              tqdm
            ]
          );
        in
        {
          default = pkgs.mkShell {
            packages = [
              pythonEnv
              pkgs.qt6.qtbase
            ];

            shellHook = ''
              export PYTHONPATH=$PWD:$PYTHONPATH
            '';
          };
        }
      );
    };
}
