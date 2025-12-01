{
  description = "A flake to build the CTRL-OS Manual, based on the original sources";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    ctrl-os24-05.url = "github:cyberus-ctrl-os/nixpkgs?ref=ctrlos-24.05";
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
                release-24-05 = "${inputs.ctrl-os24-05.lib.trivial.release}";
                release-dir-24-05 = "ctrl-os-${release-24-05}";
                mkdocsConfig = (pkgs.formats.yaml { }).generate "mkdocs.yml" {
                  site_name = "CTRL-OS Manuals";
                  site_description = "Manuals for the Cyberus Technology Resilient Linux Releases";
                  site_author = "Cyberus Technology GmbH";
                  site_url = "https://manuals.ctrl-os.com";
                  theme = {
                    name = "material";
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
                  extra.social = [
                    {
                      icon = "material/web";
                      link = "https://cyberus-technology.de";
                      name = "Cyberus Technology";
                    }
                    {
                      icon = "fontawesome/brands/github";
                      link = "https://github.com/cyberus-technology/CTRL-OS";
                      name = "GitHub";
                    }
                    {
                      icon = "simple/matrix";
                      link = "https://matrix.to/#/#ctrl-os:cyberus-technology.de";
                      name = "Matrix Chat";
                    }
                  ];
                  extra_css = [
                    "stylesheets/custom.css"
                  ];
                  docs_dir = "docs";
                  nav = [
                    {
                      Home = "index.md";
                    }
                    {
                      "CTRL-OS Nixpkgs Manuals" = [
                        { "" = "manual.md"; }
                        { "CTRL-OS ${release-24-05}" = "${release-dir-24-05}/nixpkgs/manual.html"; }
                      ];
                    }
                    {
                      "CTRL-OS Manuals" = [
                        { "" = "ctrl-os-manual.md"; }
                        { "CTRL-OS ${release-24-05} Manual" = "${release-dir-24-05}/nixos/index.html"; }
                        { "CTRL-OS ${release-24-05} Options" = "${release-dir-24-05}/nixos/options.html"; }
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
                  ];
                }
                ''
                  mkdir -p $out
                  cp -vr --no-preserve=mode,ownership "$src" docs
                  cp -v ${mkdocsConfig} mkdocs.yml
                  MANUAL_PATH=docs/${release-dir-24-05}
                  mkdir -p $MANUAL_PATH
                  mkdir -p $MANUAL_PATH/nixpkgs
                  mkdir -p $MANUAL_PATH/nixos
                  cp -vR --no-preserve=mode,ownership ${inputs.ctrl-os24-05.htmlDocs.nixpkgsManual}/share/doc/nixpkgs/manual.html $MANUAL_PATH/nixpkgs/
                  cp -vR --no-preserve=mode,ownership ${inputs.ctrl-os24-05.htmlDocs.nixpkgsManual}/share/doc/nixpkgs/*.js $MANUAL_PATH/nixpkgs/
                  cp -vR --no-preserve=mode,ownership ${inputs.ctrl-os24-05.htmlDocs.nixpkgsManual}/share/doc/nixpkgs/*.css $MANUAL_PATH/nixpkgs/
                  cp -vR --no-preserve=mode,ownership ${inputs.ctrl-os24-05.htmlDocs.nixosManual}/share/doc/nixos/*.html $MANUAL_PATH/nixos/
                  cp -vR --no-preserve=mode,ownership ${inputs.ctrl-os24-05.htmlDocs.nixosManual}/share/doc/nixos/*.js $MANUAL_PATH/nixos/
                  cp -vR --no-preserve=mode,ownership ${inputs.ctrl-os24-05.htmlDocs.nixosManual}/share/doc/nixos/*.css $MANUAL_PATH/nixos/

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
