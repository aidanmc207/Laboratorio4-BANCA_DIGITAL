# Laboratorios 4 y 5 — BANCA_DIGITAL_C4H845

IF0010 Bases de Datos II — UCR, Sede del Atlántico, II Ciclo 2026

- **Laboratorio 4:** concurrencia, transacciones, manejo de errores, funciones y procedimientos.
- **Laboratorio 5:** seguridad: logins, usuarios, roles y permisos (`GRANT`, `REVOKE` y `DENY`).

## Archivos

| Archivo | Contenido |
|---|---|
| `BANCA_DIGITAL.sql` | Crea la base de datos, las tablas, los datos de prueba y `dbo.ReiniciarDatos`. |
| `Laboratorio4_Solucion.sql` | Lab 4: solución de los ejercicios 1 al 14: transacciones, `TRY...CATCH`, `dbo.CalcularComision`, `dbo.EstadoCuenta`, `dbo.Depositar`, `dbo.Retirar` y `dbo.Transferir`. |
| `BANCA_DIGITAL_NUEVOS_OBJETOS.sql` | Lab 5: objetos de prueba (`vw_ResumenClientes`, `fn_FormatearMonto`, `sp_ConsultarMovimientos`). |
| `Laboratorio5_Solucion.sql` | Lab 5: solución de los ejercicios 1 al 5, con pruebas usando `EXECUTE AS` / `REVERT`. |
| `OPTIMIZACION_BANCA_DIGITAL.sql` | Lab 6: script del enunciado resuelto. El código está en cada `>>> ESCRIBA AQUI SU SOLUCION <<<` y las respuestas debajo de cada pregunta. |

---

# Laboratorio No.6 — Optimización de consultas e índices

1. Ejecutar `BANCA_DIGITAL.sql` **justo antes**. La Parte 0 supone una base recién creada: si `ClienteID` tiene huecos, falla con un error de llave foránea.
2. Ejecutar `OPTIMIZACION_BANCA_DIGITAL.sql` en SSMS con el plan real activado (Ctrl + M).

| Medición | Logical reads |
|---|---|
| Ej. 1: `CuentaID = 500` sin índice (Clustered Index Scan) | 1014 |
| Ej. 2: con `IX_Movimientos_CuentaID` (Index Seek + Key Lookup) | 115 |
| Ej. 4: `SELECT *` original sin filtro | 1063 (1014 + 30 + 19) |
| Ej. 4: consulta reescrita | 119 (115 + 2 + 2) |

---

# Laboratorio No.5 — Seguridad

## Cómo ejecutarlo

1. `BANCA_DIGITAL.sql`
2. `BANCA_DIGITAL_NUEVOS_OBJETOS.sql`
3. `Laboratorio5_Solucion.sql`. Se puede ejecutar varias veces porque al inicio elimina los logins, usuarios, roles y el esquema creados antes.

Cada ejercicio va seguido de un bloque `-- PRUEBA` que suplanta al usuario con `EXECUTE AS USER` y vuelve a `dbo` con `REVERT`. Los resultados y los errores que se obtienen sirven como evidencia para el PDF.

| Error | Significado |
|---|---|
| 229 | Permiso denegado sobre el objeto (`SELECT`, `INSERT`, `UPDATE`, `DELETE`, `EXECUTE`). |
| 230 | Permiso denegado sobre una columna (por ejemplo, `Cedula` o `Saldo`). |
| 262 | Permiso `CREATE ...` denegado en la base de datos. |
| 1088 | Sin permiso `ALTER` sobre la tabla. |

## Principales y permisos

| Principal | Tipo | Detalle |
|---|---|---|
| `login_auditor` / `usr_auditor` | Login + usuario | Miembro de `Rol_Auditoria` |
| `login_cajero` / `usr_cajero` | Login + usuario | Miembro de `Rol_Operadores` |
| `login_soporte` / `usr_soporte` | Login + usuario | Apoyo para el ejercicio 3.5 (permisos por columna) |
| `login_admin` / `usr_admin` | Login + usuario | Miembro de `Rol_Administracion`, apoyo para el ejercicio 4.3 |

Contraseña de todos los logins: `fg46qa95AB++*`.

## Notas

- **3.6:** Para que `usr_cajero` pueda filtrar con `WHERE NumeroCuenta = ...` necesita `SELECT` sobre las columnas del filtro. Por eso se le da `SELECT` solo sobre `CuentaID`, `NumeroCuenta` y `Estado`. Puede cambiar `Estado`, pero no `Saldo` ni `Moneda` (error 230).
- **3.7:** El `DENY` directo al usuario tiene precedencia sobre el `GRANT` que hereda del rol.
- **4.1 y 4.2:** Por el encadenamiento de propiedad, dbo es dueño del procedimiento, de la vista y de las tablas. Por eso el cajero consulta los datos a través de esos objetos aunque no tenga `SELECT` (o tenga `DENY`) sobre las tablas base.
- **4.3:** `dbo.ReiniciarDatos` usa `SET IDENTITY_INSERT`, que exige `ALTER` sobre la tabla y no está cubierto por el encadenamiento de propiedad. Por eso `Rol_Administracion` recibe `ALTER` sobre `Clientes` y `Cuentas`.
- **5.x:** Los permisos `CREATE VIEW/PROCEDURE/FUNCTION/TABLE` requieren además `ALTER` sobre el esquema donde se crea el objeto. Eso se cubre con el ejercicio 5.4 (`dbo`) y el 5.9 (`AuditoriaLocal`).
- **`fn_FormatearMonto`:** Usa el literal `'₡ '` sin prefijo `N`. Con una intercalación que no sea Unicode, el símbolo puede verse como `¢` o `?`.

---

# Laboratorio No.4

## Cómo ejecutarlo

1. Ejecutar `BANCA_DIGITAL.sql` completo en SQL Server (SSMS).
2. Ejecutar `Laboratorio4_Solucion.sql` completo. Cada ejercicio reinicia los datos con `EXEC dbo.ReiniciarDatos;`.
3. Los ejercicios 4 a 7 (Parte 2) requieren dos sesiones de SSMS. Vienen comentados con `/* ... */` y marcados por sesión para copiarlos en la ventana correspondiente.

Errores personalizados usados en los procedimientos:

| Procedimiento | Códigos |
|---|---|
| `dbo.Depositar` | 50010 monto inválido, 50011 cuenta inexistente, 50012 cuenta no activa |
| `dbo.Retirar` | 50020 monto inválido, 50021 inexistente, 50022 no activa, 50023 saldo insuficiente, 50024 límite diario |
| `dbo.Transferir` | 50030 misma cuenta, 50031 monto inválido, 50032/50033 origen/destino inexistente, 50034/50035 origen/destino no activa, 50036 monedas distintas, 50037 saldo insuficiente |

## Respuestas a las preguntas

**Pregunta 1.** `@@TRANCOUNT` devuelve la cantidad de transacciones abiertas en la sesión actual. Dentro de la transacción mostró **1** y después del `COMMIT` muestra **0**.

**Pregunta 2.** Una transacción siempre ve sus propios cambios: las filas modificadas están en las páginas de datos con bloqueos exclusivos que pertenecen a esa misma transacción. El aislamiento protege a las *otras* sesiones de ver datos sin confirmar, no a la sesión que los escribió.

**Pregunta 3.** Se creó dinero: CR-003 subió a ₡180 000 y CR-005 se quedó en ₡25 000. Con `XACT_ABORT OFF`, el error 547 (violación del `CHECK`) solo aborta *la instrucción* que falló, no la transacción. El lote continúa, y el `COMMIT` confirma el crédito que sí se aplicó.

**Pregunta 4.** Con `XACT_ABORT ON`, cualquier error en tiempo de ejecución aborta el lote y revierte la transacción completa, así que ambos saldos quedan como estaban. En el inciso (a) se violaba la **atomicidad**: la operación se aplicó a medias. En consecuencia también quedó comprometida la consistencia.

**Pregunta 5.** Después de `ROLLBACK TRANSACTION PagoInternet`, `@@TRANCOUNT` sigue en **1**: deshacer hasta un punto de guardado no cierra la transacción. Si se hubiera escrito `ROLLBACK TRANSACTION` sin nombre, se revertiría la transacción completa, incluidos los pagos de luz y agua, y `@@TRANCOUNT` pasaría a 0. Luego el `COMMIT` fallaría con el error 3902 porque no habría transacción abierta.

**Pregunta 6.** Con `READ UNCOMMITTED` el analista vio **₡1 025 000**. Con ese dato habría aprobado el crédito, pero el saldo nunca existió: el cajero hizo `ROLLBACK` y la cuenta volvió a ₡25 000. Esto es una lectura sucia.

**Pregunta 7.** Con `READ COMMITTED` el `SELECT` quedó **bloqueado (en espera)**. La sesión A tenía un bloqueo exclusivo (X) sobre la fila, y la sesión B necesita un bloqueo compartido (S) para leer datos confirmados. Cuando A hizo `ROLLBACK`, B continuó y leyó ₡25 000.

**Pregunta 8.** Con `REPEATABLE READ` tuvo que esperar el **UPDATE**, porque el auditor mantiene el bloqueo S sobre la fila de CR-004 hasta el final de la transacción. El **INSERT** se ejecutó de inmediato. En la segunda lectura el saldo **no cambió** (₡1 200 000), pero la cantidad de movimientos pasó de 1 a 2: es una **lectura fantasma**.

**Pregunta 9.** Con `SERIALIZABLE` también el `INSERT` quedó en espera. Este nivel aplica bloqueos de rango de clave sobre el rango leído (`CuentaID = 4`), así que la cantidad de movimientos no cambia entre las dos lecturas. Según la tabla de niveles de aislamiento:

| Nivel | Lectura sucia | No repetible | Fantasma |
|---|---|---|---|
| READ UNCOMMITTED | Sí | Sí | Sí |
| READ COMMITTED | No | Sí | Sí |
| REPEATABLE READ | No | No | **Sí** |
| SERIALIZABLE | No | No | **No** |

**Pregunta 10.** El saldo correcto es ₡80 000 − ₡30 000 − ₡30 000 = **₡20 000**. En el inciso (a) se obtuvo **₡50 000**: ambas sesiones leyeron ₡80 000 y la segunda escritura sobrescribió la primera, lo que es una actualización perdida. En el inciso (b), con `UPDLOCK`, la sesión B espera a que A confirme, lee ₡50 000 y el saldo final es **₡20 000**.

**Pregunta 11.** Calculando el nuevo saldo dentro del mismo `UPDATE`:
`UPDATE Cuentas SET Saldo = Saldo - 30000 WHERE NumeroCuenta = 'CR-003';`
La lectura y la escritura ocurren de forma atómica en una sola instrucción, bajo el mismo bloqueo de actualización.

**Pregunta 12.** Grafo de espera:

```
Sesión A ──espera X sobre CR-004──▶ Sesión B
    ▲                                   │
    └────espera X sobre CR-001──────────┘
```

A tiene bloqueada CR-001 y espera CR-004, mientras B tiene CR-004 y espera CR-001: es un ciclo. El monitor de interbloqueos elige una víctima, que recibe el **error 1205** (*"Transaction (Process ID n) was deadlocked on lock resources with another process and has been chosen as the deadlock victim. Rerun the transaction."*). Su transacción se **revierte completa** y la otra sesión puede terminar y confirmar.

**Pregunta 13.** Si todas las transacciones adquieren los bloqueos en el mismo orden (primero la cuenta de menor `CuentaID`), no se puede formar un ciclo en el grafo de espera. La segunda transacción se bloquea al pedir el *primer* recurso, que la primera ya tiene, y espera sin retener nada que la primera necesite. Así solo hay espera, no interbloqueo.

**Pregunta 14.** El **547** lo provocó una restricción **CHECK** (`Monto > 0` en `Movimientos`). El **2627** lo provocó una restricción **UNIQUE** (`NumeroCuenta` duplicado en `Cuentas`); también aparece con una `PRIMARY KEY`. El tercer error es mayor a 50 000 porque es un error **definido por el usuario**: `THROW` exige números ≥ 50 000, ya que los menores están reservados para los mensajes del sistema (`sys.messages`).

**Pregunta 15.** Con `XACT_ABORT OFF`, `XACT_STATE() = 1`: la transacción seguía siendo confirmable, se hizo `COMMIT` y **se conservó** el movimiento de prueba. Con `XACT_ABORT ON`, `XACT_STATE() = -1`: la transacción quedó condenada, solo se podía revertir y el movimiento **no se conservó**.

**Pregunta 16.** No. Una transferencia es una unidad atómica: si se confirma el trabajo previo al error, se podría debitar una cuenta sin acreditar la otra, o registrar movimientos sin actualizar los saldos. Ante cualquier error lo correcto es hacer `ROLLBACK` de toda la transacción. Confirmar con `XACT_STATE() = 1` solo tiene sentido cuando las partes son independientes entre sí, como los pagos con puntos de guardado del Ejercicio 3.

**Pregunta 17.** Porque el `ROLLBACK` revierte todo lo que se hizo dentro de la transacción. Si el registro `'Rechazada'` se insertara antes, el `ROLLBACK` también lo borraría. Además, con una transacción condenada (`XACT_STATE() = -1`) no se puede escribir nada hasta revertirla. Por eso, primero se revierte y luego se registra el rechazo (y el error en `LogErrores`) fuera de la transacción.

**Pregunta 18.** El paso 4: las dos cuentas se bloquean con `WITH (UPDLOCK, HOLDLOCK)` **siempre en orden ascendente de `CuentaID`**, sin importar cuál es el origen y cuál el destino. Dos transferencias opuestas (CR-001→CR-004 y CR-004→CR-001) piden primero CR-001 y luego CR-004, así que una espera a la otra y no se forma el ciclo del Ejercicio 7. `UPDLOCK` evita además que dos sesiones lean el mismo saldo con bloqueos compartidos y luego choquen al convertirlos a exclusivos.
