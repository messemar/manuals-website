{
  description = "A flake to build the Cyberus Linux Manual, based on the original sources";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "https://channels.cyberus-linux.com/channel/cyberus-linux-26.05.tar.xz";
    "cyberus-linux-26.05".url = "https://channels.cyberus-linux.com/channel/cyberus-linux-26.05.tar.xz";
    preCommitHooksNix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      imports = [
        inputs.preCommitHooksNix.flakeModule
        ./checks
      ];

      perSystem =
        {
          pkgs,
          config,
          system,
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
          };

          packages = {
            manualWebsite =
              let
                inherit (inputs."cyberus-linux-26.05".lib.trivial)
                  release
                  ;
                inherit (inputs."cyberus-linux-26.05")
                  htmlDocs
                  ;
                nixpkgsManual = htmlDocs.nixpkgsManual.${system};
                nixosManual = htmlDocs.nixosManual.${system};

                slug = "cyberus-linux-${release}";

                mkdocsConfig = (pkgs.formats.yaml { }).generate "mkdocs.yml" {
                  site_name = "Cyberus Linux Manuals";
                  site_description = "Manuals for the Cyberus Linux Releases";
                  site_author = "Cyberus Technology GmbH";
                  site_url = "https://manuals.cyberus-linux.com";
                  theme = {
                    name = "material";
                    custom_dir = "docs/overrides";
                    logo = "assets/logo-white.svg";
                    favicon = "assets/favicon.ico";
                    palette = [
                      {
                        scheme = "default";
                        toggle = {
                          icon = "material/brightness-7";
                          name = "Switch to dark mode";
                        };
                      }
                      {
                        scheme = "slate";
                        toggle = {
                          icon = "material/brightness-4";
                          name = "Switch to light mode";
                        };
                      }
                    ];
                    features = [
                      "navigation.instant"
                      "navigation.tracking"
                      "navigation.tabs"
                      "navigation.tabs.sticky"
                      "navigation.sections"
                      "navigation.expand"
                      "navigation.top"
                      "search.highlight"
                      "search.share"
                      "search.suggest"
                      "content.code.copy"
                      "content.code.select"
                      "content.tooltips"
                      "toc.integrate "
                    ];
                  };
                  extra = {
                    analytics.provider = "custom";
                    social = [
                      {
                        icon = "material/web";
                        link = "https://cyberus-technology.de";
                        name = "Cyberus Technology";
                      }
                      {
                        icon = "fontawesome/brands/github";
                        link = "https://github.com/Cyberus-Linux/nixpkgs";
                        name = "GitHub";
                      }
                      {
                        icon = "simple/matrix";
                        link = "https://matrix.to/#/#cyberus-linux:cyberus-technology.de";
                        name = "Matrix Chat";
                      }
                    ];
                  };
                  extra_css = [
                    "stylesheets/custom.css"
                  ];
                  docs_dir = "docs";
                  nav = [
                    {
                      Home = "index.md";
                    }
                    {
                      "Nixpkgs Manuals" = [
                        { "" = "nixpkgs-manuals.md"; }
                        { "Cyberus Linux ${release}" = "${slug}/nixpkgs/manual.html"; }
                      ];
                    }
                    {
                      "NixOS Manuals" = [
                        { "" = "nixos-manuals.md"; }
                        { "Cyberus Linux ${release} Manual" = "${slug}/nixos/index.html"; }
                        { "Cyberus Linux ${release} Options" = "${slug}/nixos/options.html"; }
                      ];
                    }
                    { "Legal Notice" = "https://cyberus-technology.de/en/legal-notice"; }
                  ];
                };
              in
              pkgs.runCommand "manualWebsite"
                {
                  src = ./docs;
                  nativeBuildInputs = with pkgs.python3Packages; [
                    mkdocs
                    mkdocs-material
                    mkdocs-material-extensions
                    pkgs.gnused
                  ];
                }
                ''
                  mkdir -p $out
                  cp -vr --no-preserve=mode,ownership "$src" docs
                  cp -v ${mkdocsConfig} mkdocs.yml
                  MANUAL_PATH=docs/${slug}
                  mkdir -p $MANUAL_PATH
                  mkdir -p $MANUAL_PATH/nixpkgs
                  mkdir -p $MANUAL_PATH/nixos
                  cp -vR --no-preserve=mode,ownership ${nixpkgsManual}/share/doc/nixpkgs/manual.html $MANUAL_PATH/nixpkgs/
                  cp -vR --no-preserve=mode,ownership ${nixpkgsManual}/share/doc/nixpkgs/*.js $MANUAL_PATH/nixpkgs/
                  cp -vR --no-preserve=mode,ownership ${nixpkgsManual}/share/doc/nixpkgs/*.css $MANUAL_PATH/nixpkgs/
                  cp -vR --no-preserve=mode,ownership ${nixosManual}/share/doc/nixos/*.html $MANUAL_PATH/nixos/
                  cp -vR --no-preserve=mode,ownership ${nixosManual}/share/doc/nixos/*.js $MANUAL_PATH/nixos/
                  cp -vR --no-preserve=mode,ownership ${nixosManual}/share/doc/nixos/*.css $MANUAL_PATH/nixos/

                  # Adding the tracking to the static websites
                  pushd $MANUAL_PATH
                  for html in **/*.html
                    do
                      sed -i '/<\/head>/e cat ${./docs/overrides/partials/integrations/analytics/custom.html}' "$html"
                      echo "Added analytics code to $html"
                    done
                  popd

                  mkdocs build -f ./mkdocs.yml -s -d "$out"
                '';
          };

          formatter = pkgs.nixfmt-rfc-style;

          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.nixfmt-rfc-style
            ]
            ++ config.pre-commit.settings.enabledPackages;
            shellHook = config.pre-commit.installationScript;
          };
        };
    };
}
