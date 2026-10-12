{ pkgs, lib, config, ... }:
let
  chromeIncognito = pkgs.writeShellScriptBin "chrome-incognito" ''
    exec open -na "Google Chrome" --args --incognito "$@"
  '';

  chromeIncognitoApp = pkgs.runCommand "chrome-incognito-app" { } ''
    mkdir -p "$out/Applications/Chrome Incognito.app/Contents/MacOS"

    cat > "$out/Applications/Chrome Incognito.app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Chrome Incognito</string>
  <key>CFBundleIdentifier</key>
  <string>com.s1n7ax.chrome-incognito</string>
  <key>CFBundleName</key>
  <string>Chrome Incognito</string>
  <key>CFBundleDisplayName</key>
  <string>Chrome Incognito</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleVersion</key>
  <string>1.0</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
</dict>
</plist>
EOF

    cat > "$out/Applications/Chrome Incognito.app/Contents/MacOS/Chrome Incognito" <<'EOF'
#!/bin/bash
exec open -na "Google Chrome" --args --incognito "$@"
EOF
    chmod +x "$out/Applications/Chrome Incognito.app/Contents/MacOS/Chrome Incognito"

    printf 'APPL????' > "$out/Applications/Chrome Incognito.app/Contents/PkgInfo"
  '';
in
{
  config = lib.mkIf (config.features.web.chromeIncognito.enable && pkgs.stdenv.isDarwin) {
    home.packages = [
      chromeIncognito
      chromeIncognitoApp
    ];
  };
}
