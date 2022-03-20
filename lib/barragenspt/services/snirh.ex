defmodule Barragenspt.Services.Snirh do
  @timeout 25000
  @base_url Application.get_env(:barragenspt, :snirh)[:csv_data_url]

  def get_raw_csv_data(site_id, parameter_id, start_date, end_date) do
    query_params =
      "?sites=#{site_id}&pars=#{parameter_id}&tmin=#{start_date}&tmax=#{end_date}&formato=csv"

    options = [recv_timeout: @timeout, timeout: @timeout]
    %HTTPoison.Response{body: body} = HTTPoison.get!(@base_url <> query_params, [], options)

    body
  end
end
