defmodule ResxCSV.EncoderTest do
    use ExUnit.Case
    doctest ResxCSV.Encoder

    test "media types" do
        assert ["text/csv"] == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder)).content.type
        assert ["text/csv"] == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder, format: :csv)).content.type
        assert ["text/tab-separated-values"] == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder, format: :tsv)).content.type
        assert ["text/foo"] == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder, format: "foo")).content.type
        assert ["text/csv; charset=utf-8"] == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3") |> Map.replace!(:content, %Resx.Resource.Content{data: "a,b,c\r\n1,2,3", type: ["text/csv; charset=utf-8"]}) |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder)).content.type
        assert ["application/geo+csv"] == (Resx.Resource.open!("data:application/geo+csv,a,b,c\r\n1,2,3") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder)).content.type

        assert ["csv/csv"] == (Resx.Resource.open!(~S(data:csv/csv,a)) |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder)).content.type
        assert ["csv/csv"] == (Resx.Resource.open!(~S(data:csv/csv+csv,a)) |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder)).content.type

        Application.put_env(:resx_csv, :csv_types, [])
        Application.put_env(:resx_csv, :native_types, [])
        assert { :error, { :internal, "Invalid resource type" } } = (Resx.Resource.open!(~S(data:csv/csvs,a)) |> Resx.Resource.transform(ResxCSV.Encoder))
        assert { :error, { :internal, "Invalid resource type" } } == (Resx.Resource.open!(~S(data:csv/csv+csvs,a)) |> Resx.Resource.transform(ResxCSV.Encoder))

        Application.put_env(:resx_csv, :csv_types, [{ "csv/csvs", "foo", :csv }])
        Application.put_env(:resx_csv, :native_types, [{ "foo", &(&1), &(&1) }])
        assert ["csv"] == (Resx.Resource.open!(~S(data:csv/csvs,a)) |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder)).content.type
        assert ["csv; charset=utf-8"] == (Resx.Resource.open!(~S(data:csv/csvs,a)) |> Map.replace!(:content, %Resx.Resource.Content{data: "{}", type: ["csv/csvs; charset=utf-8"]}) |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder)).content.type
    end

    describe "encoding" do
        test "csv" do
            assert "a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9\r\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder)).content |> Resx.Resource.Content.data
            assert "a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9\r\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder, format: "csv")).content |> Resx.Resource.Content.data
            assert "a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9\r\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder, format: :csv)).content |> Resx.Resource.Content.data
            assert "a,b,c\n1,2,3\n4,5,6\n7,8,9\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder, delimiter: "\n")).content |> Resx.Resource.Content.data
            assert catch_error (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder, headers: false) |> Resx.Resource.transform!(ResxCSV.Encoder)).content |> Resx.Resource.Content.data
            assert "\r\na,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9\r\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder, headers: false) |> Resx.Resource.transform!(ResxCSV.Encoder, validate_row_length: false)).content |> Resx.Resource.Content.data
            assert "1,2,3\r\n4,5,6\r\n7,8,9\r\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder, headers: false)).content |> Resx.Resource.Content.data
            assert "a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9\r\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder, headers: false) |> Resx.Resource.transform!(ResxCSV.Encoder, headers: false)).content |> Resx.Resource.Content.data
            assert "b,d,a\r\n2,,1\r\n5,,4\r\n8,,7\r\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder, headers: ["b", "d", "a"])).content |> Resx.Resource.Content.data

            assert "a,b,c\r\n1,2,3\r\n4,5,\r\n7,8,9\r\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder, validate_row_length: false) |> Resx.Resource.transform!(ResxCSV.Encoder)).content |> Resx.Resource.Content.data
            assert catch_error (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder, validate_row_length: false) |> Resx.Resource.transform!(ResxCSV.Encoder, headers: false)).content |> Resx.Resource.Content.data
            assert "1,2,3\r\n4,5\r\n7,8,9\r\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder, validate_row_length: false) |> Resx.Resource.transform!(ResxCSV.Encoder, headers: false, validate_row_length: false)).content |> Resx.Resource.Content.data

            resource = Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.finalise!(hash: false)
            resource = %{ resource | content: %{ resource.content | data: [%{ "a" => 1, "b" => 2 }, %{ "c" => 3 }, %{ "a" => 4, "d" => 5 }] } }

            assert "a,b,c,d\r\n1,2,,\r\n,,3,\r\n4,,,5\r\n" == Resx.Resource.transform!(resource, ResxCSV.Encoder).content |> Resx.Resource.Content.data
            assert catch_error Resx.Resource.transform!(resource, ResxCSV.Encoder, headers: false).content |> Resx.Resource.Content.data
            assert "1,2\r\n3\r\n4,5\r\n" == Resx.Resource.transform!(resource, ResxCSV.Encoder, headers: false, validate_row_length: false).content |> Resx.Resource.Content.data
            assert "a,c\r\n1,\r\n,3\r\n4,\r\n" == Resx.Resource.transform!(resource, ResxCSV.Encoder, headers: ["a", "c"]).content |> Resx.Resource.Content.data
            assert "a,d\r\n1,\r\n,\r\n4,5\r\n" == Resx.Resource.transform!(resource, ResxCSV.Encoder, headers: ["a", "d"]).content |> Resx.Resource.Content.data

            resource = %{ resource | content: %{ resource.content | data: [[1,2], [3], [4,5,6]] } }

            assert catch_error Resx.Resource.transform!(resource, ResxCSV.Encoder).content |> Resx.Resource.Content.data
            assert "\r\n1,2\r\n3\r\n4,5,6\r\n" == Resx.Resource.transform!(resource, ResxCSV.Encoder, validate_row_length: false).content |> Resx.Resource.Content.data
            assert catch_error Resx.Resource.transform!(resource, ResxCSV.Encoder, headers: false).content |> Resx.Resource.Content.data
            assert "1,2\r\n3\r\n4,5,6\r\n" == Resx.Resource.transform!(resource, ResxCSV.Encoder, headers: false, validate_row_length: false).content |> Resx.Resource.Content.data
            assert catch_error Resx.Resource.transform!(resource, ResxCSV.Encoder, headers: ["a"]).content |> Resx.Resource.Content.data
            assert "a\r\n1,2\r\n3\r\n4,5,6\r\n" == Resx.Resource.transform!(resource, ResxCSV.Encoder, headers: ["a"], validate_row_length: false).content |> Resx.Resource.Content.data
            assert catch_error Resx.Resource.transform!(resource, ResxCSV.Encoder, headers: ["a", "b", "c"]).content |> Resx.Resource.Content.data
            assert "a,b,c\r\n1,2\r\n3\r\n4,5,6\r\n" == Resx.Resource.transform!(resource, ResxCSV.Encoder, headers: ["a", "b", "c"], validate_row_length: false).content |> Resx.Resource.Content.data
        end

        test "tsv" do
            assert "a\tb\tc\r\n1\t2\t3\r\n4\t5\t6\r\n7\t8\t9\r\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder, format: :tsv)).content |> Resx.Resource.Content.data
            assert "a\tb\tc\r\n1\t2\t3\r\n4\t5\t6\r\n7\t8\t9\r\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder, format: "tab-separated-values")).content |> Resx.Resource.Content.data
            assert "a\tb\tc\n1\t2\t3\n4\t5\t6\n7\t8\t9\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder, format: :tsv, delimiter: "\n")).content |> Resx.Resource.Content.data
            assert catch_error (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder, headers: false) |> Resx.Resource.transform!(ResxCSV.Encoder, format: :tsv)).content |> Resx.Resource.Content.data
            assert "\r\na\tb\tc\r\n1\t2\t3\r\n4\t5\t6\r\n7\t8\t9\r\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder, headers: false) |> Resx.Resource.transform!(ResxCSV.Encoder, format: :tsv, validate_row_length: false)).content |> Resx.Resource.Content.data
            assert "1\t2\t3\r\n4\t5\t6\r\n7\t8\t9\r\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder, format: :tsv, headers: false)).content |> Resx.Resource.Content.data
            assert "a\tb\tc\r\n1\t2\t3\r\n4\t5\t6\r\n7\t8\t9\r\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder, headers: false) |> Resx.Resource.transform!(ResxCSV.Encoder, format: :tsv, headers: false)).content |> Resx.Resource.Content.data
            assert "b\td\ta\r\n2\t\t1\r\n5\t\t4\r\n8\t\t7\r\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder, format: :tsv, headers: ["b", "d", "a"])).content |> Resx.Resource.Content.data

            assert "a\tb\tc\r\n1\t2\t3\r\n4\t5\t\r\n7\t8\t9\r\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder, validate_row_length: false) |> Resx.Resource.transform!(ResxCSV.Encoder, format: :tsv)).content |> Resx.Resource.Content.data
            assert catch_error (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder, validate_row_length: false) |> Resx.Resource.transform!(ResxCSV.Encoder, format: :tsv, headers: false)).content |> Resx.Resource.Content.data
            assert "1\t2\t3\r\n4\t5\r\n7\t8\t9\r\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder, validate_row_length: false) |> Resx.Resource.transform!(ResxCSV.Encoder, format: :tsv, headers: false, validate_row_length: false)).content |> Resx.Resource.Content.data

            resource = Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.finalise!(hash: false)
            resource = %{ resource | content: %{ resource.content | data: [%{ "a" => 1, "b" => 2 }, %{ "c" => 3 }, %{ "a" => 4, "d" => 5 }] } }

            assert "a\tb\tc\td\r\n1\t2\t\t\r\n\t\t3\t\r\n4\t\t\t5\r\n" == Resx.Resource.transform!(resource, ResxCSV.Encoder, format: :tsv).content |> Resx.Resource.Content.data
            assert catch_error Resx.Resource.transform!(resource, ResxCSV.Encoder, format: :tsv, headers: false).content |> Resx.Resource.Content.data
            assert "1\t2\r\n3\r\n4\t5\r\n" == Resx.Resource.transform!(resource, ResxCSV.Encoder, format: :tsv, headers: false, validate_row_length: false).content |> Resx.Resource.Content.data
            assert "a\tc\r\n1\t\r\n\t3\r\n4\t\r\n" == Resx.Resource.transform!(resource, ResxCSV.Encoder, format: :tsv, headers: ["a", "c"]).content |> Resx.Resource.Content.data
            assert "a\td\r\n1\t\r\n\t\r\n4\t5\r\n" == Resx.Resource.transform!(resource, ResxCSV.Encoder, format: :tsv, headers: ["a", "d"]).content |> Resx.Resource.Content.data

            resource = %{ resource | content: %{ resource.content | data: [[1,2], [3], [4,5,6]] } }

            assert catch_error Resx.Resource.transform!(resource, ResxCSV.Encoder, format: :tsv).content |> Resx.Resource.Content.data
            assert "\r\n1\t2\r\n3\r\n4\t5\t6\r\n" == Resx.Resource.transform!(resource, ResxCSV.Encoder, format: :tsv, validate_row_length: false).content |> Resx.Resource.Content.data
            assert catch_error Resx.Resource.transform!(resource, ResxCSV.Encoder, format: :tsv, headers: false).content |> Resx.Resource.Content.data
            assert "1\t2\r\n3\r\n4\t5\t6\r\n" == Resx.Resource.transform!(resource, ResxCSV.Encoder, format: :tsv, headers: false, validate_row_length: false).content |> Resx.Resource.Content.data
            assert catch_error Resx.Resource.transform!(resource, ResxCSV.Encoder, format: :tsv, headers: ["a"]).content |> Resx.Resource.Content.data
            assert "a\r\n1\t2\r\n3\r\n4\t5\t6\r\n" == Resx.Resource.transform!(resource, ResxCSV.Encoder, format: :tsv, headers: ["a"], validate_row_length: false).content |> Resx.Resource.Content.data
            assert catch_error Resx.Resource.transform!(resource, ResxCSV.Encoder, format: :tsv, headers: ["a", "b", "c"]).content |> Resx.Resource.Content.data
            assert "a\tb\tc\r\n1\t2\r\n3\r\n4\t5\t6\r\n" == Resx.Resource.transform!(resource, ResxCSV.Encoder, format: :tsv, headers: ["a", "b", "c"], validate_row_length: false).content |> Resx.Resource.Content.data
        end

        test "custom" do
            assert "a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9\r\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder, format: "foo")).content |> Resx.Resource.Content.data
            assert "a;b;c\r\n1;2;3\r\n4;5;6\r\n7;8;9\r\n" == (Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform!(ResxCSV.Encoder, format: "foo", separator: ?;)).content |> Resx.Resource.Content.data
            assert { :error, { :internal, "Unknown encoding format: :foo" } } == Resx.Resource.open!("data:text/csv,a,b,c\r\n1,2,3\r\n4,5,6\r\n7,8,9") |> Resx.Resource.transform!(ResxCSV.Decoder) |> Resx.Resource.transform(ResxCSV.Encoder, format: :foo)
        end
    end
end
