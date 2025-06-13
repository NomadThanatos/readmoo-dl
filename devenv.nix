{ pkgs, lib, config, ... }:

{
  languages.ruby = {
    enable = true;
    bundler.enable = true;
  };

  enterShell = ''
    bundle install
  '';

  # See full reference at https://devenv.sh/reference/options/
}

