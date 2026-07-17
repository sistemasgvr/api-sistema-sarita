import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import databaseConfig from './config/database.config';
import facturacionConfig from './config/facturacion.config';
import jwtConfig from './config/jwt.config';
import { envValidationSchema } from './config/env.validation';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { PermisosGuard } from './common/guards/permisos.guard';
import { DatabaseModule } from './database/database.module';
import { ActividadesModule } from './modules/actividades/actividades.module';
import { AlmacenesModule } from './modules/almacenes/almacenes.module';
import { CondicionesPagoModule } from './modules/condiciones-pago/condiciones-pago.module';
import { ConfiguracionServiciosModule } from './modules/configuracion-servicios/configuracion-servicios.module';
import { ConfiguracionSunatModule } from './modules/configuracion-sunat/configuracion-sunat.module';
import { EmpresasModule } from './modules/empresas/empresas.module';
import { LoginModule } from './modules/login/login.module';
import { SucursalesModule } from './modules/sucursales/sucursales.module';
import { PermisosModule } from './modules/permisos/permisos.module';
import { RolesModule } from './modules/roles/roles.module';
import { RolesPermisosModule } from './modules/roles-permisos/roles-permisos.module';
import { SesionesModule } from './modules/sesiones/sesiones.module';
import { UsuariosModule } from './modules/usuarios/usuarios.module';
import { UsuariosRolesModule } from './modules/usuarios-roles/usuarios-roles.module';
import { ClientesModule } from './modules/clientes/clientes.module';
import { ConsultasModule } from './modules/consultas/consultas.module';
import { CatalogosModule } from './modules/catalogos/catalogos.module';
import { ContactosModule } from './modules/contactos/contactos.module';
import { DireccionesModule } from './modules/direcciones/direcciones.module';
import { ChoferesModule } from './modules/choferes/choferes.module';
import { VehiculosModule } from './modules/vehiculos/vehiculos.module';
import { LicenciasModule } from './modules/licencias/licencias.module'
import { CategoriasProductoModule } from './modules/categorias-producto/categorias-producto.module';
import { SubCategoriasProductoModule } from './modules/sub-categorias-producto/sub-categorias-producto.module';
import { CatalogoPreciosModule } from './modules/catalogo-precios/catalogo-precios.module';
import { StockProductoModule } from './modules/stock-producto/stock-producto.module';
import { MovimientosInventarioModule } from './modules/movimientos-inventario/movimientos-inventario.module';
import { ProductosModule } from './modules/productos/productos.module';
import { TiposBalonModule } from './modules/tipos-balon/tipos-balon.module';
import { BalonesModule } from './modules/balones/balones.module';
import { MovimientosBalonModule } from './modules/movimientos-balon/movimientos-balon.module';
import { MovimientosRecargaModule } from './modules/movimientos-recarga/movimientos-recarga.module';
import { PrestamosBalonModule } from './modules/prestamos-balon/prestamos-balon.module';
import { PrestamosDetalleModule } from './modules/prestamos-detalle/prestamos-detalle.module';
import { AlquileresBalonModule } from './modules/alquileres-balon/alquileres-balon.module';
import { AlquileresDetalleModule } from './modules/alquileres-detalle/alquileres-detalle.module';
import { MantenimientosBalonModule } from './modules/mantenimientos-balon/mantenimientos-balon.module';
import { FacturacionApisperuModule } from './integrations/facturacion-apisperu/facturacion-apisperu.module';
import { FacturacionElectronicaModule } from './modules/facturacion-electronica/facturacion-electronica.module';
import { ComprobantesModule } from './modules/comprobantes/comprobantes.module';
import { GuiasRemisionModule } from './modules/guias-remision/guias-remision.module';
import { BajasClienteModule } from './modules/bajas-cliente/bajas-cliente.module';
import { CuentasBancariasModule } from './modules/cuentas-bancarias/cuentas-bancarias.module';
import { DocumentosVencimientoModule } from './modules/documentos-vencimiento/documentos-vencimiento.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [databaseConfig, jwtConfig, facturacionConfig],
      validationSchema: envValidationSchema,
      validationOptions: {
        allowUnknown: true,
        abortEarly: false,
      },
    }),
    DatabaseModule,
    LoginModule,
    UsuariosModule,
    RolesModule,
    PermisosModule,
    UsuariosRolesModule,
    RolesPermisosModule,
    SesionesModule,
    SucursalesModule,
    ActividadesModule,
    AlmacenesModule,
    CondicionesPagoModule,
    EmpresasModule,
    ConfiguracionSunatModule,
    ConfiguracionServiciosModule,
    ClientesModule,
    ConsultasModule,
    CatalogosModule,
    ContactosModule,
    DireccionesModule,
    ChoferesModule,
    VehiculosModule,
    LicenciasModule,
    CategoriasProductoModule,
    SubCategoriasProductoModule,
    CatalogoPreciosModule,
    StockProductoModule,
    MovimientosInventarioModule,
    ProductosModule,
    TiposBalonModule,
    MovimientosBalonModule,
    MovimientosRecargaModule,
    PrestamosBalonModule,
    PrestamosDetalleModule,
    AlquileresBalonModule,
    AlquileresDetalleModule,
    MantenimientosBalonModule,
    BalonesModule,
    FacturacionApisperuModule,
    FacturacionElectronicaModule,
    ComprobantesModule,
    GuiasRemisionModule,
    BajasClienteModule,
    CuentasBancariasModule,
    DocumentosVencimientoModule,
  ],
  providers: [
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
    {
      provide: APP_GUARD,
      useClass: PermisosGuard,
    },
  ],
})
export class AppModule {}
