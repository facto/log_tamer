# LogTamer

Capture, flush and resume logging in the console.

A quick-and-dirty solution to runaway console logs when using Elixir's awesome
`iex -S mix`. For use during development.


## Why?

Have you ever been typing something in the console during development only to
have it clobbered by log output?

That's why I built this.

Well, I say built. It's mostly adapted from ExUnit's log capturing functionality
to fit a console development workflow.


## Installation

First, install the package. Then you may want to place something like this into
your [.iex.exs file](https://hexdocs.pm/iex/IEx.html#module-the-iex-exs-file):

```elixir
import LogTamer, only: [cl: 0, fl: 0, rl: 0, capture_log: 0, flush_log: 0, release_log: 0]
```


## Usage

This assumes you have imported these functions in your .iex.exs file (see
above).  If not, you'll need to prefix them with `LogTamer`, like `LogTamer.cl`.

To begin capturing:

`cl()`

Yep. It's that easy.

After this, you should see no more logs until you want to see them.

To flush captured logs:

`fl()`

This will output all captured logs since the previous flush.

To resume logging as normal:

`rl()`

You should now see logs appear in the console again, as normal.


## Installation

The package can be installed by adding `log_tamer` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:log_tamer, "~> 0.5.0"}
  ]
end
```
