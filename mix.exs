defmodule ResxCSV.MixProject do
    use Mix.Project

    def project do
        [
            app: :resx_csv,
            description: "CSV encoding/decoding transformer for the resx library",
            version: "0.2.0",
            elixir: "~> 1.7",
            start_permanent: Mix.env() == :prod,
            deps: deps(),
            dialyzer: [plt_add_deps: :transitive],
            package: package()
        ]
    end

    def application do
        [extra_applications: [:logger]]
    end

    defp deps do
        [
            { :resx, "~> 0.1.0" },
            { :csv, "~> 2.3" },
            { :ex_doc, "~> 0.18", only: :dev, runtime: false },
            { :simple_markdown, "~> 0.6.0", only: :dev, runtime: false },
            { :ex_doc_simple_markdown, "~> 0.4", only: :dev, runtime: false }
        ]
    end

    defp package do
        [
            maintainers: ["Stefan Johnson"],
            licenses: ["BSD 2-Clause"],
            links: %{ "GitHub" => "https://github.com/ScrimpyCat/ResxCSV" }
        ]
    end
end
