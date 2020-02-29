defmodule ResxCSV.Encoder do
    @moduledoc """
      Encode data resources into strings of CSV.

      ### Media Types

      Only `x.erlang.native` types are valid. This can either be a subtype or suffix.

      Valid: `application/x.erlang.native`, `application/geo+x.erlang.native`.
      If an error is being returned when attempting to open a data URI due to
      `{ :invalid_reference, "invalid media type: \#{type}" }`, the MIME type
      will need to be added to the config.

      To add additional media types to be encoded, that can be done by configuring
      the `:native_types` option.

        config :resx_csv,
            native_types: [
                { "application/x.my-type", &("application/\#{&1}"), &(&1) }
            ]

      The `:native_types` field should contain a list of 3 element tuples with the
      format `{ pattern :: String.pattern | Regex.t, (replacement_type :: String.t -> replacement :: String.t), preprocessor :: (Resx.Resource.content -> Resx.Resource.content) }`.

      The `pattern` and `replacement` are arguments to `String.replace/3`. While the
      preprocessor performs any operations on the content before it is encoded.

      The replacement becomes the new media type of the transformed resource. Nested
      media types will be preserved. By default the current matches will be replaced
      (where the `x.erlang.native` type part is), with the new type (currently `csv`),
      in order to denote that the content is now a CSV type. If this behaviour is not desired
      simply override the match with `:native_types` for the media types that should
      not be handled like this.

      ### Encoding

      The CSV format (final encoding type) is specified when calling transform,
      by providing an atom or string to the `:format` option. This type is then
      used to infer how the content should be encoded, as well as what type will
      be used for the media type.

        Resx.Resource.transform(resource, ResxCSV.Encoder, format: :csv)

      The current formats are:

      * `:csv` - This encodes the data into CSV. This is the default encoding format.
      * `:tsv` - This encodes the data into TSV (tab-separated-values).

      Otherwise can pass in any string to explicitly denote another format.

        Resx.Resource.transform(resource, ResxCSV.Encoder, format: "dsv", separator: ?;)

      ### Options

      `:format` - expects an `atom` or `String.t` value, defaults to `:csv`. This
      option specifies the encoding format.

      `:separator` - expects a `char` value, defaults to the separator literal that
      is returned for the given encoding format. This option allows for the separator
      to be overriden.

      `:delimiter` - expects a `String.t` value, defaults to `"\\r\\n"`. This option
      specifies the delimiter use to separate the different rows.

      `:headers` - expects a `boolean` or `list` value, defaults to `true`. This
      option specifies whether the encoding should include headers or not. If `false`
      then no headers will be included in the final output, if `true` then the content
      will be parsed first in order to get the headers, if a `list` of keys then those
      keys will be used as the header. If a header is being used, and given a row of
      type `map`, it will use the header to retrieve the individual values, whereas if
      the row is a `list` then it will use the list as is. If the content is a stream
      and headers are being inferred, this may have unintended effects if any stage of
      the stream prior has any side-effects. To alleviate this, you should cache the
      previous stage of the stream.

      `:validate_row_length` - expects a `boolean` value, defaults to `true`. This
      option specifies whether the row length needs to be the same or whether it
      can be of variable length. If `true` then it will enforce all rows are of
      equal size to the first row, so if a row is a `list` it should match the size
      as the previous rows or headers. If `false` then it will use any `list` row
      as is.
    """
    use Resx.Transformer

    alias Resx.Resource.Content

    @impl Resx.Transformer
    def transform(resource = %{ content: content }, opts) do
        case format(opts[:format] || :csv) do
            { format, separator } ->
                case validate_type(content.type, format) do
                    { :ok, { type, preprocessor } } ->
                        content = prepare_content(Callback.call(preprocessor, [content]))

                        rows = case Keyword.get(opts, :headers, true) do
                            false ->
                                Stream.map(content, fn
                                    row when is_map(row) -> Map.values(row)
                                    row -> row
                                end)
                            headers ->
                                headers = fn -> get_headers(content, headers) end
                                Stream.transform(content, { headers, true }, fn
                                    row, acc = { headers, false } when is_map(row) ->
                                        row = Enum.reduce(headers, [], &([row[&1]|&2])) |> Enum.reverse
                                        { [row], acc }
                                    row, acc = { _, false } -> { [row], acc }
                                    row, { headers, true } when is_map(row) ->
                                        headers = headers.()
                                        row = Enum.reduce(headers, [], &([row[&1]|&2])) |> Enum.reverse
                                        { [headers, row], { headers, false } }
                                    row, { headers, true } ->
                                        headers = headers.()
                                        { [headers, row], { headers, false } }
                                end)
                        end

                        rows = if Keyword.get(opts, :validate_row_length, true) do
                            Stream.transform(rows, nil, fn
                                row, nil -> { [row], length(row) }
                                row, n when length(row) == n -> { [row], length(row) }
                            end)
                        else
                            rows
                        end

                        opts = [
                            separator: opts[:separator] || separator,
                            delimiter: opts[:delimiter] || "\r\n"
                        ]

                        { :ok, %{ resource | content: %{ content | type: type, data: rows |> CSV.encode(opts) } } }
                    error -> error
                end
            format -> { :error, { :internal, "Unknown encoding format: #{inspect(format)}" } }
        end
    end

    defp prepare_content(content = %Content.Stream{}), do: content
    defp prepare_content(content = %Content{}), do: %Content.Stream{ type: content.type, data: content.data }

    defp get_headers(content, true) do
        Enum.reduce(content, MapSet.new, fn
            map, acc when is_map(map) -> map |> Map.keys |> MapSet.new |> MapSet.union(acc)
            _, acc -> acc
        end)
        |> MapSet.to_list
    end
    defp get_headers(_, headers), do: headers

    defp format(format) when format in [:csv, "csv"], do: { "csv", ?, }
    defp format(format) when format in [:tsv, "tab-separated-values"], do: { "tab-separated-values", ?\t }
    defp format(format) when is_binary(format), do: { format, ?, }
    defp format(format), do: format

    defp validate_type(types, format) do
        cond do
            new_type = validate_type(types, Application.get_env(:resx_csv, :native_types, []), format) -> { :ok, new_type }
            new_type = validate_type(types, [{ ~r/\/(x\.erlang\.native(\+x\.erlang\.native)?|(.*?\+)x\.erlang\.native)(;|$)/, &("/\\3#{&1}\\4"), &(&1) }], format) -> { :ok, new_type }
            true -> { :error, { :internal, "Invalid resource type" } }
        end
    end

    defp validate_type(_, [], _), do: nil
    defp validate_type(type_list = [type|types], [{ match, replacement, preprocessor }|matches], format) do
        if type =~ match do
            { [String.replace(type, match, Callback.call(replacement, [format]))|types], preprocessor }
        else
            validate_type(type_list, matches, format)
        end
    end
end
