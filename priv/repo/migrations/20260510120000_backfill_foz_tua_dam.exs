defmodule Barragenspt.Repo.Migrations.BackfillFozTuaDam do
  use Ecto.Migration

  @metadata ~s|{
    "Barragem": {
      "Curso de água": "RIO TUA"
    },
    "Albufeira": {
      "Capacidade total (dam3)": "106100",
      "Tipos de aproveitamento": "Energia"
    },
    "Identificação": {
      "Latitude (m)": "41º 13' 7.9392''",
      "Longitude (m)": "7º 25' 21.5112''"
    },
    "Bacia Hidrográfica": {
      "Bacia hidrográfica": "Douro"
    }
  }|

  def up do
    execute("""
    UPDATE dam
    SET
      basin_id = '12',
      basin = 'Douro',
      code = '06M/06A',
      name = 'Foz Do Tua',
      metadata = $json$#{@metadata}$json$::jsonb,
      site_id = '9321904688',
      albuf_id = '174',
      river = 'tua',
      total_capacity = 106100,
      updated_at = timezone('utc', now())
    WHERE
      site_id = '9321904688'
      OR code = '06M/06A'
      OR lower(name) = lower('Foz Do Tua')
      OR lower(name) = lower('Foz Tua');
    """)

    execute("""
    INSERT INTO dam (
      basin_id,
      basin,
      code,
      name,
      metadata,
      site_id,
      albuf_id,
      river,
      total_capacity,
      inserted_at,
      updated_at
    )
    SELECT
      '12',
      'Douro',
      '06M/06A',
      'Foz Do Tua',
      $json$#{@metadata}$json$::jsonb,
      '9321904688',
      '174',
      'tua',
      106100,
      timezone('utc', now()),
      timezone('utc', now())
    WHERE NOT EXISTS (
      SELECT 1
      FROM dam
      WHERE
        site_id = '9321904688'
        OR code = '06M/06A'
        OR lower(name) = lower('Foz Do Tua')
        OR lower(name) = lower('Foz Tua')
    );
    """)
  end

  def down do
    :ok
  end
end
