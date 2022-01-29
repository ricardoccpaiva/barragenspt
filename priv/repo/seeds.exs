"resources/dams.csv"
|> File.stream!()
|> NimbleCSV.RFC4180.parse_stream()
|> Stream.map(fn [basin_id, basin, code, name] ->
  Barragenspt.Repo.insert!(%Barragenspt.Hydrometrics.Dam{
    name: name,
    code: code,
    basin: basin,
    basin_id: String.to_integer(basin_id)
  })
end)
|> Stream.run()
