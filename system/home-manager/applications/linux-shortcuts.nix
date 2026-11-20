{
  lib,
  config,
  pkgs,
  ...
}:
let
  # Ctrl stays Ctrl here, like in a Linux terminal.
  terminals = [
    "^net\\.kovidgoyal\\.kitty$"
    "^com\\.apple\\.Terminal$"
    "^com\\.googlecode\\.iterm2$"
    "^com\\.mitchellh\\.ghostty$"
    "^com\\.github\\.wez\\.wezterm$"
    "^org\\.alacritty$"
  ];

  outside_terminals = [
    {
      type = "frontmost_application_unless";
      bundle_identifiers = terminals;
    }
  ];

  remap = from: to: {
    type = "basic";
    inherit from to;
  };

  key = key_code: mandatory: {
    inherit key_code;
    modifiers = {
      inherit mandatory;
      optional = [ "caps_lock" ];
    };
  };

  /**
    Ctrl+<key>, with or without Shift, becomes <modifier>+<key> outside
    terminals. Shift carries through, so Ctrl+Shift+Z (redo) and
    Ctrl+Shift+T (reopen tab) follow.
  */
  ctrl_as =
    modifier: key_code:
    (remap
      {
        inherit key_code;
        modifiers = {
          mandatory = [ "control" ];
          optional = [
            "shift"
            "caps_lock"
          ];
        };
      }
      [
        {
          inherit key_code;
          modifiers = [ modifier ];
        }
      ]
    )
    // {
      conditions = outside_terminals;
    };

  # App shortcuts use Cmd on macOS.
  ctrl_as_cmd = map (ctrl_as "left_command") (lib.stringToCharacters "cxvzasftwnrlpo");

  # Word-wise movement and deletion use Option on macOS.
  ctrl_word = map (ctrl_as "left_option") [
    "left_arrow"
    "right_arrow"
    "delete_or_backspace"
    "delete_forward"
  ];

  # Ctrl+Y is redo on Linux; Cmd+Y is history in browsers.
  ctrl_y_redo =
    (remap (key "y" [ "control" ]) [
      {
        key_code = "z";
        modifiers = [
          "left_command"
          "left_shift"
        ];
      }
    ])
    // {
      conditions = outside_terminals;
    };

  aerospace_key_code = name: { enter = "return_or_enter"; }.${name} or name;
  aerospace_modifier = name: { alt = "option"; }.${name} or name;

  /**
    Physical Super+<key> becomes Cmd+Ctrl+<key> for every AeroSpace binding,
    which aerospace.nix moved there so Ctrl+<key> → Cmd+<key> stays free for
    apps. Read from AeroSpace's binding list so the two never drift.
  */
  super_for_aerospace =
    let
      bindings = lib.attrByPath [ "mode" "main" "binding" ] { } config.programs.aerospace.settings;
      hidden = lib.filter (lib.hasPrefix "cmd-ctrl-") (lib.attrNames bindings);
    in
    map (
      name:
      let
        parts = lib.splitString "-" (lib.removePrefix "cmd-ctrl-" name);
        key_code = aerospace_key_code (lib.last parts);
        modifiers = map aerospace_modifier (lib.init parts);
      in
      remap (key key_code ([ "command" ] ++ modifiers)) [
        {
          inherit key_code;
          modifiers = [
            "left_command"
            "left_control"
          ]
          ++ map (m: "left_${m}") modifiers;
        }
      ]
    ) hidden;

  karabiner_json = pkgs.writeText "karabiner.json" (
    builtins.toJSON {
      profiles = [
        {
          name = "Default";
          selected = true;
          # Skips Karabiner's "which keyboard type?" prompt.
          virtual_hid_keyboard.keyboard_type_v2 = "ansi";
          complex_modifications.rules = [
            {
              description = "Super drives AeroSpace";
              manipulators = super_for_aerospace;
            }
            {
              description = "Linux-style Ctrl shortcuts outside terminals";
              manipulators = ctrl_as_cmd ++ [ ctrl_y_redo ] ++ ctrl_word;
            }
          ];
        }
      ];
    }
  );

  /**
    Home/End jump to the line start/end in text fields. Done here rather than
    in Karabiner because Cmd+Left on a web page is "Back"; these bindings
    only apply where text is being edited. Apps read this at launch.
  */
  key_bindings = pkgs.writeText "DefaultKeyBinding.dict" ''
    {
      "\UF729" = "moveToBeginningOfLine:";
      "\UF72B" = "moveToEndOfLine:";
      "$\UF729" = "moveToBeginningOfLineAndModifySelection:";
      "$\UF72B" = "moveToEndOfLineAndModifySelection:";
    }
  '';
in
lib.mkIf config.features.desktop.linuxShortcuts.enable {
  /**
    Copied, not linked: macOS ignores a symlinked DefaultKeyBinding.dict, and
    Karabiner rewrites karabiner.json in place, which would swap a symlink for
    a plain file that later switches refuse to overwrite. Settings changed in
    the Karabiner app are reset on the next switch. Karabiner itself is a
    Homebrew cask, installed by profile/macbook/configuration.nix.
  */
  home.activation.linuxShortcuts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run install -Dm644 $VERBOSE_ARG ${karabiner_json} "${config.xdg.configHome}/karabiner/karabiner.json"
    run install -Dm644 $VERBOSE_ARG ${key_bindings} "${config.home.homeDirectory}/Library/KeyBindings/DefaultKeyBinding.dict"
  '';
}
