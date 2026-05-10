defmodule Barragenspt.Repo.Migrations.UpdateDamTotalCapacitiesFromApa20260413 do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE dam
    SET total_capacity = caps.capacity,
    metadata = jsonb_set(
      COALESCE(metadata, '{}'::jsonb),
      '{Albufeira,"Capacidade total (dam3)"}',
      to_jsonb(caps.capacity::text),
      true
    ),
    updated_at = timezone('utc', now())
    FROM (
      VALUES
        ('02H/01A', 379000),
        ('03J/03A', 568700),
        ('03J/01A', 164400),
        ('04I/01A', 21200),
        ('06M/01A', 1740),
        ('07I/01A', 150200),
        ('05T/01A', 28000),
        ('07O/02A', 82900),
        ('07H/01A', 123900),
        ('07M/02A', 98500),
        ('09H/06A', 136400),
        ('11H/01A', 423000),
        ('10M/01A', 5500),
        ('10K/01A', 3841),
        ('11L/03A', 13880),
        ('12H/01A', 24400),
        ('17J/01A', 20570),
        ('16K/02A', 93000),
        ('12O/01A', 40900),
        ('22I/01A', 52100),
        ('17L/01A', 22000),
        ('26F/01A', 27150),
        ('27H/01A', 104500),
        ('27H/02AE', 653),
        ('26I/01A', 96311),
        ('26M/01A', 12500),
        ('22K/01A', 15280),
        ('30G/02A', 28380)
    ) AS caps(code, capacity)
    WHERE dam.code = caps.code;
    """)
  end

  def down do
    :ok
  end
end
