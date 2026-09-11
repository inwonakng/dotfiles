This repository is the dotfiles for various systems. It's the central place to manage and maintain configuration of the various apps I use daily.

The relevant directories are symlinked to the appropriate locations for each system. To check how things are automatically linked, you can view the setup scripts in `./scripts/setup/{local,remote}.sh`. local assumes a mac machine, while remote assumes a linux machine.

**Good practices**

- Do not use `chmod` on helper scripts. prefer to use `bash` or `sh` to execute them. 
- Do not write "tests". If you need to validate certain behavior, use a separate script in a throwaway directory under `$TMPDIR`, keep it outside the repository, and remove it when finished. If you really think a test is necessary, ask the user.
- Read `README.md` to check what apps are configured and how they work.
