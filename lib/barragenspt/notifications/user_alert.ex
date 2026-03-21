defmodule Barragenspt.Notifications.UserAlert do
  use Ecto.Schema
  import Ecto.Changeset

  alias Barragenspt.Accounts.User

  @subject_types ~w(dam)
  @realtime_metrics ~w(realtime_level realtime_inflow realtime_outflow realtime_storage)
  @metrics ~w(storage_pct month_change_pct year_change_pct) ++ @realtime_metrics
  @operators ~w(lt gt)
  @repeat_modes_base ~w(once_per_event cooldown)

  schema "user_alerts" do
    field :subject_type, :string
    field :subject_id, :string
    field :subject_name, :string
    field :metric, :string
    field :operator, :string
    field :threshold, :float
    field :repeat_mode, :string, default: "cooldown"
    field :cooldown_hours, :integer, default: 24
    field :active, :boolean, default: true
    field :breach_notification_sent, :boolean, default: false
    field :last_notified_at, :utc_datetime_usec

    belongs_to :user, User

    has_many :alert_events, Barragenspt.Notifications.AlertEvent, foreign_key: :alert_id

    timestamps()
  end

  def update_changeset(alert, attrs) do
    cast(alert, attrs, [:active, :breach_notification_sent, :last_notified_at])
  end

  def changeset(alert, attrs) do
    alert
    |> cast(attrs, [
      :subject_type,
      :subject_id,
      :subject_name,
      :metric,
      :operator,
      :threshold,
      :repeat_mode,
      :cooldown_hours,
      :active,
      :breach_notification_sent,
      :last_notified_at,
      :user_id
    ])
    |> validate_required([
      :subject_type,
      :subject_name,
      :metric,
      :operator,
      :threshold,
      :user_id
    ])
    |> validate_inclusion(:subject_type, @subject_types)
    |> validate_inclusion(:metric, @metrics)
    |> validate_inclusion(:operator, @operators)
    |> validate_inclusion(:repeat_mode, repeat_modes())
    |> validate_threshold_for_metric()
    |> validate_number(:cooldown_hours, greater_than: 0, less_than: 8760)
    |> validate_subject_id()
    |> validate_metric_subject_compatibility()
    |> foreign_key_constraint(:user_id)
  end

  defp validate_subject_id(changeset) do
    if present?(get_field(changeset, :subject_id)) do
      changeset
    else
      add_error(changeset, :subject_id, "can't be blank")
    end
  end

  defp present?(s) when is_binary(s), do: String.trim(s) != ""
  defp present?(_), do: false

  defp validate_metric_subject_compatibility(changeset) do
    metric = get_field(changeset, :metric)
    subject_type = get_field(changeset, :subject_type)

    if metric in @realtime_metrics and subject_type != "dam" do
      add_error(changeset, :metric, "is only available for dam alerts")
    else
      changeset
    end
  end

  defp validate_threshold_for_metric(changeset) do
    metric = get_field(changeset, :metric)

    case metric do
      m when m in ["storage_pct", "month_change_pct", "year_change_pct"] ->
        validate_number(changeset, :threshold, greater_than: -500, less_than: 500)

      _ ->
        validate_number(changeset, :threshold,
          greater_than: -1_000_000,
          less_than: 1_000_000
        )
    end
  end

  def subject_types, do: @subject_types
  def metrics, do: @metrics
  def realtime_metrics, do: @realtime_metrics
  def realtime_metric?(metric), do: metric in @realtime_metrics
  def operators, do: @operators
  @doc """
  Allowed `repeat_mode` values. Includes `"always"` only when `MIX_ENV=dev` (`Application.get_env(:barragenspt, :env) == :dev`).
  """
  def repeat_modes do
    if Application.get_env(:barragenspt, :env) == :dev do
      @repeat_modes_base ++ ~w(always)
    else
      @repeat_modes_base
    end
  end
end
