defmodule RawAudioParserTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use Membrane.Pipeline

  import Membrane.Testing.Assertions

  alias Membrane.AudioMixer.Support.RawAudioParser
  alias Membrane.Testing.{Pipeline, Sink, Source}
  alias Membrane.{Buffer, RawAudio, Time}

  @stream_format %RawAudio{
    channels: 2,
    sample_rate: 44_100,
    sample_format: :s24le
  }

  @silence RawAudio.silence(@stream_format, Time.milliseconds(10))

  test "parser devides payloads into samples" do
    payload_bytes = div(byte_size(@silence), 2)
    <<payload::binary-size(payload_bytes), _rest::binary>> = @silence

    buffers = Enum.map(1..9, fn _idx -> payload end)

    structure = [
      child(:source, %Source{output: buffers, stream_format: @stream_format})
      |> child(:parser, RawAudioParser)
      |> child(:sink, Sink)
    ]

    assert pipeline = Pipeline.start_link_supervised!(structure: structure)

    extended_payload = RawAudio.silence(@stream_format, Time.milliseconds(5))

    <<^extended_payload::binary-size(byte_size(extended_payload)), truncated_payload::binary>> =
      @silence

    Enum.each(1..5, fn _idx ->
      assert_sink_buffer(pipeline, :sink, %Buffer{pts: nil, payload: ^truncated_payload})
    end)

    Enum.each(1..4, fn _idx ->
      assert_sink_buffer(pipeline, :sink, %Buffer{pts: nil, payload: ^extended_payload})
    end)

    assert_sink_buffer(pipeline, :sink, %Buffer{pts: nil, payload: <<0, 0, 0>>})

    assert_end_of_stream(pipeline, :sink)
  end

  test "parser adds timestamps" do
    buffers = Enum.map(1..10, fn _idx -> @silence end)

    structure = [
      child(:source, %Source{output: buffers, stream_format: @stream_format})
      |> child(:parser, %RawAudioParser{overwrite_pts?: true})
      |> child(:sink, Sink)
    ]

    assert pipeline = Pipeline.start_link_supervised!(structure: structure)

    Enum.each(0..9, fn idx ->
      pts = idx * Time.milliseconds(10)
      assert_sink_buffer(pipeline, :sink, %Buffer{pts: ^pts, payload: @silence})
    end)

    assert_end_of_stream(pipeline, :sink)
  end

  test "parser adds timestamps with offset" do
    offset = 10
    buffers = Enum.map(1..10, fn _idx -> @silence end)

    structure = [
      child(:source, %Source{output: buffers, stream_format: @stream_format})
      |> child(:parser, %RawAudioParser{overwrite_pts?: true, offset: offset})
      |> child(:sink, Sink)
    ]

    assert pipeline = Pipeline.start_link_supervised!(structure: structure)

    Enum.each(0..9, fn idx ->
      pts = idx * Time.milliseconds(10) + offset
      assert_sink_buffer(pipeline, :sink, %Buffer{pts: ^pts, payload: @silence})
    end)

    assert_end_of_stream(pipeline, :sink)
  end
end
