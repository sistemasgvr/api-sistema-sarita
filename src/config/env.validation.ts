import * as Joi from 'joi';

export const envValidationSchema = Joi.object({
  NODE_ENV: Joi.string()
    .valid('development', 'production', 'test')
    .default('development'),

  PORT: Joi.number().port().default(3000),
  HTTP_REQUEST_LOGGER_ENABLED: Joi.boolean()
    .truthy('true')
    .falsy('false')
    .default(true),
  HTTP_REQUEST_LOGGER_MAX_BODY_LENGTH: Joi.number().integer().min(0).default(2000),

  DB_HOST: Joi.string().required(),
  DB_PORT: Joi.number().port().default(5432),
  DB_USER: Joi.string().required(),
  DB_PASSWORD: Joi.string().allow('').default(''),
  DB_NAME: Joi.string().required(),
  DB_SSL: Joi.boolean().truthy('true').falsy('false').default(false),

  DATABASE_URL: Joi.string().uri().optional(),

  JWT_SECRET: Joi.string().min(16).required(),
  JWT_EXPIRES_IN: Joi.string().default('24h'),

  // APIsPERU — consultas RENIEC/SUNAT (DNI/RUC)
  APIS_PERU_TOKEN: Joi.string().optional().allow(''),

  // APIsPERU — facturación electrónica
  FACTURACION_APISPERU_ENABLED: Joi.boolean()
    .truthy('true')
    .falsy('false')
    .default(true),
  FACTURACION_APISPERU_BASE_URL: Joi.string()
    .uri()
    .default('https://facturacion.apisperu.com/api/v1'),
  FACTURACION_APISPERU_TOKEN: Joi.string().optional().allow(''),
  FACTURACION_APISPERU_USERNAME: Joi.string().optional().allow(''),
  FACTURACION_APISPERU_PASSWORD: Joi.string().optional().allow(''),
  FACTURACION_APISPERU_RUC: Joi.string().optional().allow(''),
  FACTURACION_APISPERU_CLIENT_ID: Joi.string().optional().allow(''),
  FACTURACION_APISPERU_CLIENT_SECRET: Joi.string().optional().allow(''),
  FACTURACION_APISPERU_GRE_CLIENT_ID: Joi.string().optional().allow(''),
  FACTURACION_APISPERU_GRE_CLIENT_SECRET: Joi.string().optional().allow(''),
  FACTURACION_APISPERU_TIMEOUT_MS: Joi.number().integer().min(1000).default(60000),
});
