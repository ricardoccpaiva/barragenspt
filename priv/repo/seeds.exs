"resources/dams.csv"
|> File.stream!()
|> NimbleCSV.RFC4180.parse_stream()
|> Stream.map(fn [basin, code, name] ->
  Barragenspt.Repo.insert!(%Barragenspt.Hydrometrics.Dam{
    name: name,
    code: code,
    basin: basin
  })
end)
|> Stream.run()
