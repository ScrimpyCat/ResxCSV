defmodule ResxCSV.Decoder do
    @moduledoc """
      Decode CSV string resources into erlang terms.

      ### Media Types

      Only CSV/TSV types are valid. This can either be a CSV/TSV subtype or suffix.

      Valid: `text/csv`, `application/geo+csv`, `text/tab-separated-values`
      If an error is being returned when attempting to open a data URI due to
      `{ :invalid_reference, "invalid media type: \#{type}" }`, the MIME type
      will need to be added to the config.

      To add additional media types to be decoded, that can be done by configuring
      the `:csv_types` option.

        config :resx_csv,
            csv_types: [
                { "application/x.my-type", "application/x.erlang.native", ?; }
            ]

      The `:csv_types` field should contain a list of 3 element tuples with the
      format `{ pattern :: String.pattern | Regex.t, replacement :: String.t, separator :: char }`.

      The `pattern` and `replacement` are arguments to `String.replace/3`. While the
      separator specifies the character literal used to separate columns in the document.

      The replacement becomes the new media type of the transformed resource. Nested
      media types will be preserved. By default the current matches will be replaced
      (where the `csv` type part is), with `x.erlang.native`, in order to denote
      that the content is now a native erlang type. If this behaviour is not desired
      simply override the match with `:csv_types` for the media types that should
      not be handled like this.

      ### Options

      `:skip_errors` - expects a `boolean` value, defaults to `false`. This option
      specifies whether any decoding/formatting errors in the CSV should be skipped.
      If they are skipped then those rows will not appear in the decoded result, if
      should not be skipped then the decoding fails if there are any errors.

      `:separator` - expects a `char` value, defaults to the separator literal that
      is returned for the given MIME/csv_type. This option allows for the separator
      to be overriden.

      `:headers` - expects a `boolean` value, defaults to `true`. This option specifies
      whether the first row will be used as a header.

      `:strip_fields` - expects a `boolean` value, defaults to `false`. This option
      specifies whether any surrounding whitespace will be trimmed.

      `:validate_row_length` - expects a `boolean` value, defaults to `true`. This
      option specifies whether the row length needs to be the same or whether it
      can be of variable length.

        Resx.Resource.transform(resource, ResxCSV.Decoder, skip_errors: true, headers: false)
    """
    use Resx.Transformer

    alias Resx.Resource.Content

    @impl Resx.Transformer
    def transform(resource = %{ content: content }, opts) do
        case validate_type(content.type) do
            { :ok, { type, separator } } ->
                content = prepare_content(content)
                decode = if(opts[:skip_errors], do: &filter_decode/2, else: &CSV.decode!/2)
                opts = [
                    headers: Keyword.get(opts, :headers, true),
                    separator: opts[:separator] || separator,
                    strip_fields: opts[:strip_fields] || false,
                    validate_row_length: Keyword.get(opts, :validate_row_length, true)
                ]

                { :ok, %{ resource | content: %{ content | type: type, data: content |> decode.(opts) } } }
            error -> error
        end
    end

    defp filter_decode(row, opts), do: CSV.decode(row, opts) |> Stream.filter(&filter_row/1) |> Stream.map(&elem(&1, 1))

    defp filter_row({ :ok, _ }), do: true
    defp filter_row(_), do: false

    defp prepare_content(content = %Content.Stream{}), do: content
    defp prepare_content(content = %Content{}), do: %Content.Stream{ type: content.type, data: String.split(content.data, "\n") }

    @default_csv_types [
        { ~r/\/(csv(\+csv)?|(.*?\+)csv)(;|$)/, "/\\3x.erlang.native\\4", ?, },
        { ~r/\/(tab-separated-values(\+tab-separated-values)?|(.*?\+)tab-separated-values)(;|$)/, "/\\3x.erlang.native\\4", ?\t }
    ]
    defp validate_type(types) do
        cond do
            new_type = validate_type(types, Application.get_env(:resx_csv, :csv_types, [])) -> { :ok, new_type }
            new_type = validate_type(types, @default_csv_types) -> { :ok, new_type }
            true -> { :error, { :internal, "Invalid resource type" } }
        end
    end

    defp validate_type(_, []), do: nil
    defp validate_type(type_list = [type|types], [{ match, replacement, decoder }|matches]) do
        if type =~ match do
            { [String.replace(type, match, replacement)|types], decoder }
        else
            validate_type(type_list, matches)
        end
    end
end
