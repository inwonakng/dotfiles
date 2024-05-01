return {
	ssh_domains = {
		{
			-- This name identifies the domain
			name = "idea-node-07",
			-- The hostname or address to connect to. Will be used to match settings
			-- from your ssh config file
			remote_address = "idea-node-07",
			-- The username to use on the remote host
			username = "kangi",
		},
	},
	-- unix_domains = {
	-- 	{
	-- 		name = "unix",
	-- 	},
	-- },

	-- This causes `wezterm` to act as though it was started as
	-- `wezterm connect unix` by default, connecting to the unix
	-- domain on startup.
	-- If you prefer to connect manually, leave out this line.
	-- default_gui_startup_args = { "connect", "unix" },
	-- default_gui_startup_args = {},
}
