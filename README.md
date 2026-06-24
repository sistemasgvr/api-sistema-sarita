<p align="center">
  <a href="http://nestjs.com/" target="blank"><img src="https://nestjs.com/img/logo-small.svg" width="120" alt="Nest Logo" /></a>
</p>

[circleci-image]: https://img.shields.io/circleci/build/github/nestjs/nest/master?token=abc123def456
[circleci-url]: https://circleci.com/gh/nestjs/nest

  <p align="center">A progressive <a href="http://nodejs.org" target="_blank">Node.js</a> framework for building efficient and scalable server-side applications.</p>
    <p align="center">
<a href="https://www.npmjs.com/~nestjscore" target="_blank"><img src="https://img.shields.io/npm/v/@nestjs/core.svg" alt="NPM Version" /></a>
<a href="https://www.npmjs.com/~nestjscore" target="_blank"><img src="https://img.shields.io/npm/l/@nestjs/core.svg" alt="Package License" /></a>
<a href="https://www.npmjs.com/~nestjscore" target="_blank"><img src="https://img.shields.io/npm/dm/@nestjs/common.svg" alt="NPM Downloads" /></a>
<a href="https://circleci.com/gh/nestjs/nest" target="_blank"><img src="https://img.shields.io/circleci/build/github/nestjs/nest/master" alt="CircleCI" /></a>
<a href="https://discord.gg/G7Qnnhy" target="_blank"><img src="https://img.shields.io/badge/discord-online-brightgreen.svg" alt="Discord"/></a>
<a href="https://opencollective.com/nest#backer" target="_blank"><img src="https://opencollective.com/nest/backers/badge.svg" alt="Backers on Open Collective" /></a>
<a href="https://opencollective.com/nest#sponsor" target="_blank"><img src="https://opencollective.com/nest/sponsors/badge.svg" alt="Sponsors on Open Collective" /></a>
  <a href="https://paypal.me/kamilmysliwiec" target="_blank"><img src="https://img.shields.io/badge/Donate-PayPal-ff3f59.svg" alt="Donate us"/></a>
    <a href="https://opencollective.com/nest#sponsor"  target="_blank"><img src="https://img.shields.io/badge/Support%20us-Open%20Collective-41B883.svg" alt="Support us"></a>
  <a href="https://twitter.com/nestframework" target="_blank"><img src="https://img.shields.io/twitter/follow/nestframework.svg?style=social&label=Follow" alt="Follow us on Twitter"></a>
</p>
  <!--[![Backers on Open Collective](https://opencollective.com/nest/backers/badge.svg)](https://opencollective.com/nest#backer)
  [![Sponsors on Open Collective](https://opencollective.com/nest/sponsors/badge.svg)](https://opencollective.com/nest#sponsor)-->

## Description

[Nest](https://github.com/nestjs/nest) framework TypeScript starter repository.

## Project setup

```bash
$ npm install
```

## Compile and run the project

```bash
# development
$ npm run start

# watch mode
$ npm run start:dev

# production mode
$ npm run start:prod
```

## Run tests

```bash
# unit tests
$ npm run test

# e2e tests
$ npm run test:e2e

# test coverage
$ npm run test:cov
```

## Deployment

When you're ready to deploy your NestJS application to production, there are some key steps you can take to ensure it runs as efficiently as possible. Check out the [deployment documentation](https://docs.nestjs.com/deployment) for more information.

If you are looking for a cloud-based platform to deploy your NestJS application, check out [Mau](https://mau.nestjs.com), our official platform for deploying NestJS applications on AWS. Mau makes deployment straightforward and fast, requiring just a few simple steps:

```bash
$ npm install -g @nestjs/mau
$ mau deploy
```

With Mau, you can deploy your application in just a few clicks, allowing you to focus on building features rather than managing infrastructure.

## Resources

Check out a few resources that may come in handy when working with NestJS:

- Visit the [NestJS Documentation](https://docs.nestjs.com) to learn more about the framework.
- For questions and support, please visit our [Discord channel](https://discord.gg/G7Qnnhy).
- To dive deeper and get more hands-on experience, check out our official video [courses](https://courses.nestjs.com/).
- Deploy your application to AWS with the help of [NestJS Mau](https://mau.nestjs.com) in just a few clicks.
- Visualize your application graph and interact with the NestJS application in real-time using [NestJS Devtools](https://devtools.nestjs.com).
- Need help with your project (part-time to full-time)? Check out our official [enterprise support](https://enterprise.nestjs.com).
- To stay in the loop and get updates, follow us on [X](https://x.com/nestframework) and [LinkedIn](https://linkedin.com/company/nestjs).
- Looking for a job, or have a job to offer? Check out our official [Jobs board](https://jobs.nestjs.com).

## Support

Nest is an MIT-licensed open source project. It can grow thanks to the sponsors and support by the amazing backers. If you'd like to join them, please [read more here](https://docs.nestjs.com/support).

## Stay in touch

- Author - [Kamil Myśliwiec](https://twitter.com/kammysliwiec)
- Website - [https://nestjs.com](https://nestjs.com/)
- Twitter - [@nestframework](https://twitter.com/nestframework)

## License

Nest is [MIT licensed](https://github.com/nestjs/nest/blob/master/LICENSE).

## Estructura del proyecto

API NestJS que consume **funciones de PostgreSQL**. Cada módulo sigue el flujo: **controller → logic → model**.

```
src/
├── config/          # Configuración de la aplicación
├── database/        # Conexión y pool de PostgreSQL
├── common/          # Código compartido entre módulos
├── modules/         # Módulos por dominio/funcionalidad
├── app.module.ts    # Módulo raíz
└── main.ts          # Punto de entrada, Swagger y logs de arranque
```

### `src/config/`

Variables y configuración centralizada. Aquí se definen los parámetros de conexión a PostgreSQL (`database.config.ts`) leídos desde el archivo `.env`.

### `src/database/`

Capa de acceso a la base de datos. Contiene el pool de conexiones (`database.service.ts`) y el helper `callFunction()` para invocar funciones PG. También verifica si la BD está conectada al iniciar la API.

### `src/common/`

Recursos reutilizables en toda la aplicación:

| Carpeta / archivo | Propósito |
|-------------------|-----------|
| `dto/` | DTOs genéricos de respuesta para Swagger (`ApiResponseDto`, `ApiErrorResponseDto`) |
| `filters/` | Filtros globales de excepciones. Formatea errores HTTP con la estructura estándar |
| `guards/` | Guards de autenticación y autorización (JWT, roles, permisos) |
| `helpers/` | Utilidades compartidas, como `ResponseHelper` para respuestas con `meta` de paginación |
| `interceptors/` | Interceptores transversales. Envuelve respuestas exitosas en `{ success, message, data }` |
| `interfaces/` | Interfaces TypeScript de las estructuras de respuesta de la API |

### `src/modules/`

Cada carpeta es un módulo independiente (ej. `ejemplo`, `usuarios`, etc.). Para crear uno nuevo, copia la estructura del módulo `ejemplo`:

| Carpeta | Propósito |
|---------|-----------|
| `controllers/` | Endpoints HTTP (GET, POST, PATCH, DELETE). Recibe requests y delega a logic |
| `logic/` | Lógica de negocio, validaciones y manejo de errores antes/después de llamar al model |
| `models/` | Única capa que habla con PostgreSQL. Solo llama funciones de la BD (`fn_*`) |
| `dto/` | Objetos de entrada/salida: crear, actualizar, filtros y respuestas documentadas en Swagger |
| `*.module.ts` | Registra controller, logic y model del módulo |

### `test/`

Pruebas end-to-end de la aplicación.

### Archivos en la raíz

| Archivo | Propósito |
|---------|-----------|
| `.env.example` | Plantilla de variables de entorno (puerto, credenciales de BD) |
| `nest-cli.json` | Configuración del CLI de NestJS |
| `tsconfig.json` | Configuración de TypeScript |

### Respuesta estándar de la API

Todas las respuestas exitosas siguen este formato:

```json
{
  "success": true,
  "message": "Consulta exitosa",
  "data": {}
}
```

Los errores:

```json
{
  "success": false,
  "message": "Descripción del error",
  "data": null,
  "errors": null,
  "statusCode": 400
}
```

### Swagger

Documentación interactiva disponible en `http://localhost:3000/api/docs` al iniciar el servidor.
