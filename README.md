# Membrane Raw Audio Parser Plugin

[![Hex.pm](https://img.shields.io/hexpm/v/membrane_raw_audio_parser_plugin .svg)](https://hex.pm/packages/membrane_raw_audio_parser_plugin )
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/membrane_raw_audio_parser_plugin )
[![CircleCI](https://circleci.com/gh/membraneframework/membrane_raw_audio_parser_plugin .svg?style=svg)](https://circleci.com/gh/membraneframework/membrane_raw_audio_parser_plugin )

Plugin providing element for parsing raw audio. 
It will ensure that buffers contain full samples and can overwrite timestamps additionally.

It is part of [Membrane Multimedia Framework](https://membraneframework.org).

## Installation

The package can be installed by adding `membrane_raw_audio_parser_plugin ` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:membrane_raw_audio_parser_plugin , "~> 0.1.0"}
  ]
end
```

## Usage
```elixir
defmodule Mixing.Pipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(_ctx, _options) do
    structure = [
      child({:source, 1}, %Membrane.Hackney.Source{
        location:
          "https://raw.githubusercontent.com/membraneframework/static/gh-pages/samples/beep-s16le-48kHz-stereo.raw",
        hackney_opts: [follow_redirect: true]
      })
      |> child({:parser, 1}, %Membrane.RawAudioParser{
        stream_format: %Membrane.RawAudio{
          channels: 2,
          sample_format: :s16le,
          sample_rate: 48_000
        },
        overwrite_pts?: true,
        offset: Membrane.Time.seconds(5)
      })
      |> child(:mixer, Membrane.LiveAudioMixer)
      |> child(:player, Membrane.PortAudio.Sink)
    ]

    {[spec: structure, playback: :playing], %{}}
  end
end
```

## Copyright and License

Copyright 2023, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)