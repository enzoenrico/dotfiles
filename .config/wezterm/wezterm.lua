-- WezTerm — Cursor / Neovim Cmd (SUPER) parity:
-- Chain(DisableDefaultAssignment, SendKey) so macOS/WezTerm does not eat the chord
-- and the pane receives kitty-protocol-encoded SUPER keys Neovim maps as <D-…>.

local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action

config.font_size = 18.0
config.window_padding = {
	left = 18,
	right = 18,
	top = 18,
	bottom = 18,
}
config.window_background_opacity = 0.92
config.macos_window_background_blur = 24

config.term = "wezterm"
config.enable_kitty_keyboard = true
config.enable_csi_u_key_encoding = false

-- Cmd+click opens links inside tmux (mouse on). Default bypass is Shift only.
config.bypass_mouse_reporting_modifiers = "SUPER|SHIFT"

-- Chain: clear WezTerm default (e.g. hide on Cmd+h), then inject the chord for the pane.
local function send_modified_key(key, mods)
	return act.Chain({
		act.DisableDefaultAssignment,
		act.SendKey({ key = key, mods = mods }),
	})
end

local keys = {
	{ key = "f", mods = "SHIFT", action = act.DisableDefaultAssignment },
	{ key = "f", mods = "CTRL|SHIFT", action = act.DisableDefaultAssignment },
}

for _, k in ipairs({ "h", "j", "k", "l" }) do
	table.insert(keys, { key = k, mods = "SUPER", action = send_modified_key(k, "SUPER") })
	table.insert(keys, { key = k, mods = "SUPER|SHIFT", action = send_modified_key(k, "SUPER|SHIFT") })
end

table.insert(keys, { key = "s", mods = "ALT|SUPER", action = send_modified_key("s", "ALT|SUPER") })
table.insert(keys, { key = "]", mods = "SUPER", action = send_modified_key("]", "SUPER") })
table.insert(keys, { key = "]", mods = "SUPER|SHIFT", action = send_modified_key("]", "SUPER|SHIFT") })
table.insert(keys, { key = "p", mods = "SUPER", action = send_modified_key("p", "SUPER") })
table.insert(keys, { key = "p", mods = "SUPER|SHIFT", action = send_modified_key("p", "SUPER|SHIFT") })

config.keys = keys

config.mouse_bindings = {
	{
		event = { Up = { streak = 1, button = "Left" } },
		mods = "SUPER",
		action = act.OpenLinkAtMouseCursor,
	},
	{
		event = { Down = { streak = 1, button = "Left" } },
		mods = "SUPER",
		action = act.Nop,
	},
}

return config
