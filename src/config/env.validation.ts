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
});
