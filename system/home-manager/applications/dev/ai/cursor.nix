{
  pkgs,
  pkgs-unstable,
  config,
  lib,
  ...
}:
let
  commonRules = builtins.readFile ./AGENTS.md;
  ai = config.features.development.ai;
  jsonFormat = pkgs.formats.json { };

  # Cursor's Slack partner client uses auth.CLIENT_ID; Pi rejects that shape
  # (auth.provider must be a provider name) and needs oauth.clientId instead.
  # Shared ~/.config/mcp/mcp.json stays Pi-safe; rewrite Slack for Cursor.
  cursorServers =
    let
      servers = config.programs.mcp.servers;
    in
    servers
    // lib.optionalAttrs (servers ? slack) {
      slack = {
        url = "https://mcp.slack.com/mcp";
        auth.CLIENT_ID = "3660753192626.8903469228982";
      };
    };

  cursorMcpJson = jsonFormat.generate "cursor-mcp.json" {
    mcpServers = lib.mapAttrs (
      _: server:
      lib.hm.mcp.transformMcpServer {
        inherit server;
        extraTransforms = [ lib.hm.mcp.addType ];
        exclude = [ "serverUrl" ];
      }
    ) cursorServers;
  };
in
{
  config = lib.mkIf ai.cursor.enable (
    lib.mkMerge [
      {
        # Cursor CLI agent (cursor.com/cli, binary `cursor-agent`).
        #
        # BYOK: like the other agents here, this repo does not provision a
        # credential for it. Authenticate manually, once per machine, with an
        # interactive login or by exporting CURSOR_API_KEY before invoking it.
        home.packages = [ pkgs-unstable.cursor-cli ];

        # Global rules (same rules system as the editor's .cursor/rules).
        # Project-root AGENTS.md/CLAUDE.md files are picked up automatically
        # on top of this.
        home.file.".cursor/rules/standards.mdc".text = ''
          ---
          description: Shared working-relationship rules for every repo
          alwaysApply: true
          ---
          ${commonRules}
        '';
      }

      # Cursor reads ~/.cursor/mcp.json. Same fleet as programs.mcp, but Slack
      # is rewritten to Cursor's auth.CLIENT_ID (see cursorServers above).
      (lib.mkIf (config.programs.mcp.servers != { }) {
        home.file.".cursor/mcp.json".source = cursorMcpJson;
      })
    ]
  );
}
