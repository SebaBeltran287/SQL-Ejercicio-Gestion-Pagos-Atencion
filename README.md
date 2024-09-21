# Gestión de Pagos de Atenciones - Clínica Ketekura

Este repositorio contiene un conjunto de procedimientos y triggers en PL/SQL para gestionar los pagos de las atenciones en la Clínica Ketekura. Se incluyen mecanismos para registrar pagos, calcular saldos pendientes y auditar errores.

## Funcionalidades Principales

- **Registro de Pagos**: Procedimientos para registrar pagos de atenciones y validar que no excedan el saldo pendiente ni sean anteriores a la fecha actual.
- **Actualización de Pagos**: Procedimiento para recalcular todos los pagos y saldos pendientes de las atenciones ya existentes.
- **Auditoría de Errores**: Registro de errores en una tabla `ERRORES_PROCESO` cuando se detectan problemas durante las operaciones de inserción o actualización.

## Estructura de Tablas

- **`ATENCION`**: Contiene las atenciones realizadas a los pacientes.
- **`PAGO_ATENCION`**: Registra los pagos de las atenciones.
- **`RESUMEN_PAGO`**: Consolida el total de pagos y los saldos pendientes por atención.
- **`ERRORES_PROCESO`**: Almacena los errores ocurridos en las operaciones SQL.
