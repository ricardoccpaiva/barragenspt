defmodule Barragenspt.Converters.ColorConverter do
  def get_hex_color("precipitation", "rgb(0%,0%,0%)") do
    "000000"
  end

  def get_hex_color("precipitation", "rgb(21.176471%,5.490196%,21.960784%)") do
    "360e38"
  end

  def get_hex_color("precipitation", "rgb(53.333333%,13.333333%,54.901961%)") do
    "88218c"
  end

  def get_hex_color("precipitation", "rgb(46.27451%,23.921569%,55.294118%)") do
    "753d8d"
  end

  def get_hex_color("precipitation", "rgb(40.784314%,36.862745%,59.607843%)") do
    "685e98"
  end

  def get_hex_color("precipitation", "rgb(41.568627%,45.490196%,64.313725%)") do
    "6a74a4"
  end

  def get_hex_color("precipitation", "rgb(47.058824%,55.294118%,70.588235%)") do
    "788db4"
  end

  def get_hex_color("precipitation", "rgb(54.901961%,64.313725%,76.862745%)") do
    "8da4c4"
  end

  def get_hex_color("precipitation", "rgb(68.235294%,77.254902%,86.27451%)") do
    "aec5dc"
  end

  def get_hex_color("precipitation", "rgb(87.843137%,92.54902%,95.686275%)") do
    "e0ecf4"
  end
end
