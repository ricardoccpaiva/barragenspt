defmodule Barragenspt.Repo.Migrations.BackfillBaixoSaborDam do
  use Ecto.Migration

  @metadata ~s|{
    "Barragem": {
      "Curso de água": "RIO SABOR"
    },
    "Albufeira": {
      "Capacidade total (dam3)": "1095000",
      "Tipos de aproveitamento": "Energia"
    },
    "Identificação": {
      "Latitude (m)": "41º 13' 42.1608''",
      "Longitude (m)": "7º 0' 45.7596''"
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
      code = '06O/09A',
      name = 'Baixo Sabor',
      metadata = $json$#{@metadata}$json$::jsonb,
      site_id = '7554777518',
      river = 'sabor',
      total_capacity = 1095000,
      updated_at = timezone('utc', now())
    WHERE
      site_id = '7554777518'
      OR code = '06O/09A'
      OR lower(name) = lower('Baixo Sabor');
    """)

    execute("""
    INSERT INTO dam (
      basin_id,
      basin,
      code,
      name,
      metadata,
      site_id,
      river,
      total_capacity,
      inserted_at,
      updated_at
    )
    SELECT
      '12',
      'Douro',
      '06O/09A',
      'Baixo Sabor',
      $json$#{@metadata}$json$::jsonb,
      '7554777518',
      'sabor',
      1095000,
      timezone('utc', now()),
      timezone('utc', now())
    WHERE NOT EXISTS (
      SELECT 1
      FROM dam
      WHERE
        site_id = '7554777518'
        OR code = '06O/09A'
        OR lower(name) = lower('Baixo Sabor')
    );
    """)
  end

  def down do
    :ok
  end
end
