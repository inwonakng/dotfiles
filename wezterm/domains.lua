return {
  ssh_domains = {
    {
      -- This name identifies the domain
      name = 'idea-node-07',
      -- The hostname or address to connect to. Will be used to match settings
      -- from your ssh config file
      remote_address = 'idea-node-07',
      -- The username to use on the remote host
      username = 'kangi',
    },
  }
}
