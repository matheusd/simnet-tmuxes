# Simnet Tmuxes

This repo contains a bunch of tmux automation scripts that ease setup/execution/teardown of simnet's for decred (and eventually other cryptocurrencies).

Most of the scripts can be run as `./script.tmux` with little or no previous setup.

In general, you'll need to have the decred tools (`dcrd`, `dcrctl`, `dcrwallet`, etc) installed in your `$GOPATH/bin` dir (or otherwise accesible on your `$PATH`).

## Super Quick Tmux Cheatsheet

For more, see: https://gist.github.com/MohamedAlaa/2961058

**Ctrl+B**, then:

```
    c  create window
    n  next window
    p  previous window

    %  vertical split
    "  horizontal split
    o  swap panes

    alt + {←,↑,→,↓}  resize pane

    [  copy mode
    :  "command" mode
```

## License

Unless otherwise noted, all work is released under the [Unlicense](http://unlicense.org) license.

See the accompanying LICENSE file.
