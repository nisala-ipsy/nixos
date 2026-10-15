{
  config,
  lib,
  pkgs,
  ...
}:
let
  ai = config.features.development.ai;
  cfg = ai.mcp;

  # ha-mcp only takes credentials from the environment. Read the token from
  # sops at launch so it never lands in the store or a generated MCP config.
  homeAssistantMcp = pkgs.writeShellScript "home-assistant-mcp" ''
    set -eu
    export HOMEASSISTANT_URL=${lib.escapeShellArg cfg.home-assistant.url}
    HOMEASSISTANT_TOKEN="$(< ${lib.escapeShellArg config.sops.secrets."home-assistant/mcp_token".path})"
    export HOMEASSISTANT_TOKEN
    exec ${lib.getExe pkgs.ha-mcp} "$@"
  '';

  # Partner client IDs live outside the repo. Default path is per-user; override
  # with features.development.ai.mcp.slack.clientsFile. Requires impure eval.
  slackClientsFile =
    if cfg.slack.clientsFile != null then
      cfg.slack.clientsFile
    else
      "${config.home.homeDirectory}/.config/nixos/mcp-slack-clients.json";

  slackClients =
    if cfg.slack.enable then
      builtins.fromJSON (builtins.readFile slackClientsFile)
    else
      { };

  # Single MCP fleet, with each server enabled or disabled per-host through the
  # profile's features.development.ai.mcp.* options.
  servers =
    lib.optionalAttrs cfg.nixos.enable {
      nixos.command = lib.getExe pkgs.mcp-nixos;
    }
    // lib.optionalAttrs cfg.playwright.enable {
      playwright = {
        command = lib.getExe pkgs.playwright-mcp;
        args = lib.optional cfg.playwright.headless "--headless";
      };
    }
    // lib.optionalAttrs cfg.context7.enable {
      context7.command = lib.getExe pkgs.context7-mcp;
    }
    // lib.optionalAttrs cfg.svelte.enable {
      svelte = {
        command = "npx";
        args = [
          "-y"
          "@sveltejs/mcp"
        ];
      };
    }
    // lib.optionalAttrs cfg.nextjs.enable {
      nextjs = {
        command = "npx";
        args = [
          "-y"
          "next-devtools-mcp@latest"
        ];
      };
    }
    // lib.optionalAttrs cfg.tailwindcss.enable {
      tailwindcss = {
        command = "npx";
        args = [
          "-y"
          "tailwindcss-mcp-server"
        ];
      };
    }
    // lib.optionalAttrs cfg.chakra-ui.enable {
      chakra-ui = {
        command = "npx";
        args = [
          "-y"
          "@chakra-ui/react-mcp"
        ];
      };
    }
    // lib.optionalAttrs cfg.jira.enable {
      jira.url = "https://mcp.atlassian.com/v2/mcp";
    }
    // lib.optionalAttrs cfg.slack.enable {
      # Slack rejects dynamic client registration. Put both partner clients
      # in the shared fleet: Claude oauth.clientId for Pi, Cursor
      # auth.CLIENT_ID for Cursor. Slack only registers
      # http://localhost:3118/callback for Claude — pin that callbackUrl
      # because Pi's default callbackPort URI uses 127.0.0.1.
      slack = {
        url = "https://mcp.slack.com/mcp";
        oauth = {
          clientId = slackClients.claudeClientId;
          callbackPort = 3118;
          callbackUrl = "http://localhost:3118/callback";
        };
        auth.CLIENT_ID = slackClients.cursorClientId;
      };
    }
    // lib.optionalAttrs cfg.home-assistant.enable {
      home-assistant.command = "${homeAssistantMcp}";
    };
in
{
  config = lib.mkIf ai.enable (
    lib.mkMerge [
      {
        assertions = lib.optional cfg.slack.enable {
          assertion =
            (slackClients ? claudeClientId)
            && (slackClients.claudeClientId != "")
            && (slackClients ? cursorClientId)
            && (slackClients.cursorClientId != "");
          message = ''
            features.development.ai.mcp.slack.enable requires ${slackClientsFile}
            with non-empty claudeClientId and cursorClientId.
            See system/home-manager/applications/dev/ai/mcp-slack-clients.json.example.
          '';
        };

        programs.mcp = {
          enable = true;
          servers = servers;
        };
      }

      # Claude Code ignores ~/.config/mcp/mcp.json; home-manager wraps `claude`
      # with a generated --plugin-dir carrying the same server list instead. Pi
      # gets the shared instructions via ~/.pi/agent/AGENTS.md in pi.nix.
      (lib.mkIf ai.claude.enable {
        programs.claude-code.mcpServers = servers;
      })

      /**
        Pi's built-in MCP support reads only ~/.pi/agent/mcp.json, so link it
        to the shared file. The link is read-only: toggling a server globally
        in Pi's `/mcp` fails; "Disable in this project" writes .pi/mcp.json.
      */
      (lib.mkIf ai.pi.enable {
        home.file.".pi/agent/mcp.json".source = config.xdg.configFile."mcp/mcp.json".source;
      })

      (lib.mkIf cfg.home-assistant.enable {
        sops.secrets."home-assistant/mcp_token" = { };
      })
    ]
  );
}
