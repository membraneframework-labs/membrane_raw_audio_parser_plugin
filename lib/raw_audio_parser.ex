defmodule Membrane.RawAudioParser do
  @moduledoc """
  This element is responsible for parsing audio in RawAudio format.
  """

  use Membrane.Filter

  alias Membrane.RemoteStream
  alias Membrane.{Buffer, RawAudio}

  def_options stream_format: [
                spec: RawAudio.t() | nil,
                description: """
                The value defines a raw audio format of the input pad.
                """,
                default: nil
              ],
              overwrite_pts?: [
                spec: boolean(),
                description: """
                If set to true RawAudioParser will add timestamps based on payload duration
                """,
                default: false
              ],
              offset: [
                spec: non_neg_integer(),
                description: """
                If set to value different than 0, RawAudioParser will start timestamps from offset.
                """,
                default: 0
              ]

  def_input_pad :input,
    demand_mode: :auto,
    accepted_format:
      any_of(
        RawAudio,
        Membrane.RemoteStream
      ),
    availability: :always

  def_output_pad :output,
    demand_mode: :auto,
    availability: :always,
    accepted_format: RawAudio

  @impl true
  def handle_init(_ctx, options) do
    state =
      options
      |> Map.from_struct()
      |> Map.put(:next_pts, options.offset)
      |> Map.put(:acc, <<>>)

    {[], state}
  end

  @impl true
  def handle_stream_format(
        _pad,
        %RemoteStream{},
        _context,
        %{stream_format: nil}
      ),
      do:
        raise("""
        You need to specify `stream_format` in options if `Membrane.RemoteStream` will be received on the `:input` pad
        """)

  @impl true
  def handle_stream_format(
        _pad,
        stream_format,
        _context,
        %{stream_format: nil} = state
      ),
      do: {[stream_format: {:output, stream_format}], %{state | stream_format: stream_format}}

  @impl true
  def handle_stream_format(
        _pad,
        %RemoteStream{},
        _context,
        %{stream_format: stream_format} = state
      ) do
    {[stream_format: {:output, stream_format}], state}
  end

  @impl true
  def handle_stream_format(
        _pad,
        stream_format,
        _context,
        %{stream_format: stream_format} = state
      ),
      do: {[stream_format: {:output, stream_format}], state}

  @impl true
  def handle_stream_format(_pad, input_stream_format, _context, %{stream_format: stream_format}),
    do:
      raise(
        "Stream format on input pad: #{inspect(input_stream_format)} is different than the one passed in option: #{inspect(stream_format)}"
      )

  @impl true
  def handle_process(
        _pad,
        buffer,
        _context,
        %{stream_format: stream_format, overwrite_pts?: overwrite_pts?} = state
      ) do
    payload = state.acc <> buffer.payload
    sample_size = RawAudio.sample_size(stream_format) * stream_format.channels

    parsed_payload_bytes = byte_size(payload) - rem(byte_size(payload), sample_size)

    <<parsed_payload::binary-size(parsed_payload_bytes), acc::binary>> = payload
    state = %{state | acc: acc}

    if parsed_payload == <<>> do
      {[], state}
    else
      parsed_buffer = %Buffer{buffer | payload: parsed_payload}

      {parsed_buffer, state} =
        if overwrite_pts?, do: overwrite_pts(parsed_buffer, state), else: {parsed_buffer, state}

      {[buffer: {:output, parsed_buffer}], state}
    end
  end

  @impl true
  def handle_end_of_stream(_pad, _context, %{acc: <<>>} = state),
    do: {[end_of_stream: :output], state}

  @impl true
  def handle_end_of_stream(
        _pad,
        _context,
        %{acc: acc, overwrite_pts?: overwrite_pts?} = state
      ) do
    buffer = %Buffer{payload: acc}
    {buffer, state} = if overwrite_pts?, do: overwrite_pts(buffer, state), else: {buffer, state}
    {[buffer: {:output, buffer}, end_of_stream: :output], %{state | acc: <<>>}}
  end

  defp overwrite_pts(
         %{payload: payload} = buffer,
         %{next_pts: next_pts, stream_format: stream_format} = state
       ) do
    duration = RawAudio.bytes_to_time(byte_size(payload), stream_format)
    {%{buffer | pts: next_pts}, %{state | next_pts: next_pts + duration}}
  end
end
