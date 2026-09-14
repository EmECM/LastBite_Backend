using System.Data;
using Dapper;

namespace LastBite.Api.Common;

/// <summary>
/// Enseña a Dapper a leer y escribir DateOnly y TimeOnly.
///
/// Por qué hace falta: Dapper 2.1.79 trae desactivado el soporte de estos dos
/// tipos, y Npgsql 8 entrega las columnas date como DateTime y las time como
/// TimeSpan. Sin estos convertidores, cualquier DTO con DateOnly o TimeOnly
/// (horarios, ventanas de retiro, fechas de publicación) revienta al leerse:
/// en un record falla con "A parameterless default constructor or one matching
/// signature is required", y en una clase con InvalidCastException.
///
/// Se registran una sola vez en Program.cs. Cubren también DateOnly? y TimeOnly?.
/// </summary>
public sealed class DateOnlyTypeHandler : SqlMapper.TypeHandler<DateOnly>
{
    public override DateOnly Parse(object value) => value switch
    {
        DateOnly fecha => fecha,
        DateTime fechaHora => DateOnly.FromDateTime(fechaHora),
        _ => throw new DataException(
            $"No se puede convertir {value.GetType().Name} a DateOnly.")
    };

    public override void SetValue(IDbDataParameter parametro, DateOnly valor)
    {
        parametro.DbType = DbType.Date;
        parametro.Value = valor;
    }
}

/// <summary>Igual que DateOnlyTypeHandler, para las columnas time.</summary>
public sealed class TimeOnlyTypeHandler : SqlMapper.TypeHandler<TimeOnly>
{
    public override TimeOnly Parse(object value) => value switch
    {
        TimeOnly hora => hora,
        TimeSpan duracion => TimeOnly.FromTimeSpan(duracion),
        DateTime fechaHora => TimeOnly.FromDateTime(fechaHora),
        _ => throw new DataException(
            $"No se puede convertir {value.GetType().Name} a TimeOnly.")
    };

    public override void SetValue(IDbDataParameter parametro, TimeOnly valor)
    {
        parametro.DbType = DbType.Time;
        parametro.Value = valor;
    }
}
