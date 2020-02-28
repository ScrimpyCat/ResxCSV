defmodule ResxCSV.DecoderTest do
    use ExUnit.Case
    doctest ResxCSV.Decoder

    test "media types" do
        assert ["text/x.erlang.native"] == (Resx.Resource.open!(~S(data:text/csv,{})) |> Resx.Resource.transform!(ResxCSV.Decoder)).content.type
        assert ["text/x.erlang.native; charset=utf-8"] == (Resx.Resource.open!(~S(data:text/csv,{})) |> Map.replace!(:content, %Resx.Resource.Content{data: "{}", type: ["text/csv; charset=utf-8"]}) |> Resx.Resource.transform!(ResxCSV.Decoder)).content.type
        assert ["text/x.erlang.native"] == (Resx.Resource.open!(~S(data:text/tab-separated-values,{})) |> Resx.Resource.transform!(ResxCSV.Decoder)).content.type
        assert ["application/geo+x.erlang.native"] == (Resx.Resource.open!(~S(data:application/geo+csv,{})) |> Resx.Resource.transform!(ResxCSV.Decoder)).content.type
        assert ["application/geo+x.erlang.native"] == (Resx.Resource.open!(~S(data:application/geo+tab-separated-values,{})) |> Resx.Resource.transform!(ResxCSV.Decoder)).content.type

        assert ["csv/x.erlang.native"] == (Resx.Resource.open!(~S(data:csv/csv,{})) |> Resx.Resource.transform!(ResxCSV.Decoder)).content.type
        assert ["csv/x.erlang.native"] == (Resx.Resource.open!(~S(data:csv/csv+csv,{})) |> Resx.Resource.transform!(ResxCSV.Decoder)).content.type

        Application.put_env(:resx_csv, :csv_types, [])
        assert { :error, { :internal, "Invalid resource type" } } == (Resx.Resource.open!(~S(data:csv/csvs,{})) |> Resx.Resource.transform(ResxCSV.Decoder))
        assert { :error, { :internal, "Invalid resource type" } } == (Resx.Resource.open!(~S(data:csv/csv+csvs,{})) |> Resx.Resource.transform(ResxCSV.Decoder))

        Application.put_env(:resx_csv, :csv_types, [{ "csv/csvs", "foo", :csv }])
        assert ["foo"] == (Resx.Resource.open!(~S(data:csv/csvs,{})) |> Resx.Resource.transform!(ResxCSV.Decoder)).content.type
        assert ["foo; charset=utf-8"] == (Resx.Resource.open!(~S(data:csv/csvs,{})) |> Map.replace!(:content, %Resx.Resource.Content{data: "{}", type: ["csv/csvs; charset=utf-8"]}) |> Resx.Resource.transform!(ResxCSV.Decoder)).content.type
    end

    describe "decoding" do
        test "valid" do
            assert [
                %{ "a" => "1", "b" => "2", "c" => "3" },
                %{ "a" => "4", "b" => "5", "c" => "6" },
                %{ "a" => "7", "b" => "8", "c" => "9" }
            ] == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder)).content |> Resx.Resource.Content.data

            assert [
                %{ "a" => "1", "b" => "2", "c" => "3" },
                %{ "a" => "4", "b" => "5", "c" => "6" },
                %{ "a" => "7", "b" => "8", "c" => "9" }
            ] == (Resx.Resource.open!("data:text/csv,a,b,c\n1,2,3\n4,5,6\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder, delimiter: "\n")).content |> Resx.Resource.Content.data

            assert [
                %{ "a" => "1", "b" => "2", "c" => "3" },
                %{ "a" => "4", "b" => "5", "c" => "6" },
                %{ "a" => "7", "b" => "8", "c" => "9" }
            ] == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder, skip_errors: true)).content |> Resx.Resource.Content.data

            assert [
                ["a", "b", "c"],
                ["1", "2", "3"],
                ["4", "5", "6"],
                ["7", "8", "9"]
            ] == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder, headers: false)).content |> Resx.Resource.Content.data

            assert [
                %{ "a" => "1", "b" => "2", "c" => "3" },
                %{ "a" => "4", "b" => "5", "c" => "6" },
                %{ "a" => "7", "b" => "8", "c" => "9" }
            ] == (Resx.Resource.open!("data:text/tab-separated-values,a\tb\tc\r\n1\t2\t3\r\n4\t5\t6\r\n7\t8\t9") |> Resx.Resource.transform!(ResxCSV.Decoder)).content |> Resx.Resource.Content.data

            assert [
                %{ "a" => "1", "b" => "2", "c" => "3" },
                %{ "a" => "4", "b" => "5", "c" => "6" },
                %{ "a" => "7", "b" => "8", "c" => "9" }
            ] == (Resx.Resource.open!("data:text/csv,a;b;c\r\n1;2;3\r\n4;5;6\r\n7;8;9") |> Resx.Resource.transform!(ResxCSV.Decoder, separator: ?;)).content |> Resx.Resource.Content.data

            assert [
                %{ "a" => "1", "b" => "2", "c" => "3" },
                %{ "a" => "4", "b" => "5", "c" => "6" },
                %{ "a" => "7", "b" => "8", "c" => "9" }
            ] == (Resx.Resource.stream!("file:" <> Path.join([__DIR__, "example.csv"])) |> Resx.Resource.transform!(ResxCSV.Decoder)).content |> Resx.Resource.Content.data

            assert [
                ["a", "b", "c"],
                ["1", "2", "3"],
                ["4", "5", "6"],
                ["7", "8", "9"]
            ] == (Resx.Resource.stream!("file:" <> Path.join([__DIR__, "example.csv"])) |> Resx.Resource.transform!(ResxCSV.Decoder, headers: false)).content |> Resx.Resource.Content.data

            assert [
                %{ "a" => "1", "b" => "2", "c" => "3" },
                %{ "a" => "4", "b" => "5", "c" => "6" },
                %{ "a" => "7", "b" => "8", "c" => "9" }
            ] == (Resx.Resource.stream!("file:" <> Path.join([__DIR__, "example.tsv"])) |> Resx.Resource.transform!(ResxCSV.Decoder)).content |> Resx.Resource.Content.data

            assert [
                %{ "a" => "1", "b" => "2", "c" => "3" },
                %{ "a" => "4", "b" => "5", "c" => "6" },
                %{ "a" => "7", "b" => "8", "c" => "9" }
            ] == (Resx.Resource.stream!("file:" <> Path.join([__DIR__, "example-semicolon.csv"])) |> Resx.Resource.transform!(ResxCSV.Decoder, separator: ?;)).content |> Resx.Resource.Content.data

            assert [
                %{ " a " => "1", "b" => " 2 ", "c" => "3" }
            ] == (Resx.Resource.open!("data:text/csv, a ,b,c\r\n1, 2 ,3") |> Resx.Resource.transform!(ResxCSV.Decoder)).content |> Resx.Resource.Content.data

            assert [
                %{ "a" => "1", "b" => "2", "c" => "3" }
            ] == (Resx.Resource.open!("data:text/csv, a ,b,c\r\n1, 2 ,3") |> Resx.Resource.transform!(ResxCSV.Decoder, strip_fields: true)).content |> Resx.Resource.Content.data
        end

        test "malformed" do
            assert catch_error (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder)).content |> Resx.Resource.Content.data

            assert [
                %{ "a" => "1", "b" => "2", "c" => "3" },
                %{ "a" => "7", "b" => "8", "c" => "9" }
            ] == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder, skip_errors: true)).content |> Resx.Resource.Content.data

            assert [
                %{ "a" => "1", "b" => "2", "c" => "3" },
                %{ "a" => "7", "b" => "8", "c" => "9" }
            ] == (Resx.Resource.stream!("file:" <> Path.join([__DIR__, "example-malformed.csv"])) |> Resx.Resource.transform!(ResxCSV.Decoder, skip_errors: true)).content |> Resx.Resource.Content.data

            assert [
                %{ "a" => "1", "b" => "2", "c" => "3" },
                %{"a" => "4", "b" => "5"},
                %{ "a" => "7", "b" => "8", "c" => "9" }
            ] == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder, validate_row_length: false)).content |> Resx.Resource.Content.data
        end
    end
end
