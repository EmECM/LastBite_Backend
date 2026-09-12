using System.Data;
using Dapper;

namespace LastBite.Api.Common;

/// <summary>
/// Dapper no sabe leer DateOnly/TimeOnly por su cuenta: Npgsql entrega
/// DateTime para "date" y TimeSpan para "time", y el deserializador rápido de
/// Dapper exige que el constructor del record reciba exactamente eso. Sin
/// estos handlers, cualquier DTO con DateOnly u TimeOnly (los hay desde
/// ZonaResponse) revienta con InvalidOperationException al primer uso real.
/// </summary>
public sealed class DateOnlyTypeHandler : SqlMapper.TypeHandler<DateOnly>
{
    public override DateOnly Parse(object value) => DateOnly.FromDateTime((DateTime)value);

    public override void SetValue(IDbDataParameter parameter, DateOnly value)
    {
        // Sin fijar DbType, Npgsql ve un DateTime y lo manda como "timestamp",
        // y falla contra procedimientos con parámetros DATE (42883).
        parameter.DbType = DbType.Date;
        parameter.Value = value.ToDateTime(TimeOnly.MinValue);
    }
}

public sealed class TimeOnlyTypeHandler : SqlMapper.TypeHandler<TimeOnly>
{
    public override TimeOnly Parse(object value) => TimeOnly.FromTimeSpan((TimeSpan)value);

    public override void SetValue(IDbDataParameter parameter, TimeOnly value)
    {
        parameter.DbType = DbType.Time;
        parameter.Value = value.ToTimeSpan();
    }
}

/// <summary>
/// Npgsql entrega DateTime (en UTC) para "timestamptz", no DateTimeOffset.
/// Mismo problema que arriba: sin esto, cualquier columna TIMESTAMPTZ mapeada
/// a DateTimeOffset revienta al materializar.
/// </summary>
public sealed class DateTimeOffsetTypeHandler : SqlMapper.TypeHandler<DateTimeOffset>
{
    public override DateTimeOffset Parse(object value) => value switch
    {
        DateTimeOffset dto => dto,
        DateTime dt => new DateTimeOffset(DateTime.SpecifyKind(dt, DateTimeKind.Utc)),
        _ => throw new InvalidCastException($"No se puede convertir {value.GetType()} a DateTimeOffset.")
    };

    public override void SetValue(IDbDataParameter parameter, DateTimeOffset value)
        => parameter.Value = value;
}
